import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/machine_metrics.dart';

class PowerBiService {
  /// Envia uma linha para um Streaming Dataset do Power BI.
  /// URL típica:
  /// https://api.powerbi.com/beta/.../datasets/.../rows?key=...
  Future<void> pushMetrics({
    required String pushUrl,
    required MachineMetrics metrics,
  }) async {
    final uri = Uri.tryParse(pushUrl.trim());
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      throw Exception('URL do Power BI inválida.');
    }

    final body = jsonEncode([metrics.toPowerBiRow()]);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Power BI respondeu ${response.statusCode}: ${response.body}',
      );
    }
  }
}
