import 'package:flutter_test/flutter_test.dart';
import 'package:sala_monitor/models/machine_metrics.dart';
import 'package:sala_monitor/services/ip_list_parser.dart';

void main() {
  test('MachineMetrics gera linha CSV com cabeçalhos coerentes', () {
    final m = MachineMetrics(
      timestamp: DateTime.utc(2026, 7, 22, 12, 0, 0),
      hostname: 'PC01',
      username: 'aluno',
      ip: '192.168.1.10',
      mac: 'AA:BB:CC:DD:EE:FF',
      adapterName: 'Ethernet',
      online: true,
      bytesReceived: 1000,
      bytesSent: 500,
      gbReceivedDelta: 0.001,
      gbSentDelta: 0.002,
      pingTarget: '192.168.1.1',
      pingLossPct: 0,
      pingLatencyMs: 12,
      cpuPct: 20,
      ramPct: 40,
      diskPct: 55,
      uptimeHours: 3.5,
      linkSpeedMbps: 1000,
      sala: 'Sala 01',
    );

    final row = m.toCsvRow();
    expect(MachineMetrics.csvHeaders.length, row.split(',').length);
    expect(row.contains('PC01'), isTrue);
    expect(row.contains('AA:BB:CC:DD:EE:FF'), isTrue);
  });

  test('IpListParser expande IPs e faixas', () {
    final ips = IpListParser.parse('''
# comentario
192.168.15.10
192.168.15.12-14
192.168.15.20-192.168.15.21
''');
    expect(
      ips,
      [
        '192.168.15.10',
        '192.168.15.12',
        '192.168.15.13',
        '192.168.15.14',
        '192.168.15.20',
        '192.168.15.21',
      ],
    );
  });
}
