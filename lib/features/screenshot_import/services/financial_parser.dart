/// On-device financial data extractor.
///
/// Takes raw OCR text (one string per image) plus an optional user hint and
/// returns one [ParsedAsset] per image with as many fields populated as the
/// text allows.  No network calls – pure Dart.
library;

enum ParsedAssetType { giro, festgeld, etf, crypto, unknown }

class ParsedAsset {
  const ParsedAsset({
    required this.type,
    this.bankOrBroker,
    this.label,
    this.primaryAmount,
    this.interestRate,
    this.durationMonths,
    this.endDate,
    this.ticker,
    this.shares,
    this.currentPrice,
    this.coinName,
    required this.confidence,
    required this.rawText,
  });

  final ParsedAssetType type;

  /// Bank name (Giro/Festgeld) or broker/exchange name (ETF/Crypto).
  final String? bankOrBroker;

  /// Account label such as "Girokonto", "Gehaltskonto".
  final String? label;

  /// Main monetary amount: balance (Giro), deposit amount (Festgeld),
  /// total position value (ETF/Crypto).
  final double? primaryAmount;

  /// Interest rate in percent (Festgeld only).
  final double? interestRate;

  /// Deposit term in months (Festgeld only).
  final int? durationMonths;

  /// Maturity / end date (Festgeld only).
  final DateTime? endDate;

  /// Ticker or ISIN (ETF/Stock only).
  final String? ticker;

  /// Number of shares / units (ETF/Stock only).
  final double? shares;

  /// Price per unit (ETF/Stock / Crypto).
  final double? currentPrice;

  /// Coin name or symbol (Crypto only).
  final String? coinName;

  /// 0.0–1.0 extraction confidence.
  final double confidence;

  /// Original OCR text (kept for debugging / manual review).
  final String rawText;
}

// ---------------------------------------------------------------------------

class FinancialParser {
  // ── Known institution names ──────────────────────────────────────────────

  static const _knownBanks = [
    // German banks
    'ING', 'DKB', 'N26', 'C24', 'Commerzbank', 'Deutsche Bank',
    'Postbank', 'Sparkasse', 'Volksbank', 'Raiffeisenbank',
    'Comdirect', 'Consorsbank', 'Santander', 'Targobank', 'Norisbank',
    'Hypovereinsbank', 'HVB', 'Baader Bank', 'Barclays', 'bunq',
    'Revolut',
    // Brokers
    'Trade Republic', 'Scalable Capital', 'Scalable', 'Flatex',
    'OnVista', 'Smartbroker', 'Comdirect',
    // Crypto exchanges
    'Kraken', 'Coinbase', 'Binance', 'Bitpanda', 'Bison',
    'Bitvavo', 'Nexo', 'Crypto.com',
  ];

  // ── Public API ───────────────────────────────────────────────────────────

