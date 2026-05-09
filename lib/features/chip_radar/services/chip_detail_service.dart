import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_detail.dart';

class ChipDetailService {
  static const _url =
      'https://us-central1-fintrack-a459c.cloudfunctions.net/getStockDetail';

  static Future<StockDetail?> fetch(String ticker) async {
    try {
      final resp = await http
          .get(Uri.parse('$_url?ticker=$ticker'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json.containsKey('error')) return null;
      return StockDetail.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
