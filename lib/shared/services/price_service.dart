import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PriceResult {
  const PriceResult({required this.price, required this.source});
  final double price;
  final String source;
}

class YahooSearchResult {
  const YahooSearchResult({
    required this.symbol,
    required this.name,
    required this.type,
    required this.exchange,
  });
  final String symbol;
  final String name;
  final String type; // 'ETF' or 'Aktie'
  final String exchange;
}

class CoinGeckoResult {
  const CoinGeckoResult({required this.id, required this.name, required this.symbol, this.imageUrl});
  final String id; // CoinGecko coin id (e.g. "cronos", "bitcoin")
  final String name;
  final String symbol;
  final String? imageUrl; // small thumbnail URL
}

class PriceService {
  PriceService._();

  static const _proxyBase =
      'https://us-central1-fintrack-a459c.cloudfunctions.net/fetchPrice';

  static const _binanceBase = 'https://api.binance.com/api/v3/ticker/price';
  static const _frankfurterUrl =
      'https://api.frankfurter.app/latest?from=USD&to=EUR';
  static const _yahooBase =
      'https://query1.finance.yahoo.com/v8/finance/chart';
  static const _yahoo2Base =
      'https://query2.finance.yahoo.com/v8/finance/chart';
  static const _stooqBase = 'https://stooq.com/q/l/';
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

  static Future<PriceResult?> _proxyFetch(Map<String, String> params) async {
    try {
      final uri = Uri.parse(_proxyBase).replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final price = (data['price'] as num?)?.toDouble();
      final source = data['source'] as String? ?? 'Cloud Function';
      if (price == null) return null;
      return PriceResult(price: price, source: source);
    } catch (_) {
      return null;
    }
  }

