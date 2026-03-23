import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/market_mover.dart';

const _marketMoversUrl =
    'https://us-central1-fintrack-a459c.cloudfunctions.net/getMarketMovers';

final marketMoversProvider =
    FutureProvider.autoDispose<MarketMoversResult>((ref) async {
  final res = await http
      .get(Uri.parse(_marketMoversUrl))
      .timeout(const Duration(seconds: 20));

  if (res.statusCode != 200) {
    throw Exception('Fehler beim Laden: ${res.statusCode}');
  }

  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return MarketMoversResult.fromJson(json);
});
