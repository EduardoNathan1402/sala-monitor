import 'dart:convert';
import 'dart:io';

import '../models/machine_metrics.dart';

class MetricsCollector {
  int? _lastBytesReceived;
  int? _lastBytesSent;

  Future<MachineMetrics> collect({
    required String sala,
    String? pingTarget,
  }) async {
    final raw = await _runPowerShell(_collectorScript(pingTarget));
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final bytesReceived = _asInt(data['bytesReceived']);
    final bytesSent = _asInt(data['bytesSent']);

    var gbIn = 0.0;
    var gbOut = 0.0;
    if (_lastBytesReceived != null && _lastBytesSent != null) {
      final dIn = (bytesReceived - _lastBytesReceived!).clamp(0, 1 << 62);
      final dOut = (bytesSent - _lastBytesSent!).clamp(0, 1 << 62);
      gbIn = dIn / (1024 * 1024 * 1024);
      gbOut = dOut / (1024 * 1024 * 1024);
    }
    _lastBytesReceived = bytesReceived;
    _lastBytesSent = bytesSent;

    return MachineMetrics(
      timestamp: DateTime.now(),
      hostname: data['hostname']?.toString() ?? Platform.localHostname,
      username: data['username']?.toString() ?? '',
      ip: data['ip']?.toString() ?? '',
      mac: data['mac']?.toString() ?? '',
      adapterName: data['adapterName']?.toString() ?? '',
      online: true,
      bytesReceived: bytesReceived,
      bytesSent: bytesSent,
      gbReceivedDelta: gbIn,
      gbSentDelta: gbOut,
      pingTarget: data['pingTarget']?.toString() ?? '',
      pingLossPct: _asDouble(data['pingLossPct']),
      pingLatencyMs: _asDouble(data['pingLatencyMs']),
      cpuPct: _asDouble(data['cpuPct']),
      ramPct: _asDouble(data['ramPct']),
      diskPct: _asDouble(data['diskPct']),
      uptimeHours: _asDouble(data['uptimeHours']),
      linkSpeedMbps: _asDouble(data['linkSpeedMbps']),
      sala: sala,
    );
  }

