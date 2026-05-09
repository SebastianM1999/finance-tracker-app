/// On-device financial data extractor.
///
/// Takes raw OCR text (one string per image) plus an optional user hint and
/// returns one [ParsedAsset] per image with as many fields populated as the
/// text allows.  No network calls – pure Dart.
library;

import '../../../shared/data/known_assets.dart';

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
    this.gainPercent,
    this.matchedEtf,
    this.coinName,
    required this.confidence,
    required this.rawText,
  });

  final ParsedAssetType type;
  final String? bankOrBroker;
  final String? label;

  /// Total current position value (Giro balance / Festgeld deposit / ETF value).
  final double? primaryAmount;

  final double? interestRate;
  final int? durationMonths;
  final DateTime? endDate;
  final String? ticker;
  final double? shares;
  final double? currentPrice;

  /// Return since purchase in percent (e.g. 15.83 for +15,83 %).
  /// Negative for a loss. ETF/Crypto only.
  final double? gainPercent;

  /// Best fuzzy match from [KnownAssets.etfsAndStocks], or null if no confident match.
  final KnownEtf? matchedEtf;

  /// Derived purchase value: primaryAmount / (1 + gainPercent/100).
  double? get purchaseValue {
    if (primaryAmount == null || gainPercent == null) return null;
    return primaryAmount! / (1 + gainPercent! / 100);
  }

  final String? coinName;
  final double confidence;
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
    'Revolut', 'Oyak', 'Oyak Bank',
    // Brokers
    'Trade Republic', 'Scalable Capital', 'Scalable', 'Flatex',
    'OnVista', 'Smartbroker', 'Comdirect',
    // Crypto exchanges
    'Kraken', 'Coinbase', 'Binance', 'Bitpanda', 'Bison',
    'Bitvavo', 'Nexo', 'Crypto.com',
  ];

  // ── Public API ───────────────────────────────────────────────────────────

  /// Parse [ocrTexts] (one per image) using an optional free-text [userHint].
  /// A single image may contain a list of accounts — in that case multiple
  /// [ParsedAsset]s are returned for that image.
  static List<ParsedAsset> parseAll(List<String> ocrTexts, String? userHint) {
    final hint = userHint?.toLowerCase().trim();
    final hintType = _parseHintType(hint);
    final hintBank = _extractBankFromHint(userHint);
    final results = <ParsedAsset>[];
    for (final text in ocrTexts) {
      // Strategy 3: crypto portfolio list (e.g. crypto.com Übersicht)
      if (hintType == ParsedAssetType.crypto || _isCryptoList(text)) {
        final cryptos = _parseCryptoList(text, hintBank);
        if (cryptos.isNotEmpty) {
          results.addAll(cryptos);
          continue;
        }
      }
      final blocks = _splitIntoAccountBlocks(text);
      results.addAll(blocks.map((b) => _parse(b, hintType, hintBank: hintBank)));
    }
    return results;
  }

  /// Splits OCR text into per-account blocks. Supports two layouts:
  ///
  /// 1. Account-type keyword headers on their own line (Festgeld, Tagesgeld …)
  /// 2. ETF/stock list rows identified by "X Stück zu Y EUR" pattern (ING-style)
  static List<String> _splitIntoAccountBlocks(String text) {
    final lines = text.split('\n');

    // ── Strategy 1: keyword headers ──────────────────────────────────────────
    final headerRe = RegExp(
      r'^(Festgeld|Tagesgeld|Girokonto|Gehaltskonto|Sparkonto|Konto)\s*$',
      caseSensitive: false,
    );
    final headerIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (headerRe.hasMatch(lines[i].trim())) headerIndices.add(i);
    }
    if (headerIndices.length >= 2) {
      final blocks = <String>[];
      for (var h = 0; h < headerIndices.length; h++) {
        final from = headerIndices[h];
        final to = h + 1 < headerIndices.length ? headerIndices[h + 1] : lines.length;
        blocks.add(lines.sublist(from, to).join('\n'));
      }
      if (headerIndices.first > 0) {
        blocks[0] = '${lines.sublist(0, headerIndices.first).join('\n')}\n${blocks[0]}';
      }
      return blocks;
    }

    // ── Strategy 2: ETF list rows ("X Stück zu Y EUR") ───────────────────────
    final stueckRe = RegExp(
      r'\d+[,.]?\d*\s+Stück\s+zu\s+\d',
      caseSensitive: false,
    );
    final stueckIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (stueckRe.hasMatch(lines[i])) stueckIndices.add(i);
    }
    if (stueckIndices.length >= 2) {
      return _splitEtfListBlocks(lines, stueckIndices);
    }

    return [text];
  }

  /// Splits an ETF list by anchoring on "Stück zu" lines.
  /// Each block = [name lines] + [Stück zu line] + [optional total line].
  static List<String> _splitEtfListBlocks(List<String> lines, List<int> stueckIdxs) {
    // Standalone amount-only line (e.g. "5.122,65 EUR" or "26 055,38 EUR")
    // Allows space or period/comma as thousands separator for OCR variations.
    final totalLineRe = RegExp(
      r'^\+?-?\d{1,3}(?:[\s.,]\d{3})*[.,]\d{2}\s*(?:EUR)?\s*$',
    );

    // Determine where each block ends (after its total line)
    final blockEnds = stueckIdxs.map((si) {
      final nextIdx = si + 1;
      // If the Stück-zu line already contains a second EUR amount, total is inline
      final stueckLine = lines[si];
      final eurCount = 'EUR'.allMatches(stueckLine).length;
      if (eurCount >= 2) return si + 1;
      if (nextIdx < lines.length && totalLineRe.hasMatch(lines[nextIdx].trim())) {
        return nextIdx + 1;
      }
      return si + 1;
    }).toList();

    final blocks = <String>[];
    for (var h = 0; h < stueckIdxs.length; h++) {
      final from = h == 0 ? 0 : blockEnds[h - 1];
      final to = blockEnds[h];
      blocks.add(lines.sublist(from, to).join('\n'));
    }
    return blocks;
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  static ParsedAssetType? _parseHintType(String? hint) {
    if (hint == null || hint.isEmpty) return null;
    // Count how many distinct asset types are mentioned. If >1, return null so
    // per-block OCR detection handles each entry individually.
    final matches = <ParsedAssetType>{};
    if (_containsAny(hint, ['giro', 'girokonto', 'tagesgeld', 'checking'])) {
      matches.add(ParsedAssetType.giro);
    }
    if (_containsAny(hint, ['festgeld', 'zinsen', 'fixed', 'deposit'])) {
      matches.add(ParsedAssetType.festgeld);
    }
    if (_containsAny(hint, ['etf', 'aktien', 'aktie', 'stock', 'depot', 'fonds'])) {
      matches.add(ParsedAssetType.etf);
    }
    if (_containsAny(hint, ['krypto', 'crypto', 'bitcoin', 'coin', 'token', 'wallet'])) {
      matches.add(ParsedAssetType.crypto);
    }
    if (matches.length == 1) return matches.first;
    return null; // mixed or none — let per-block detection decide
  }

  /// Extracts a bank/broker name from the user's free-text hint.
  /// Looks for "von <Name>", "bei <Name>", or a known bank name anywhere.
  static String? _extractBankFromHint(String? hint) {
    if (hint == null || hint.isEmpty) return null;
    // "von Oyak Bank", "bei ING", etc.
    final vonMatch = RegExp(
      r'\b(?:von|bei|from|at)\s+([A-ZÄÖÜ][A-Za-zäöüÄÖÜ0-9 &.]{1,30})',
    ).firstMatch(hint);
    if (vonMatch != null) return vonMatch.group(1)!.trim();
    // Known bank names anywhere in the hint
    final lower = hint.toLowerCase();
    for (final name in _knownBanks) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    return null;
  }

  static ParsedAsset _parse(String text, ParsedAssetType? hintType, {String? hintBank}) {
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
    final bankOrBroker = hintBank ?? _extractInstitution(text);

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
        final etfName = _extractEtfName(text) ?? _extractTicker(text);
        final matched = matchKnownEtf(etfName);
        return ParsedAsset(
          type: type,
          bankOrBroker: bankOrBroker,
          ticker: etfName,
          shares: _extractShares(lower),
          primaryAmount: primaryAmount,
          currentPrice: _extractPriceFromStueck(text),
          gainPercent: _extractGainPercent(text),
          matchedEtf: matched,
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

    // Giro / Tagesgeld (flexible accounts, no fixed term)
    _score(scores, ParsedAssetType.giro, lower, 'girokonto', 5);
    _score(scores, ParsedAssetType.giro, lower, 'gehaltskonto', 5);
    _score(scores, ParsedAssetType.giro, lower, 'tagesgeld', 5);
    _score(scores, ParsedAssetType.giro, lower, 'iban', 4);
    _score(scores, ParsedAssetType.giro, lower, 'kontostand', 3);
    _score(scores, ParsedAssetType.giro, lower, 'verfügbar', 2);
    _score(scores, ParsedAssetType.giro, lower, 'überweisen', 2);
    _score(scores, ParsedAssetType.giro, lower, 'lastschrift', 2);
    _score(scores, ParsedAssetType.giro, lower, 'guthaben', 1);

    // Festgeld (fixed term only)
    _score(scores, ParsedAssetType.festgeld, lower, 'festgeld', 6);
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

  static const _accountTypeWords = {
    'festgeld', 'tagesgeld', 'girokonto', 'gehaltskonto', 'sparkonto', 'konto',
  };

  static String? _extractInstitution(String text) {
    final lower = text.toLowerCase();
    for (final name in _knownBanks) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    // Fall back to first non-empty line that looks like a name but is not an
    // account-type keyword, an IBAN, or a pure number/amount.
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.length < 2 || t.length > 35) continue;
      if (RegExp(r'^[\d€$]').hasMatch(t)) continue; // digits or currency symbol
      if (_accountTypeWords.contains(t.toLowerCase())) continue;
      if (RegExp(r'^[A-Z]{2}\d{2}').hasMatch(t)) continue; // IBAN
      if (RegExp(r'\d{1,3}[.,]\d{3}[.,]\d{2}').hasMatch(t)) continue; // amount
      return t;
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
    // "127,77165 Stück zu" or "13 Stück zu" (ING format)
    var m = RegExp(r'(\d+[,.]?\d*)\s+stück\s+zu').firstMatch(lower);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', '.'));
    // Generic: anteile, shares, stücke, etc.
    m = RegExp(
      r'(\d+[,.]?\d*)\s*(?:anteile?|stücke?|stück|shares?|units?|stk\.?)',
    ).firstMatch(lower);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  /// Fuzzy-matches an ETF name against [KnownAssets.etfsAndStocks].
  /// Returns the best match with Jaccard similarity ≥ 0.25, or null.
  static KnownEtf? matchKnownEtf(String? input) {
    if (input == null) return null;

    // Direct ticker match — handles "EQQQ", "EQQQ.DE", "CNDX", etc.
    final tickerClean = input.trim().toUpperCase();
    for (final etf in KnownAssets.etfsAndStocks) {
      final t = etf.ticker.toUpperCase();
      if (t == tickerClean || t.replaceAll('.DE', '') == tickerClean) return etf;
    }

    // Fuzzy name match via Jaccard similarity
    final ocrTokens = _normalizeEtfName(input);
    if (ocrTokens.isEmpty) return null;

    KnownEtf? best;
    double bestScore = 0.25;

    for (final etf in KnownAssets.etfsAndStocks) {
      final known = _normalizeEtfName(etf.name);
      final intersection = ocrTokens.intersection(known).length;
      final union = ocrTokens.union(known).length;
      if (union == 0) continue;
      final score = intersection / union;
      if (score > bestScore) {
        bestScore = score;
        best = etf;
      }
    }
    return best;
  }

  /// Normalises an ETF name to a set of meaningful lowercase tokens for
  /// fuzzy comparison. Expands common broker abbreviations used by ING etc.
  static Set<String> _normalizeEtfName(String name) {
    var s = name.toLowerCase()
        .replaceAll('u.etf', 'etf')
        .replaceAll(RegExp(r'\bdla\b|\bdld\b|\b dl\b'), '') // listing suffixes
        .replaceAll(RegExp(r'\bishs[ivxlcdm]*[-\s]'), 'ishares ') // ISHSIII- etc.
        .replaceAll('ishs', 'ishares')
        .replaceAll('wld', 'world')
        .replaceAll('wrld', 'world')
        .replaceAll('emimi', 'em imi')
        .replaceAll('em imi', 'em imi') // already expanded
        .replaceAll(RegExp(r'[.,\-/]'), ' ');
    // Remove noise words
    final stopWords = {'bank', 'ag', 'se', 'plc', 'ltd', 'inc', 'acc', 'dist', 'dla', 'dld'};
    return s
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 2 && !stopWords.contains(t))
        .toSet();
  }

  /// Extracts the per-ETF signed gain percentage (e.g. "+15,83 %" → 15.83).
  /// Skips lines that also contain EUR amounts — those are portfolio totals
  /// (e.g. "+13,95 % +4.242,28 EUR"), not per-position returns.
  static double? _extractGainPercent(String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.contains('EUR')) continue; // portfolio-total line — skip
      final m = RegExp(r'([+-])(\d+)[,.](\d+)\s*%').firstMatch(t);
      if (m != null) {
        final sign = m.group(1) == '-' ? -1 : 1;
        return sign * double.parse('${m.group(2)}.${m.group(3)}');
      }
    }
    return null;
  }

  /// Extracts the price per unit from "X Stück zu PRICE EUR" (ING format).
  static double? _extractPriceFromStueck(String text) {
    final m = RegExp(
      r'Stück\s+zu\s+(\d+[,.]?\d*)\s*EUR',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  // Known fund manager / issuer names that appear as OCR artefacts (logos etc.)
  static const _fundManagers = {
    'blackrock', 'vaneck', 'vanguard', 'ishares', 'amundi', 'xtrackers',
    'invesco', 'spdr', 'lyxor', 'wisdomtree', 'dws', 'ubs', 'pimco',
  };

  // Currency / unit codes that should never be an ETF name
  static const _currencyCodes = {'eur', 'usd', 'gbp', 'chf', 'jpy', 'acc', 'dist'};

  /// Extracts the full fund name from an ETF block — the readable lines
  /// appearing before the "Stück zu" anchor, stripped of percentages/amounts.
  static String? _extractEtfName(String text) {
    final stueckRe = RegExp(r'\d+[,.]?\d*\s+Stück\s+zu', caseSensitive: false);
    final skipRe = RegExp(
      r'^[\d+\-€$%]'           // starts with digit/sign/currency symbol
      r'|^ETFs?$'              // "ETF" or "ETFs" standalone
      r'|^Bestand|^Depot|^Rendite|^Bestandswert|^Depotübersicht',
      caseSensitive: false,
    );
    final nameParts = <String>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (stueckRe.hasMatch(t)) break;
      if (t.isEmpty || skipRe.hasMatch(t)) continue;
      // Must start with uppercase — filters OCR garbage like "l 65 +"
      if (!RegExp(r'^[A-ZÄÖÜ0-9]').hasMatch(t)) continue;
      // Skip fund manager logo text and currency codes
      final lower = t.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (_fundManagers.contains(lower) || _currencyCodes.contains(lower)) continue;
      // Strip trailing percentage ("+15,83 %") OCR puts on the name line
      final cleaned = t
          .replaceAll(RegExp(r'\s*[+-]\d+[,.]\d+\s*%\s*$'), '')
          .trim();
      if (cleaned.isNotEmpty) nameParts.add(cleaned);
    }
    return nameParts.isEmpty ? null : nameParts.join(' ');
  }

  // ── Crypto list parsing (e.g. crypto.com, Bitpanda overview) ────────────────

  /// Known crypto tickers — used to distinguish "426,51 XRP" from ETF amounts.
  static const _knownCryptoTickers = {
    'BTC', 'ETH', 'XRP', 'SOL', 'ADA', 'DOT', 'MATIC', 'AVAX', 'LINK',
    'ATOM', 'DOGE', 'LTC', 'CRO', 'HBAR', 'VET', 'ALGO', 'XLM', 'TRX',
    'BCH', 'UNI', 'AAVE', 'GRT', 'FIL', 'SHIB', 'ARB', 'OP', 'IMX',
    'SAND', 'MANA', 'AXS', 'ENJ', 'CHZ', 'FLOW', 'ROSE', 'NEAR', 'FTM',
    'ONE', 'HOT', 'BAT', 'SNX', 'PEPE', 'FLOKI', 'ICP', 'HNT', 'THETA',
  };

  static const _cryptoTickerToName = {
    'BTC': 'Bitcoin', 'ETH': 'Ethereum', 'XRP': 'XRP', 'SOL': 'Solana',
    'ADA': 'Cardano', 'DOT': 'Polkadot', 'MATIC': 'Polygon', 'AVAX': 'Avalanche',
    'LINK': 'Chainlink', 'ATOM': 'Cosmos', 'DOGE': 'Dogecoin', 'LTC': 'Litecoin',
    'CRO': 'Cronos', 'HBAR': 'Hedera', 'VET': 'VeChain', 'ALGO': 'Algorand',
    'XLM': 'Stellar', 'TRX': 'TRON', 'BCH': 'Bitcoin Cash', 'UNI': 'Uniswap',
    'AAVE': 'Aave', 'GRT': 'The Graph', 'FIL': 'Filecoin', 'SHIB': 'Shiba Inu',
    'ARB': 'Arbitrum', 'OP': 'Optimism', 'IMX': 'Immutable X',
    'SAND': 'The Sandbox', 'MANA': 'Decentraland', 'AXS': 'Axie Infinity',
    'ENJ': 'Enjin', 'CHZ': 'Chiliz', 'FLOW': 'Flow', 'NEAR': 'NEAR Protocol',
    'FTM': 'Fantom', 'BAT': 'Basic Attention Token',
  };

  /// Regex matching a crypto amount line: "426,51 XRP" or "0,00592 BTC".
  static final _cryptoRowRe = RegExp(r'^(\d[\d.,]*)\s+([A-Z]{2,6})\b');

  /// Returns true when the text contains ≥ 2 known crypto amount lines.
  static bool _isCryptoList(String text) {
    int count = 0;
    for (final line in text.split('\n')) {
      final m = _cryptoRowRe.firstMatch(line.trim());
      if (m != null && _knownCryptoTickers.contains(m.group(2))) {
        count++;
        if (count >= 2) return true;
      }
    }
    return false;
  }

  /// Parses a crypto portfolio overview into individual [ParsedAsset]s.
  static List<ParsedAsset> _parseCryptoList(String text, String? hintBank) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final results = <ParsedAsset>[];

    for (var i = 0; i < lines.length; i++) {
      final m = _cryptoRowRe.firstMatch(lines[i]);
      if (m == null) continue;
      final ticker = m.group(2)!;
      if (!_knownCryptoTickers.contains(ticker)) continue;

      final shares = _parseGermanNum(m.group(1)!);

      // Name: preceding line that is plain text (no digits/€/%)
      String? name;
      if (i > 0) {
        final prev = lines[i - 1];
        if (prev.isNotEmpty &&
            !RegExp(r'^[\d€+\-]').hasMatch(prev) &&
            !prev.contains('%') &&
            prev.length <= 30) {
          name = prev;
        }
      }

      // Collect surrounding lines for value/gain extraction
      final windowLines = <String>[];
      for (var j = (i - 1).clamp(0, lines.length - 1);
          j <= (i + 3).clamp(0, lines.length - 1);
          j++) {
        windowLines.add(lines[j]);
      }
      final window = windowLines.join('\n');

      // Extract €value
      double? value;
      final vM = RegExp(r'€\s*(\d[\d.,]*)').firstMatch(window);
      if (vM != null) value = _parseGermanNum(vM.group(1)!);

      // Extract gain %
      double? gain;
      final gM = RegExp(r'([+-])(\d+)[,.](\d+)\s*%').firstMatch(window);
      if (gM != null) {
        gain = (gM.group(1) == '-' ? -1 : 1) *
            double.parse('${gM.group(2)}.${gM.group(3)}');
      }

      results.add(ParsedAsset(
        type: ParsedAssetType.crypto,
        bankOrBroker: hintBank,
        coinName: name ?? _cryptoTickerToName[ticker] ?? ticker,
        ticker: ticker,
        shares: shares,
        primaryAmount: value,
        gainPercent: gain,
        confidence: name != null ? 0.90 : 0.75,
        rawText: window,
      ));
    }
    return results;
  }

  /// Parses a German-formatted number (e.g. "2.376,7" → 2376.7, "426,51" → 426.51).
  static double? _parseGermanNum(String s) {
    String clean = s;
    if (s.contains(',') && s.contains('.')) {
      clean = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains(',')) {
      clean = s.replaceAll(',', '.');
    }
    return double.tryParse(clean);
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
    if (lower.contains('tagesgeld')) return 'Tagesgeld';
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
