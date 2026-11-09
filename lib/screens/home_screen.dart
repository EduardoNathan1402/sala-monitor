import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/machine_metrics.dart';
import '../services/monitor_controller.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final m = controller.latest;
        final lossHistory = controller.roomLossHistory.isNotEmpty
            ? controller.roomLossHistory
            : controller.history.map((e) => e.pingLossPct).toList(growable: false);
        final latencyHistory = controller.roomLatencyHistory.isNotEmpty
            ? controller.roomLatencyHistory
            : controller.history
                .map((e) => e.pingLatencyMs)
                .toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sala Monitor'),
            actions: [
              IconButton(
                tooltip: 'Atualizar agora',
                onPressed: controller.collecting ? null : controller.collectOnce,
                icon: controller.collecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Configurações',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(controller: controller),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderBar(controller: controller),
                const SizedBox(height: 16),
                if (controller.lastError != null)
                  Card(
                    color: const Color(0xFF3B1515),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        controller.lastError!,
                        style: const TextStyle(color: Color(0xFFFFB4B4)),
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _StatCard(
                                  label: 'Máquinas ativas',
                                  value: '${controller.activeHosts}',
                                  subtitle: controller.configuredHosts == 0
                                      ? 'Cadastre os IPs da sala'
                                      : '${controller.activeHosts} online de ${controller.configuredHosts} IPs',
                                  accent: const Color(0xFF2BB673),
                                ),
                                _StatCard(
                                  label: 'GB nesta sessão',
                                  value: controller.totalGbSession
                                      .toStringAsFixed(3),
                                  subtitle: m == null
                                      ? '—'
                                      : '+${m.gbTotalDelta.toStringAsFixed(4)} GB no intervalo',
                                  accent: const Color(0xFF4EA1FF),
                                ),
                                _StatCard(
                                  label: 'Perda média (sala)',
                                  value:
                                      '${controller.roomAvgLoss.toStringAsFixed(1)}%',
                                  subtitle: controller.configuredHosts == 0
                                      ? 'Sem IPs configurados'
                                      : 'média das máquinas online',
                                  accent: controller.roomAvgLoss > 5
                                      ? const Color(0xFFFF6B6B)
                                      : const Color(0xFF2BB673),
                                ),
                                _StatCard(
                                  label: 'Latência média',
                                  value:
                                      '${controller.roomAvgLatency.toStringAsFixed(0)} ms',
                                  subtitle: m == null
                                      ? ''
                                      : 'CPU ${m.cpuPct.toStringAsFixed(0)}% · RAM ${m.ramPct.toStringAsFixed(0)}%',
                                  accent: const Color(0xFFE6B84F),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ChartCard(
                                      title: 'Perda média da sala (%)',
                                      values: lossHistory,
                                      color: const Color(0xFFFF6B6B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ChartCard(
                                      title: 'Latência média da sala (ms)',
                                      values: latencyHistory,
                                      color: const Color(0xFF4EA1FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (m != null) _LocalMachineCard(metrics: m),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _HostsTable(hosts: controller.hosts),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.exportPathShown == null
                      ? 'CSV/JSON ainda não gerados. Inicie o monitoramento.'
                      : 'Exportando para: ${controller.exportPathShown}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.settings.sala,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                controller.lastStatus ?? 'Pronto',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: controller.running
              ? controller.stop
              : () => controller.start(),
          icon: Icon(controller.running ? Icons.stop : Icons.play_arrow),
          label: Text(controller.running ? 'Parar' : 'Iniciar'),
          style: FilledButton.styleFrom(
            backgroundColor: controller.running
                ? const Color(0xFFB33A3A)
                : const Color(0xFF1F8A5B),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2330),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2330),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: spots.length < 2
                ? const Center(
                    child: Text(
                      'Coletando histórico…',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LocalMachineCard extends StatelessWidget {
  const _LocalMachineCard({required this.metrics});

  final MachineMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm:ss');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2330),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _kv('Host', metrics.hostname),
          _kv('Usuário', metrics.username),
          _kv('IP', metrics.ip),
          _kv('MAC', metrics.mac),
          _kv('Adaptador', metrics.adapterName),
          _kv('Link', '${metrics.linkSpeedMbps.toStringAsFixed(0)} Mbps'),
          _kv('Disco C:', '${metrics.diskPct.toStringAsFixed(0)}%'),
          _kv('Uptime', '${metrics.uptimeHours.toStringAsFixed(1)} h'),
          _kv('Coleta', fmt.format(metrics.timestamp)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HostsTable extends StatelessWidget {
  const _HostsTable({required this.hosts});

  final List<NetworkHost> hosts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2330),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Máquinas da sala (só IPs cadastrados)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: hosts.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma máquina listada.\n'
                      'Cadastre os IPs da sala em Configurações\n'
                      'e clique em Iniciar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    itemCount: hosts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final h = hosts[index];
                      final online = h.isReachable;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          online ? Icons.lan : Icons.lan_outlined,
                          color: online
                              ? const Color(0xFF2BB673)
                              : Colors.white38,
                        ),
                        title: Text(
                          h.hostname.isEmpty ? h.ip : h.hostname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          h.mac.isEmpty
                              ? h.ip
                              : '${h.ip}  ·  ${h.mac}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              online ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: online
                                    ? const Color(0xFF2BB673)
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              online
                                  ? '${h.latencyMs.toStringAsFixed(0)} ms · ${h.lossPct.toStringAsFixed(0)}%'
                                  : 'sem resposta',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