  Future<List<NetworkHost>> scanLanHosts() async {
    final raw = await _runPowerShell(_lanScanScript);
    final decoded = jsonDecode(raw);
    final list = decoded is List
        ? decoded
        : decoded is Map
            ? <dynamic>[decoded]
            : <dynamic>[];
    final now = DateTime.now();
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return NetworkHost(
        ip: m['ip']?.toString() ?? '',
        mac: m['mac']?.toString() ?? '',
        hostname: m['hostname']?.toString() ?? '',
        state: m['state']?.toString() ?? '',
        lastSeen: now,
        latencyMs: _asDouble(m['latencyMs']),
        lossPct: _asDouble(m['lossPct']),
      );
    }).where((h) => h.ip.isNotEmpty && !h.ip.startsWith('169.254')).toList()
      ..sort((a, b) => _ipSortKey(a.ip).compareTo(_ipSortKey(b.ip)));
  }

  /// Analisa somente os IPs cadastrados da sala (ping + MAC/hostname).
  Future<List<NetworkHost>> probeSalaHosts(List<String> ips) async {
    if (ips.isEmpty) return [];

    final unique = ips.toSet().toList()
      ..sort((a, b) => _ipSortKey(a).compareTo(_ipSortKey(b)));

    final raw = await _runPowerShell(_probeScript(unique));
    final decoded = jsonDecode(raw);
    final list = decoded is List
        ? decoded
        : decoded is Map
            ? <dynamic>[decoded]
            : <dynamic>[];
    final now = DateTime.now();

    final byIp = <String, NetworkHost>{};
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final ip = m['ip']?.toString() ?? '';
      if (ip.isEmpty) continue;
      byIp[ip] = NetworkHost(
        ip: ip,
        mac: m['mac']?.toString() ?? '',
        hostname: m['hostname']?.toString() ?? '',
        state: m['state']?.toString() ?? 'Offline',
        lastSeen: now,
        latencyMs: _asDouble(m['latencyMs']),
        lossPct: _asDouble(m['lossPct']),
      );
    }

    return [
      for (final ip in unique)
        byIp[ip] ??
            NetworkHost(
              ip: ip,
              mac: '',
              hostname: '',
              state: 'Offline',
              lastSeen: now,
              latencyMs: 0,
              lossPct: 100,
            ),
    ];
  }

  Future<String> _runPowerShell(String script) async {
    final temp = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'sala_monitor_${DateTime.now().microsecondsSinceEpoch}.ps1',
    );

    try {
      // UTF-16 LE com BOM — formato nativo do PowerShell no Windows
      final bom = [0xFF, 0xFE];
      final body = <int>[];
      for (final unit in script.codeUnits) {
        body.add(unit & 0xFF);
        body.add((unit >> 8) & 0xFF);
      }
      await temp.writeAsBytes([...bom, ...body]);

      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          temp.path,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (result.exitCode != 0) {
        final err = result.stderr.toString().trim();
        throw Exception(
          'Falha ao coletar métricas (código ${result.exitCode}): '
          '${err.isEmpty ? result.stdout : err}',
        );
      }

      final out = result.stdout.toString().trim();
      if (out.isEmpty) {
        throw Exception('Coleta retornou vazio.');
      }
      return out;
    } finally {
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  static int _ipSortKey(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    var key = 0;
    for (final p in parts) {
      key = (key << 8) + (int.tryParse(p) ?? 0);
    }
    return key;
  }

  static String _collectorScript(String? pingTarget) {
    final customTarget = pingTarget == null || pingTarget.trim().isEmpty
        ? ''
        : pingTarget.trim().replaceAll("'", "''");

    return '''
\$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

\$hostname = \$env:COMPUTERNAME
\$username = \$env:USERNAME

\$adapter = Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' -and \$_.HardwareInterface -eq \$true } |
  Sort-Object -Property LinkSpeed -Descending |
  Select-Object -First 1

if (-not \$adapter) {
  \$adapter = Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' } | Select-Object -First 1
}

\$ip = ''
\$mac = ''
\$adapterName = ''
\$linkSpeedMbps = 0
\$bytesReceived = 0
\$bytesSent = 0
\$gateway = ''

if (\$adapter) {
  \$adapterName = \$adapter.Name
  \$mac = (\$adapter.MacAddress -replace '-', ':')
  try {
    if (\$adapter.ReceiveLinkSpeed -and \$adapter.ReceiveLinkSpeed -gt 0) {
      \$linkSpeedMbps = [math]::Round([double]\$adapter.ReceiveLinkSpeed / 1000000.0, 0)
    }
  } catch { \$linkSpeedMbps = 0 }

  \$ipCfg = Get-NetIPAddress -InterfaceIndex \$adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { \$_.IPAddress -notlike '169.254*' } |
    Select-Object -First 1
  if (\$ipCfg) { \$ip = \$ipCfg.IPAddress }

  \$route = Get-NetRoute -InterfaceIndex \$adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric |
    Select-Object -First 1
  if (\$route) { \$gateway = \$route.NextHop }

  \$stats = Get-NetAdapterStatistics -Name \$adapter.Name -ErrorAction SilentlyContinue
  if (\$stats) {
    \$bytesReceived = [int64]\$stats.ReceivedBytes
    \$bytesSent = [int64]\$stats.SentBytes
  }
}

\$pingTarget = '$customTarget'
if ([string]::IsNullOrWhiteSpace(\$pingTarget)) {
  if (-not [string]::IsNullOrWhiteSpace(\$gateway)) { \$pingTarget = \$gateway } else { \$pingTarget = '8.8.8.8' }
}

\$pingLossPct = 100
\$pingLatencyMs = 0
try {
  \$ping = Test-Connection -ComputerName \$pingTarget -Count 4 -ErrorAction Stop
  \$latencies = @(\$ping | ForEach-Object { \$_.Latency })
  if (\$latencies.Count -gt 0) {
    \$pingLatencyMs = [math]::Round((\$latencies | Measure-Object -Average).Average, 2)
    \$pingLossPct = [math]::Round(((4 - \$latencies.Count) / 4.0) * 100, 2)
  }
} catch {
  \$pingLossPct = 100
  \$pingLatencyMs = 0
}

\$cpuPct = 0
try {
  \$cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
  \$cpuPct = [math]::Round([double]\$cpu.Average, 2)
} catch {}

\$ramPct = 0
try {
  \$os = Get-CimInstance Win32_OperatingSystem
  \$total = [double]\$os.TotalVisibleMemorySize
  \$free = [double]\$os.FreePhysicalMemory
  if (\$total -gt 0) { \$ramPct = [math]::Round(((\$total - \$free) / \$total) * 100, 2) }
} catch {}

\$diskPct = 0
try {
  \$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
  if (\$disk -and \$disk.Size -gt 0) {
    \$diskPct = [math]::Round(((\$disk.Size - \$disk.FreeSpace) / \$disk.Size) * 100, 2)
  }
} catch {}

\$uptimeHours = 0
try {
  \$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  \$uptimeHours = [math]::Round(((Get-Date) - \$boot).TotalHours, 2)
} catch {}

\$obj = [ordered]@{
  hostname = \$hostname
  username = \$username
  ip = \$ip
  mac = \$mac
  adapterName = \$adapterName
  linkSpeedMbps = \$linkSpeedMbps
  bytesReceived = \$bytesReceived
  bytesSent = \$bytesSent
  pingTarget = \$pingTarget
  pingLossPct = \$pingLossPct
  pingLatencyMs = \$pingLatencyMs
  cpuPct = \$cpuPct
  ramPct = \$ramPct
  diskPct = \$diskPct
  uptimeHours = \$uptimeHours
}

\$obj | ConvertTo-Json -Compress
''';
  }

  static const String _lanScanScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$neighbors = Get-NetNeighbor -AddressFamily IPv4 |
  Where-Object {
    $_.State -in @('Reachable','Permanent','Stale','Delay','Probe') -and
    $_.IPAddress -notmatch '^(127\.|224\.|239\.|255\.|0\.)' -and
    $_.LinkLayerAddress -and
    $_.LinkLayerAddress -ne '00-00-00-00-00-00'
  }

$result = @()
foreach ($n in $neighbors) {
  $hostName = ''
  try {
    $entry = [System.Net.Dns]::GetHostEntry($n.IPAddress)
    if ($entry -and $entry.HostName) { $hostName = $entry.HostName }
  } catch {}

  $result += [ordered]@{
    ip = $n.IPAddress
    mac = ($n.LinkLayerAddress -replace '-', ':')
    hostname = $hostName
    state = [string]$n.State
  }
}

# Também inclui o próprio host
$selfIp = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127*' -and $_.IPAddress -notlike '169.254*' } |
  Select-Object -First 1).IPAddress
