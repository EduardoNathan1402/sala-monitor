class MachineMetrics {
  MachineMetrics({
    required this.timestamp,
    required this.hostname,
    required this.username,
    required this.ip,
    required this.mac,
    required this.adapterName,
    required this.online,
    required this.bytesReceived,
    required this.bytesSent,
    required this.gbReceivedDelta,
    required this.gbSentDelta,
    required this.pingTarget,
    required this.pingLossPct,
    required this.pingLatencyMs,
    required this.cpuPct,
    required this.ramPct,
    required this.diskPct,
    required this.uptimeHours,
    required this.linkSpeedMbps,
    required this.sala,
  });

  final DateTime timestamp;
  final String hostname;
  final String username;
  final String ip;
  final String mac;
  final String adapterName;
  final bool online;
  final int bytesReceived;
  final int bytesSent;
  final double gbReceivedDelta;
  final double gbSentDelta;
  final String pingTarget;
  final double pingLossPct;
  final double pingLatencyMs;
  final double cpuPct;
  final double ramPct;
  final double diskPct;
  final double uptimeHours;
  final double linkSpeedMbps;
  final String sala;

  double get gbTotalDelta => gbReceivedDelta + gbSentDelta;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'hostname': hostname,
        'username': username,
        'ip': ip,
        'mac': mac,
        'adapter_name': adapterName,
        'online': online,
        'bytes_received': bytesReceived,
        'bytes_sent': bytesSent,
        'gb_received_delta': gbReceivedDelta,
        'gb_sent_delta': gbSentDelta,
        'gb_total_delta': gbTotalDelta,
        'ping_target': pingTarget,
        'ping_loss_pct': pingLossPct,
        'ping_latency_ms': pingLatencyMs,
        'cpu_pct': cpuPct,
        'ram_pct': ramPct,
        'disk_pct': diskPct,
        'uptime_hours': uptimeHours,
        'link_speed_mbps': linkSpeedMbps,
        'sala': sala,
      };

  Map<String, dynamic> toPowerBiRow() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'hostname': hostname,
        'username': username,
        'ip': ip,
        'mac': mac,
        'adapter_name': adapterName,
        'online': online ? 1 : 0,
        'bytes_received': bytesReceived,
        'bytes_sent': bytesSent,
        'gb_received_delta': gbReceivedDelta,
        'gb_sent_delta': gbSentDelta,
        'gb_total_delta': gbTotalDelta,
        'ping_target': pingTarget,
        'ping_loss_pct': pingLossPct,
        'ping_latency_ms': pingLatencyMs,
        'cpu_pct': cpuPct,
        'ram_pct': ramPct,
        'disk_pct': diskPct,
        'uptime_hours': uptimeHours,
        'link_speed_mbps': linkSpeedMbps,
        'sala': sala,
      };

  static List<String> get csvHeaders => [
        'timestamp',
        'hostname',
        'username',
        'ip',
        'mac',
        'adapter_name',
        'online',
        'bytes_received',
        'bytes_sent',
        'gb_received_delta',
        'gb_sent_delta',
        'gb_total_delta',
        'ping_target',
        'ping_loss_pct',
        'ping_latency_ms',
        'cpu_pct',
        'ram_pct',
        'disk_pct',
        'uptime_hours',
        'link_speed_mbps',
        'sala',
      ];

  String toCsvRow() {
    final values = [
      timestamp.toIso8601String(),
      hostname,
      username,
      ip,
      mac,
      adapterName,
      online ? '1' : '0',
      bytesReceived.toString(),
      bytesSent.toString(),
      gbReceivedDelta.toStringAsFixed(6),
      gbSentDelta.toStringAsFixed(6),
      gbTotalDelta.toStringAsFixed(6),
      pingTarget,
      pingLossPct.toStringAsFixed(2),
      pingLatencyMs.toStringAsFixed(2),
      cpuPct.toStringAsFixed(2),
      ramPct.toStringAsFixed(2),
      diskPct.toStringAsFixed(2),
      uptimeHours.toStringAsFixed(2),
      linkSpeedMbps.toStringAsFixed(0),
      sala,
    ];
    return values.map(_escapeCsv).join(',');
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class NetworkHost {
  NetworkHost({
    required this.ip,
    required this.mac,
    required this.hostname,
    required this.state,
    required this.lastSeen,
    this.latencyMs = 0,
    this.lossPct = 100,
  });

  final String ip;
  final String mac;
  final String hostname;
  final String state;
  final DateTime lastSeen;
  final double latencyMs;
  final double lossPct;

  bool get isReachable =>
      state.toLowerCase() == 'reachable' || state.toLowerCase() == 'online';

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'mac': mac,
        'hostname': hostname,
        'state': state,
        'last_seen': lastSeen.toIso8601String(),
        'online': isReachable,
        'latency_ms': latencyMs,
        'loss_pct': lossPct,
      };

  static List<String> get csvHeaders => [
        'ip',
        'mac',
        'hostname',
        'state',
        'last_seen',
        'online',
        'latency_ms',
        'loss_pct',
      ];

  String toCsvRow() {
    final values = [
      ip,
      mac,
      hostname,
      state,
      lastSeen.toIso8601String(),
      isReachable ? '1' : '0',
      latencyMs.toStringAsFixed(2),
      lossPct.toStringAsFixed(2),
    ];
    return values.map((v) {
      if (v.contains(',') || v.contains('"')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }).join(',');
  }
}
