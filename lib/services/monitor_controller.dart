import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/machine_metrics.dart';
import 'app_settings.dart';
import 'export_service.dart';
import 'metrics_collector.dart';
import 'powerbi_service.dart';

class MonitorController extends ChangeNotifier {
  MonitorController({
    MetricsCollector? collector,
    ExportService? exporter,
    PowerBiService? powerBi,
  })  : _collector = collector ?? MetricsCollector(),
        _exporter = exporter ?? ExportService(),
        _powerBi = powerBi ?? PowerBiService();

  final MetricsCollector _collector;
  final ExportService _exporter;
  final PowerBiService _powerBi;

  AppSettings settings = AppSettings();
  MachineMetrics? latest;
  List<NetworkHost> hosts = [];
  final List<MachineMetrics> history = [];
  final List<double> roomLossHistory = [];
  final List<double> roomLatencyHistory = [];
  String? exportPathShown;
  String? lastError;
  String? lastStatus;
  bool running = false;
  bool collecting = false;

  Timer? _timer;
  double totalGbSession = 0;

  Future<void> init() async {
    settings = await AppSettings.load();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await settings.save();
    if (running) {
      await stop();
      await start();
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (running) return;
    running = true;
    lastError = null;
    lastStatus = 'Monitoramento iniciado';
    notifyListeners();
    await collectOnce();
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: settings.intervalSeconds.clamp(10, 600)),
      (_) => collectOnce(),
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    running = false;
    lastStatus = 'Monitoramento parado';
    notifyListeners();
  }

  Future<void> collectOnce() async {
    if (collecting) return;
    collecting = true;
    lastError = null;
    notifyListeners();

    try {
      final metrics = await _collector.collect(
        sala: settings.sala,
        pingTarget: settings.pingTarget.isEmpty ? null : settings.pingTarget,
      );
      latest = metrics;
      totalGbSession += metrics.gbTotalDelta;
      history.add(metrics);
      if (history.length > 120) {
        history.removeRange(0, history.length - 120);
      }

      if (settings.monitorSalaIps) {
        final ips = settings.salaIps;
        if (ips.isEmpty) {
          hosts = [];
          lastStatus =
              'Configure os IPs da sala em Configurações para analisar as máquinas';
        } else {
          hosts = await _collector.probeSalaHosts(ips);
          final online = hosts.where((h) => h.isReachable).toList();
          final avgLoss = online.isEmpty
              ? 100.0
              : online.map((h) => h.lossPct).reduce((a, b) => a + b) /
                  online.length;
          final avgLat = online.isEmpty
              ? 0.0
              : online.map((h) => h.latencyMs).reduce((a, b) => a + b) /
                  online.length;
          roomLossHistory.add(avgLoss);
          roomLatencyHistory.add(avgLat);
          if (roomLossHistory.length > 120) {
            roomLossHistory.removeAt(0);
            roomLatencyHistory.removeAt(0);
          }
        }
      }

      if (settings.autoExport) {
        final csv = await _exporter.appendMetricsCsv(
          metrics,
          customPath: settings.exportPath.isEmpty ? null : settings.exportPath,
        );
        await _exporter.writeHostsCsv(
          hosts,
          customPath: settings.exportPath.isEmpty ? null : settings.exportPath,
        );
        await _exporter.writeLatestJson(
          metrics,
          hosts,
          customPath: settings.exportPath.isEmpty ? null : settings.exportPath,
        );
        exportPathShown = csv.parent.path;
      }

      if (settings.pushToPowerBi && settings.powerBiPushUrl.isNotEmpty) {
        await _powerBi.pushMetrics(
          pushUrl: settings.powerBiPushUrl,
          metrics: metrics,
        );
      }

      if (hosts.isNotEmpty || settings.salaIps.isNotEmpty) {
        lastStatus =
            'Atualizado ${metrics.timestamp.hour.toString().padLeft(2, '0')}:'
            '${metrics.timestamp.minute.toString().padLeft(2, '0')}:'
            '${metrics.timestamp.second.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      lastError = e.toString();
      lastStatus = 'Erro na coleta';
    } finally {
      collecting = false;
      notifyListeners();
    }
  }

  int get activeHosts => hosts.where((h) => h.isReachable).length;
  int get configuredHosts => settings.salaIps.length;

  double get roomAvgLoss {
    final online = hosts.where((h) => h.isReachable).toList();
    if (online.isEmpty) {
      return hosts.isEmpty ? 0 : 100;
    }
    return online.map((h) => h.lossPct).reduce((a, b) => a + b) / online.length;
  }

  double get roomAvgLatency {
    final online = hosts.where((h) => h.isReachable).toList();
    if (online.isEmpty) return 0;
    return online.map((h) => h.latencyMs).reduce((a, b) => a + b) /
        online.length;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
