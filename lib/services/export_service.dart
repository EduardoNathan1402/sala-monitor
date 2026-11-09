import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/machine_metrics.dart';

class ExportService {
  Future<Directory> resolveExportDir({String? customPath}) async {
    if (customPath != null && customPath.trim().isNotEmpty) {
      final dir = Directory(customPath.trim());
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}SalaMonitor');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> appendMetricsCsv(
    MachineMetrics metrics, {
    String? customPath,
  }) async {
    final dir = await resolveExportDir(customPath: customPath);
    final file = File('${dir.path}${Platform.pathSeparator}metricas_powerbi.csv');
    final exists = await file.exists();
    final sink = file.openWrite(mode: FileMode.append);
    if (!exists) {
      sink.writeln(MachineMetrics.csvHeaders.join(','));
    }
    sink.writeln(metrics.toCsvRow());
    await sink.flush();
    await sink.close();
    return file;
  }

  Future<File> writeHostsCsv(
    List<NetworkHost> hosts, {
    String? customPath,
  }) async {
    final dir = await resolveExportDir(customPath: customPath);
    final file = File('${dir.path}${Platform.pathSeparator}hosts_rede.csv');
    final buffer = StringBuffer()
      ..writeln(NetworkHost.csvHeaders.join(','));
    for (final h in hosts) {
      buffer.writeln(h.toCsvRow());
    }
    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<File> writeLatestJson(
    MachineMetrics metrics,
    List<NetworkHost> hosts, {
    String? customPath,
  }) async {
    final dir = await resolveExportDir(customPath: customPath);
    final file = File('${dir.path}${Platform.pathSeparator}ultimo_snapshot.json');
    final payload = {
      'gerado_em': DateTime.now().toIso8601String(),
      'maquina_local': metrics.toJson(),
      'hosts_ativos': hosts.where((h) => h.isReachable).length,
      'hosts_total': hosts.length,
      'hosts': hosts.map((h) => h.toJson()).toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file;
  }
}
