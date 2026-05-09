/// Gemini-Vision-based financial data extractor.
///
/// Auto-discovers the best available model for the API key by calling
/// ListModels, then sends screenshots and parses the returned JSON.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/config/api_keys.dart';
import '../../../shared/data/known_assets.dart';
import 'financial_parser.dart';

class GeminiParserService {
  static const _model = 'gemini-2.5-flash';
  static const _apiVersion = 'v1beta';

  static const _systemPrompt = '''
You are a financial data extractor for a personal finance app.
Analyze the screenshot and extract ALL financial positions (accounts, ETFs, stocks, crypto, etc.).

Return ONLY a valid JSON array — no explanation, no markdown fences.
Each object uses these exact keys (omit fields you cannot determine):

- "type": one of "giro", "festgeld", "etf", "crypto"
  - giro: checking/savings accounts (Girokonto, Tagesgeld, Gehaltskonto)
  - festgeld: fixed-term deposits with interest rate and end date
  - etf: ETFs, stocks, funds in a depot
  - crypto: cryptocurrency holdings
- "bankOrBroker": institution name (e.g. "ING", "Trade Republic", "Crypto.com")
- "label": human-readable label (e.g. "Girokonto", "Tagesgeld", coin name like "Bitcoin")
- "primaryAmount": current total value in EUR as a number (e.g. 1234.56)
- "ticker": ETF ticker/ISIN or crypto ticker (e.g. "EUNL", "IE00B4L5Y983", "BTC")
- "shares": number of shares or coins held as a number
- "currentPrice": price per share/coin in EUR as a number
- "gainPercent": gain since purchase as a signed number (e.g. 15.83 or -3.20)
- "interestRate": annual interest rate % for Festgeld (e.g. 3.5)
- "durationMonths": term in months for Festgeld (e.g. 12)
- "endDate": maturity date as "DD.MM.YYYY" for Festgeld

Return [] if no financial data is found.
''';

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Parses [images] using Gemini Vision. [userHint] is passed as extra context.
  static Future<List<ParsedAsset>> parseImages(
    List<XFile> images,
    String? userHint,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/$_apiVersion/models'
      '/$_model:generateContent?key=${ApiKeys.gemini}',
    );

    final results = <ParsedAsset>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      final mime = _mimeType(image.name);
      final prompt = userHint != null && userHint.isNotEmpty
          ? '$_systemPrompt\nUser context: "$userHint"'
          : _systemPrompt;

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {'inline_data': {'mime_type': mime, 'data': base64Encode(bytes)}},
            ],
          }
        ],
        'generationConfig': {'temperature': 0.1},
      });

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final text =
            (((json['candidates'] as List).first)['content']['parts'] as List)
                .first['text'] as String;
        results.addAll(_parseResponse(text));
      } else {
        debugPrint('Gemini ${res.statusCode}: ${res.body}');
        throw Exception(
          'Gemini API Fehler ${res.statusCode} — ${_extractError(res.body)}',
        );
      }
    }
    return results;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _mimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  static String _extractError(String body) {
    try {
      return (jsonDecode(body)['error'] as Map?)?['message'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }

  static List<ParsedAsset> _parseResponse(String text) {
    final jsonStr = _extractJson(text);
    if (jsonStr == null) {
      debugPrint('GeminiParserService: no JSON array in:\n$text');
      return [];
    }
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.whereType<Map<String, dynamic>>().map(_fromJson).toList();
    } catch (e) {
      debugPrint('GeminiParserService JSON error: $e\nRaw: $text');
      return [];
    }
  }

  static String? _extractJson(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start == -1 || end <= start) return null;
    return cleaned.substring(start, end + 1);
  }

  static ParsedAsset _fromJson(Map<String, dynamic> j) {
    final type = switch (j['type'] as String? ?? '') {
      'giro' => ParsedAssetType.giro,
      'festgeld' => ParsedAssetType.festgeld,
      'etf' => ParsedAssetType.etf,
      'crypto' => ParsedAssetType.crypto,
      _ => ParsedAssetType.unknown,
    };

    DateTime? endDate;
    final dateStr = j['endDate'] as String?;
    if (dateStr != null) {
      final p = dateStr.split('.');
      if (p.length == 3) endDate = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    }

    final ticker = j['ticker'] as String?;
    final label = j['label'] as String?;

    KnownEtf? matched;
    if (type == ParsedAssetType.etf) {
      matched = FinancialParser.matchKnownEtf(ticker) ??
          FinancialParser.matchKnownEtf(label);
    }

    return ParsedAsset(
      type: type == ParsedAssetType.unknown ? ParsedAssetType.giro : type,
      bankOrBroker: j['bankOrBroker'] as String?,
      label: type == ParsedAssetType.crypto ? null : label,
      primaryAmount: (j['primaryAmount'] as num?)?.toDouble(),
      interestRate: (j['interestRate'] as num?)?.toDouble(),
      durationMonths: (j['durationMonths'] as num?)?.toInt(),
      endDate: endDate,
      ticker: ticker,
      shares: (j['shares'] as num?)?.toDouble(),
      currentPrice: (j['currentPrice'] as num?)?.toDouble(),
      gainPercent: (j['gainPercent'] as num?)?.toDouble(),
      matchedEtf: matched,
      coinName: type == ParsedAssetType.crypto ? (label ?? ticker) : null,
      confidence: 0.92,
      rawText: j.toString(),
    );
  }
}