  /// Parse [ocrTexts] (one per image) using an optional free-text [userHint].
  static List<ParsedAsset> parseAll(List<String> ocrTexts, String? userHint) {
    final hintType = _parseHintType(userHint?.toLowerCase().trim());
    return ocrTexts.map((t) => _parse(t, hintType)).toList();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  static ParsedAssetType? _parseHintType(String? hint) {
    if (hint == null || hint.isEmpty) return null;
    if (_containsAny(hint, ['giro', 'girokonto', 'konto', 'checking'])) {
      return ParsedAssetType.giro;
    }
    if (_containsAny(hint, ['festgeld', 'tagesgeld', 'zinsen', 'fixed', 'savings', 'deposit'])) {
      return ParsedAssetType.festgeld;
    }
    if (_containsAny(hint, ['etf', 'aktien', 'aktie', 'stock', 'depot', 'fonds'])) {
      return ParsedAssetType.etf;
    }
    if (_containsAny(hint, ['krypto', 'crypto', 'bitcoin', 'coin', 'token', 'wallet'])) {
      return ParsedAssetType.crypto;
    }
    return null;
  }

  static ParsedAsset _parse(String text, ParsedAssetType? hintType) {
    final lower = text.toLowerCase();
    final type = hintType ?? _detectType(lower);

    // Strip date-like strings before extracting amounts to avoid false hits
    final textForAmounts = text.replaceAll(
      RegExp(r'\d{2}[./]\d{2}[./]\d{4}|\d{4}-\d{2}-\d{2}'),
      '',
    );

    final amounts = _extractAllAmounts(textForAmounts);
    final primaryAmount = amounts.isNotEmpty
        ? amounts.reduce((a, b) => a > b ? a : b)
        : null;
    final bankOrBroker = _extractInstitution(text);

    switch (type) {
      case ParsedAssetType.festgeld:
        return ParsedAsset(
          type: type,
          bankOrBroker: bankOrBroker,
          primaryAmount: primaryAmount,
          interestRate: _extractInterestRate(text),
          durationMonths: _extractDurationMonths(lower),
          endDate: _extractDate(text),
          confidence: _calcConfidence(type, lower, primaryAmount, bankOrBroker),
          rawText: text,
        );

      case ParsedAssetType.etf:
        final sortedAmounts = [...amounts]..sort();
        return ParsedAsset(
          type: type,
          bankOrBroker: bankOrBroker,
          ticker: _extractTicker(text),
          shares: _extractShares(lower),
          primaryAmount: primaryAmount,
          currentPrice: sortedAmounts.isNotEmpty ? sortedAmounts.first : null,
          confidence: _calcConfidence(type, lower, primaryAmount, bankOrBroker),
          rawText: text,
        );

      case ParsedAssetType.crypto:
        return ParsedAsset(
          type: type,
          bankOrBroker: bankOrBroker,
          coinName: _extractCoinName(lower),
          primaryAmount: primaryAmount,
          currentPrice: amounts.isNotEmpty
              ? amounts.reduce((a, b) => a < b ? a : b)
              : null,
          confidence: _calcConfidence(type, lower, primaryAmount, bankOrBroker),
          rawText: text,
        );

      default: // giro / unknown
        return ParsedAsset(
          type: type == ParsedAssetType.unknown ? ParsedAssetType.giro : type,
          bankOrBroker: bankOrBroker,
          label: _extractAccountLabel(lower),
          primaryAmount: primaryAmount,
          confidence: _calcConfidence(type, lower, primaryAmount, bankOrBroker),
          rawText: text,
        );
    }
  }

  // ── Asset-type detection ─────────────────────────────────────────────────

  static ParsedAssetType _detectType(String lower) {
    final scores = <ParsedAssetType, int>{
      ParsedAssetType.giro: 0,
      ParsedAssetType.festgeld: 0,
      ParsedAssetType.etf: 0,
      ParsedAssetType.crypto: 0,
    };

    // Giro
    _score(scores, ParsedAssetType.giro, lower, 'girokonto', 5);
    _score(scores, ParsedAssetType.giro, lower, 'gehaltskonto', 5);
    _score(scores, ParsedAssetType.giro, lower, 'iban', 4);
    _score(scores, ParsedAssetType.giro, lower, 'kontostand', 3);
    _score(scores, ParsedAssetType.giro, lower, 'verfügbar', 2);
    _score(scores, ParsedAssetType.giro, lower, 'überweisen', 2);
    _score(scores, ParsedAssetType.giro, lower, 'lastschrift', 2);
    _score(scores, ParsedAssetType.giro, lower, 'guthaben', 1);

    // Festgeld / Tagesgeld
    _score(scores, ParsedAssetType.festgeld, lower, 'festgeld', 6);
    _score(scores, ParsedAssetType.festgeld, lower, 'tagesgeld', 4);
    _score(scores, ParsedAssetType.festgeld, lower, 'p.a.', 5);
    _score(scores, ParsedAssetType.festgeld, lower, 'per annum', 5);
    _score(scores, ParsedAssetType.festgeld, lower, 'zinssatz', 4);
    _score(scores, ParsedAssetType.festgeld, lower, 'zinsen', 3);
    _score(scores, ParsedAssetType.festgeld, lower, 'laufzeit', 3);
    _score(scores, ParsedAssetType.festgeld, lower, 'fälligkeit', 4);
    _score(scores, ParsedAssetType.festgeld, lower, 'auszahlung', 2);

    // ETF / Stocks
    _score(scores, ParsedAssetType.etf, lower, 'depot', 4);
    _score(scores, ParsedAssetType.etf, lower, 'etf', 5);
    _score(scores, ParsedAssetType.etf, lower, 'aktie', 4);
    _score(scores, ParsedAssetType.etf, lower, 'aktien', 4);
    _score(scores, ParsedAssetType.etf, lower, 'anteile', 3);
    _score(scores, ParsedAssetType.etf, lower, 'stücke', 3);
    _score(scores, ParsedAssetType.etf, lower, 'isin', 4);
    _score(scores, ParsedAssetType.etf, lower, 'wkn', 4);
    _score(scores, ParsedAssetType.etf, lower, 'kurs', 2);
    _score(scores, ParsedAssetType.etf, lower, 'fonds', 3);

    // Crypto
    _score(scores, ParsedAssetType.crypto, lower, 'bitcoin', 6);
    _score(scores, ParsedAssetType.crypto, lower, 'btc', 5);
    _score(scores, ParsedAssetType.crypto, lower, 'ethereum', 6);
    _score(scores, ParsedAssetType.crypto, lower, 'eth', 4);
    _score(scores, ParsedAssetType.crypto, lower, 'krypto', 5);
    _score(scores, ParsedAssetType.crypto, lower, 'crypto', 5);
    _score(scores, ParsedAssetType.crypto, lower, 'wallet', 3);
    _score(scores, ParsedAssetType.crypto, lower, 'blockchain', 3);
    _score(scores, ParsedAssetType.crypto, lower, 'satoshi', 4);

    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value == 0) return ParsedAssetType.unknown;
    return best.key;
  }