$selfMac = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).MacAddress
if ($selfIp) {
  $exists = $result | Where-Object { $_.ip -eq $selfIp }
  if (-not $exists) {
    $result += [ordered]@{
      ip = $selfIp
      mac = (($selfMac) -replace '-', ':')
      hostname = $env:COMPUTERNAME
      state = 'Reachable'
    }
  }
}

if ($result.Count -eq 0) {
  Write-Output '[]'
} else {
  (@($result) | Sort-Object { $_.ip }) | ConvertTo-Json -Compress -Depth 4
}
''';

  static String _probeScript(List<String> ips) {
    final listLiteral = ips
        .map((ip) => "'${ip.replaceAll("'", "")}'")
        .join(',');

    return '''
\$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

\$ips = @($listLiteral)
\$result = @()

foreach (\$ip in \$ips) {
  \$pings = @(Test-Connection -ComputerName \$ip -Count 2 -ErrorAction SilentlyContinue)
  \$count = \$pings.Count
  \$lossPct = if (\$count -le 0) { 100 } else { [math]::Round(((2 - \$count) / 2.0) * 100, 2) }

  \$latencyMs = 0
  if (\$count -gt 0) {
    \$times = @()
    foreach (\$p in \$pings) {
      if (\$null -ne \$p.ResponseTime) { \$times += [double]\$p.ResponseTime }
      elseif (\$null -ne \$p.Latency) { \$times += [double]\$p.Latency }
    }
    if (\$times.Count -gt 0) {
      \$latencyMs = [math]::Round((\$times | Measure-Object -Average).Average, 2)
    }
  }

  \$mac = ''
  \$neighbor = Get-NetNeighbor -AddressFamily IPv4 -IPAddress \$ip -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (\$neighbor -and \$neighbor.LinkLayerAddress -and \$neighbor.LinkLayerAddress -ne '00-00-00-00-00-00') {
    \$mac = (\$neighbor.LinkLayerAddress -replace '-', ':')
  }

  \$hostName = ''
  try {
    \$entry = [System.Net.Dns]::GetHostEntry(\$ip)
    if (\$entry -and \$entry.HostName) { \$hostName = \$entry.HostName }
  } catch {}

  \$state = if (\$count -gt 0) { 'Reachable' } else { 'Offline' }

  \$result += [ordered]@{
    ip = \$ip
    mac = \$mac
    hostname = \$hostName
    state = \$state
    latencyMs = \$latencyMs
    lossPct = \$lossPct
  }
}

if (\$result.Count -eq 0) {
  Write-Output '[]'
} else {
  @(\$result) | ConvertTo-Json -Compress -Depth 4
}
''';
  }
}
