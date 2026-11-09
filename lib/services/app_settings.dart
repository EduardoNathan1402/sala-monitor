import 'package:shared_preferences/shared_preferences.dart';

import 'ip_list_parser.dart';

class AppSettings {
  AppSettings({
    this.sala = 'Sala 01',
    this.intervalSeconds = 30,
    this.pingTarget = '',
    this.exportPath = '',
    this.powerBiPushUrl = '',
    this.salaIpsText = '',
    this.autoExport = true,
    this.monitorSalaIps = true,
    this.pushToPowerBi = false,
  });

  String sala;
  int intervalSeconds;
  String pingTarget;
  String exportPath;
  String powerBiPushUrl;

  /// Lista de IPs da sala (um por linha, ou faixas 192.168.15.10-40).
  String salaIpsText;
  bool autoExport;
  bool monitorSalaIps;
  bool pushToPowerBi;

  List<String> get salaIps => IpListParser.parse(salaIpsText);

  static const _kSala = 'sala';
  static const _kInterval = 'interval_seconds';
  static const _kPing = 'ping_target';
  static const _kExport = 'export_path';
  static const _kPushUrl = 'powerbi_push_url';
  static const _kSalaIps = 'sala_ips_text';
  static const _kAutoExport = 'auto_export';
  static const _kMonitorSala = 'monitor_sala_ips';
  static const _kPush = 'push_to_powerbi';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      sala: prefs.getString(_kSala) ?? 'Sala 01',
      intervalSeconds: prefs.getInt(_kInterval) ?? 30,
      pingTarget: prefs.getString(_kPing) ?? '',
      exportPath: prefs.getString(_kExport) ?? '',
      powerBiPushUrl: prefs.getString(_kPushUrl) ?? '',
      salaIpsText: prefs.getString(_kSalaIps) ?? '',
      autoExport: prefs.getBool(_kAutoExport) ?? true,
      monitorSalaIps: prefs.getBool(_kMonitorSala) ?? true,
      pushToPowerBi: prefs.getBool(_kPush) ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSala, sala);
    await prefs.setInt(_kInterval, intervalSeconds.clamp(10, 600));
    await prefs.setString(_kPing, pingTarget);
    await prefs.setString(_kExport, exportPath);
    await prefs.setString(_kPushUrl, powerBiPushUrl);
    await prefs.setString(_kSalaIps, salaIpsText);
    await prefs.setBool(_kAutoExport, autoExport);
    await prefs.setBool(_kMonitorSala, monitorSalaIps);
    await prefs.setBool(_kPush, pushToPowerBi);
  }
}