  static void _score(
    Map<ParsedAssetType, int> scores,
    ParsedAssetType type,
    String lower,
    String keyword,
    int points,
  ) {
    if (lower.contains(keyword)) {
      scores[type] = scores[type]! + points;
    }
  }

  // ── Institution extraction ───────────────────────────────────────────────

  static String? _extractInstitution(String text) {
    final lower = text.toLowerCase();
    for (final name in _knownBanks) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    // Fall back to first non-empty line if it looks like a name
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.length >= 2 && t.length <= 35 && !RegExp(r'^\d').hasMatch(t)) {
        return t;
      }
    }
    return null;
  }

  // ── Amount extraction ────────────────────────────────────────────────────

  static List<double> _extractAllAmounts(String text) {
    final results = <double>{};

    // German format: 1.234,56 € or € 1.234,56
    for (final m in RegExp(
      r'(?:€\s*)?(\d{1,3}(?:\.\d{3})*),(\d{2})(?:\s*(?:€|EUR))?',
    ).allMatches(text)) {
      final v = _toDouble(m.group(1)!.replaceAll('.', ''), m.group(2)!);
      if (v != null && v > 0) results.add(v);
    }

    // English format: 1,234.56 € or € 1,234.56
    for (final m in RegExp(
      r'(?:[€\$]\s*)?(\d{1,3}(?:,\d{3})*)\.(\d{2})(?:\s*(?:€|EUR|\$))?',
    ).allMatches(text)) {
      final v = _toDouble(m.group(1)!.replaceAll(',', ''), m.group(2)!);
      if (v != null && v > 0) results.add(v);
    }

    return results.toList();
  }

  static double? _toDouble(String intPart, String decPart) =>
      double.tryParse('$intPart.$decPart');

  // ── Field extractors ─────────────────────────────────────────────────────

  static double? _extractInterestRate(String text) {
    // e.g.  3,50 % p.a.  or  3.5%  or  3%
    var m = RegExp(r'(\d+)[,.](\d+)\s*%').firstMatch(text);
    if (m != null) return double.tryParse('${m.group(1)}.${m.group(2)}');
    m = RegExp(r'(\d+)\s*%').firstMatch(text);
    if (m != null) return double.tryParse(m.group(1)!);
    return null;
  }

  static int? _extractDurationMonths(String lower) {
    var m = RegExp(r'(\d+)\s*(?:monate?|months?)').firstMatch(lower);
    if (m != null) return int.tryParse(m.group(1)!);
    m = RegExp(r'(\d+)\s*(?:jahre?|years?)').firstMatch(lower);
    if (m != null) {
      final y = int.tryParse(m.group(1)!);
      if (y != null) return y * 12;
    }
    return null;
  }

  static DateTime? _extractDate(String text) {
    // DD.MM.YYYY
    var m = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(text);
    if (m != null) {
      return _tryDate(m.group(3)!, m.group(2)!, m.group(1)!);
    }
    // YYYY-MM-DD
    m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (m != null) {
      return _tryDate(m.group(1)!, m.group(2)!, m.group(3)!);
    }
    return null;
  }

  static DateTime? _tryDate(String y, String mo, String d) {
    final year = int.tryParse(y);
    final month = int.tryParse(mo);
    final day = int.tryParse(d);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static String? _extractTicker(String text) {
    // Prefer full ISIN
    var m = RegExp(r'\b([A-Z]{2}[0-9A-Z]{10})\b').firstMatch(text);
    if (m != null) return m.group(1);
    // Short ticker: 2-5 uppercase letters not inside longer words
    m = RegExp(r'(?<!\w)([A-Z]{2,5})(?!\w)').firstMatch(text);
    return m?.group(1);
  }

  static double? _extractShares(String lower) {
    final m = RegExp(
      r'(\d+[,.]?\d*)\s*(?:anteile?|stücke?|stück|shares?|units?|stk\.?)',
    ).firstMatch(lower);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  static String? _extractCoinName(String lower) {
    const coins = {
      'bitcoin': 'Bitcoin', 'btc': 'Bitcoin',
      'ethereum': 'Ethereum', 'eth': 'Ethereum',
      'solana': 'Solana', 'sol': 'Solana',
      'cardano': 'Cardano', 'ada': 'Cardano',
      'ripple': 'Ripple', 'xrp': 'Ripple',
      'litecoin': 'Litecoin', 'ltc': 'Litecoin',
      'dogecoin': 'Dogecoin', 'doge': 'Dogecoin',
      'polkadot': 'Polkadot', 'dot': 'Polkadot',
      'chainlink': 'Chainlink', 'link': 'Chainlink',
      'polygon': 'Polygon', 'matic': 'Polygon',
      'avalanche': 'Avalanche', 'avax': 'Avalanche',
      'cosmos': 'Cosmos', 'atom': 'Cosmos',
    };
    for (final entry in coins.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String? _extractAccountLabel(String lower) {
    if (lower.contains('girokonto')) return 'Girokonto';
    if (lower.contains('gehaltskonto')) return 'Gehaltskonto';
    if (lower.contains('konto')) return 'Konto';
    return null;
  }

  // ── Confidence ───────────────────────────────────────────────────────────

  static double _calcConfidence(
    ParsedAssetType type,
    String lower,
    double? amount,
    String? institution,
  ) {
    double score = 0.0;
    if (amount != null) score += 0.40;
    if (institution != null) score += 0.25;
    switch (type) {
      case ParsedAssetType.giro:
        if (_containsAny(lower, ['girokonto', 'iban', 'kontostand'])) score += 0.35;
      case ParsedAssetType.festgeld:
        if (_containsAny(lower, ['festgeld', 'p.a.', 'zinssatz'])) score += 0.35;
      case ParsedAssetType.etf:
        if (_containsAny(lower, ['depot', 'isin', 'aktie', 'etf'])) score += 0.35;
      case ParsedAssetType.crypto:
        if (_containsAny(lower, ['bitcoin', 'ethereum', 'wallet', 'crypto'])) score += 0.35;
      default:
        break;
    }
    return score.clamp(0.0, 1.0);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);
}
