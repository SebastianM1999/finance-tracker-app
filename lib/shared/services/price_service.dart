import 'dart:convert';
import 'package:http/http.dart' as http;

class PriceResult {
  const PriceResult({required this.price, required this.source});
  final double price;
  final String source;
}

class PriceService {
  PriceService._();

  static const _binanceBase = 'https://api.binance.com/api/v3/ticker/price';
  static const _frankfurterUrl =
      'https://api.frankfurter.app/latest?from=USD&to=EUR';
  static const _yahooBase =
      'https://query1.finance.yahoo.com/v8/finance/chart';
  static const _stockpricesBase = 'https://stockprices.dev/api';

  // ── Crypto (Binance — CORS-safe) ──────────────────────────────────────────

  static const _symbolAliases = {
    '₿': 'BTC',
    'Ξ': 'ETH',
    'BITCOIN': 'BTC',
    'ETHEREUM': 'ETH',
  };

  static String _normalizeSymbol(String raw) {
    final trimmed = raw.trim();
    return _symbolAliases[trimmed] ??
        _symbolAliases[trimmed.toUpperCase()] ??
        trimmed.toUpperCase();
  }

  static Future<PriceResult?> fetchCryptoPrice(
      String coinSymbol, String coinName) async {
    final symbol = _normalizeSymbol(coinSymbol);

    final eurPrice = await _binancePrice('${symbol}EUR');
    if (eurPrice != null) {
      return PriceResult(price: eurPrice, source: 'Binance');
    }

    final usdtPrice = await _binancePrice('${symbol}USDT');
    if (usdtPrice != null) {
      final rate = await _usdToEur();
      if (rate != null) {
        return PriceResult(price: usdtPrice * rate, source: 'Binance');
      }
    }

    return null;
  }

  static Future<double?> _binancePrice(String symbol) async {
    try {
      final uri = Uri.parse('$_binanceBase?symbol=$symbol');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return double.tryParse(data['price'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  // ── Stocks & ETFs ─────────────────────────────────────────────────────────

  /// Strips exchange suffix: VWCE.DE → VWCE, AAPL → AAPL
  static String _cleanTicker(String ticker) =>
      ticker.trim().split('.').first.toUpperCase();

  /// 1. Try Yahoo Finance (returns exact EUR/USD price, works on native).
  /// 2. Fall back to stockprices.dev (CORS-safe, USD only, US securities only).
  /// Fetches commodity spot price via Yahoo Finance (e.g. GC=F for Gold).
  /// Returns EUR price per unit (troy oz for metals, barrel for oil).
  static Future<PriceResult?> fetchCommodityPrice(String yahooTicker) =>
      _yahooPrice(yahooTicker);

  static Future<PriceResult?> fetchStockOrEtfPrice(
    String ticker, {
    required bool isEtf,
  }) async {
    if (ticker.trim().isEmpty) return null;

    // ── 1. Yahoo Finance with full ticker (e.g. EIMI.DE) ────────────────────
    final yahoo = await _yahooPrice(ticker);
    if (yahoo != null) return yahoo;

    // ── 2. Yahoo Finance with base ticker only (e.g. EIMI) ──────────────────
    // Helps when an exchange suffix is unrecognised by Yahoo but the base
    // ticker resolves to another listing (e.g. EIMI → EIMI.L on Yahoo).
    final base = _cleanTicker(ticker);
    if (base != ticker.trim().toUpperCase()) {
      final yahooBase = await _yahooPrice(base);
      if (yahooBase != null) return yahooBase;
    }

    // ── 3. stockprices.dev fallback (CORS-safe, US tickers only) ───────────
    return _stockpricesPrice(base, isEtf: isEtf);
  }

  static Future<PriceResult?> _yahooPrice(String ticker) async {
    try {
      // Do NOT use Uri.encodeComponent here — it encodes '=' as '%3D' which
      // breaks futures tickers like GC=F on the Yahoo Finance API.
      final uri = Uri.parse('$_yahooBase/$ticker?interval=1d&range=1d');
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final meta = ((data['chart']?['result']) as List?)?.firstOrNull
          as Map<String, dynamic>?;
      final price = (meta?['meta']?['regularMarketPrice'] as num?)?.toDouble();
      if (price == null) return null;

      // If the price is in USD, convert to EUR
      final currency =
          (meta?['meta']?['currency'] as String?)?.toUpperCase() ?? 'USD';
      if (currency == 'USD') {
        final rate = await _usdToEur();
        if (rate == null) return null;
        return PriceResult(price: price * rate, source: 'Yahoo Finance');
      }

      return PriceResult(price: price, source: 'Yahoo Finance');
    } catch (_) {
      return null;
    }
  }

  static Future<PriceResult?> _stockpricesPrice(
    String clean, {
    required bool isEtf,
  }) async {
    if (clean.isEmpty) return null;
    try {
      final segment = isEtf ? 'etfs' : 'stocks';
      final uri = Uri.parse('$_stockpricesBase/$segment/$clean');
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final usdPrice = (data['Price'] as num?)?.toDouble();
      if (usdPrice == null) return null;

      final rate = await _usdToEur();
      if (rate == null) return null;

      return PriceResult(price: usdPrice * rate, source: 'stockprices.dev');
    } catch (_) {
      return null;
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  static Future<double?> _usdToEur() async {
    try {
      final uri = Uri.parse(_frankfurterUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['rates']?['EUR'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }
}