  /// Fetches prices for multiple tickers in a single Cloud Function call.
  /// Only used on web. Returns a map of ticker → price (EUR).
  static Future<Map<String, double>> fetchBatchPrices(
      Map<String, bool> tickers) async {
    if (tickers.isEmpty) return {};
    try {
      final tickersParam = tickers.entries
          .map((e) => '${e.key}:${e.value ? 'etf' : 'stock'}')
          .join(',');
      final uri = Uri.parse(_proxyBase)
          .replace(queryParameters: {'type': 'batch', 'tickers': tickersParam});
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final prices = data['prices'] as Map<String, dynamic>? ?? {};
      return prices.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  static Future<List<YahooSearchResult>> _proxySearch(String query) async {
    try {
      final uri = Uri.parse(_proxyBase)
          .replace(queryParameters: {'type': 'search', 'q': query.trim()});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];
      return results
          .whereType<Map<String, dynamic>>()
          .map((q) => YahooSearchResult(
                symbol: q['symbol'] as String? ?? '',
                name: q['name'] as String? ?? '',
                type: q['type'] as String? ?? 'Aktie',
                exchange: q['exchange'] as String? ?? '',
              ))
          .where((r) => r.symbol.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PriceResult?> fetchCryptoPrice(
      String coinSymbol, String coinName) async {
    final symbol = _normalizeSymbol(coinSymbol);
    if (kIsWeb) return _proxyFetch({'type': 'crypto', 'symbol': symbol});

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

  /// Searches CoinGecko for coins matching [query]. Returns up to 20 results.
  static Future<List<CoinGeckoResult>> searchCryptos(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/search?query=${Uri.encodeComponent(query.trim())}',
      );
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final coins = (data['coins'] as List?) ?? [];
      return coins
          .whereType<Map<String, dynamic>>()
          .map((c) => CoinGeckoResult(
                id: c['id'] as String? ?? '',
                name: c['name'] as String? ?? '',
                symbol: (c['symbol'] as String? ?? '').toUpperCase(),
                imageUrl: c['large'] as String? ?? c['thumb'] as String?,
              ))
          .where((c) => c.id.isNotEmpty && c.name.isNotEmpty && c.symbol.isNotEmpty)
          .take(20)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Batch-fetches EUR prices from CoinGecko by coin id (e.g. "bitcoin", "cronos").
  /// Returns a map of id → EUR price.
  static Future<Map<String, double>> fetchCoinGeckoPrices(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=${ids.join(',')}&vs_currencies=eur',
      );
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = <String, double>{};
      for (final entry in data.entries) {
        final eur = ((entry.value as Map<String, dynamic>)['eur'] as num?)?.toDouble();
        if (eur != null) result[entry.key] = eur;
      }
      return result;
    } catch (_) {
      return {};
    }
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
  static Future<PriceResult?> fetchCommodityPrice(String yahooTicker) {
    if (kIsWeb) {
      return _proxyFetch({'type': 'commodity', 'ticker': yahooTicker});
    }
    return _yahooPrice(yahooTicker);
  }

  static Future<PriceResult?> fetchStockOrEtfPrice(
    String ticker, {
    required bool isEtf,
  }) async {
    if (ticker.trim().isEmpty) return null;
    if (kIsWeb) {
      return _proxyFetch({
        'type': isEtf ? 'etf' : 'stock',
        'ticker': ticker,
        'isEtf': isEtf.toString(),
      });
    }

    // ── 1. Yahoo Finance query1 with full ticker (e.g. IS3N.DE) ─────────────
    final yahoo = await _yahooPrice(ticker, base: _yahooBase);
    if (yahoo != null) return yahoo;

    // ── 2. Yahoo Finance query2 (alternative server, same API) ──────────────
    final yahoo2 = await _yahooPrice(ticker, base: _yahoo2Base);
    if (yahoo2 != null) return yahoo2;

    // ── 3. Stooq (reliable for XETRA .DE and Euronext .AS, no key needed) ──
    final stooq = await _stooqPrice(ticker);
    if (stooq != null) return stooq;

    // ── 4. Yahoo Finance base ticker only (e.g. IS3N strips to base) ────────
    final base = _cleanTicker(ticker);
    if (base != ticker.trim().toUpperCase()) {
      final yahooBase = await _yahooPrice(base, base: _yahooBase);
      if (yahooBase != null) return yahooBase;
    }

    // ── 5. stockprices.dev fallback (CORS-safe, US tickers only) ────────────
    return _stockpricesPrice(base, isEtf: isEtf);
  }

  /// Converts a Yahoo-style ticker to a Stooq ticker and fetches the price.
  /// Handles: XETRA (.DE → .de), Euronext (.AS → .as), LSE (.L → .uk),
  /// US stocks (no suffix → .us). Returns EUR price.
  static Future<PriceResult?> _stooqPrice(String ticker) async {
    try {
      final t = ticker.trim().toUpperCase();
      final String stooqTicker;
      final bool isEur;

      if (t.endsWith('.DE')) {
        stooqTicker = t.toLowerCase();
        isEur = true;
      } else if (t.endsWith('.AS') || t.endsWith('.PA')) {
        stooqTicker = t.toLowerCase();
        isEur = true;
      } else if (t.endsWith('.L')) {
        // LSE prices from Stooq are in GBp (pence), skip — Yahoo handles these
        return null;
      } else {
        // US ticker (no suffix or explicit .US)
        final base = t.endsWith('.US') ? t : '$t.US';
        stooqTicker = base.toLowerCase();
        isEur = false;
      }

      final uri = Uri.parse(
          '$_stooqBase?s=$stooqTicker&f=sd2t2ohlcv&h&e=csv');
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final lines = res.body.trim().split('\n');
      if (lines.length < 2) return null;
      final cols = lines[1].split(',');
      if (cols.length < 7) return null;

      final close = double.tryParse(cols[6].trim());
      if (close == null || close <= 0) return null;

      if (isEur) return PriceResult(price: close, source: 'Stooq');

      final rate = await _usdToEur();
      if (rate == null) return null;
      return PriceResult(price: close * rate, source: 'Stooq');
    } catch (_) {
      return null;
    }
  }

  static Future<PriceResult?> _yahooPrice(String ticker,
      {String base = _yahooBase}) async {
    try {
      // Do NOT use Uri.encodeComponent here — it encodes '=' as '%3D' which
      // breaks futures tickers like GC=F on the Yahoo Finance API.
      final uri = Uri.parse('$base/$ticker?interval=1d&range=1d');
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

  // ── Yahoo Finance search ──────────────────────────────────────────────────

  static const _yahooSearchBase =
      'https://query1.finance.yahoo.com/v1/finance/search';

  static Future<List<YahooSearchResult>> searchAssets(String query) async {
    if (query.trim().isEmpty) return [];
    if (kIsWeb) return _proxySearch(query);
    try {
      final encoded = Uri.encodeComponent(query.trim());
      final uri = Uri.parse(
        '$_yahooSearchBase?q=$encoded&lang=en-US&region=DE'
        '&quotesCount=15&newsCount=0&enableFuzzyQuery=false',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final quotes = (data['quotes'] as List?) ?? [];
      return quotes
          .whereType<Map<String, dynamic>>()
          .where((q) =>
              q['quoteType'] == 'ETF' || q['quoteType'] == 'EQUITY')
          .map((q) => YahooSearchResult(
                symbol: (q['symbol'] as String? ?? '').trim(),
                name: (q['shortname'] ?? q['longname'] ?? q['symbol'])
                        as String? ??
                    '',
                type: q['quoteType'] == 'ETF' ? 'ETF' : 'Aktie',
                exchange: (q['exchDisp'] ?? q['exchange'] ?? '') as String? ??
                    '',
              ))
          .where((r) => r.symbol.isNotEmpty && r.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
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
