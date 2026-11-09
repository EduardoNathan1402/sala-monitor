import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_settings.dart';
import '../services/ip_list_parser.dart';
import '../services/monitor_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final MonitorController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _sala;
  late final TextEditingController _interval;
  late final TextEditingController _ping;
  late final TextEditingController _export;
  late final TextEditingController _pushUrl;
  late final TextEditingController _salaIps;
  late bool _autoExport;
  late bool _monitorSala;
  late bool _push;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _sala = TextEditingController(text: s.sala);
    _interval = TextEditingController(text: '${s.intervalSeconds}');
    _ping = TextEditingController(text: s.pingTarget);
    _export = TextEditingController(text: s.exportPath);
    _pushUrl = TextEditingController(text: s.powerBiPushUrl);
    _salaIps = TextEditingController(text: s.salaIpsText);
    _autoExport = s.autoExport;
    _monitorSala = s.monitorSalaIps;
    _push = s.pushToPowerBi;
  }

  @override
  void dispose() {
    _sala.dispose();
    _interval.dispose();
    _ping.dispose();
    _export.dispose();
    _pushUrl.dispose();
    _salaIps.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = AppSettings(
      sala: _sala.text.trim().isEmpty ? 'Sala 01' : _sala.text.trim(),
      intervalSeconds: int.tryParse(_interval.text.trim()) ?? 30,
      pingTarget: _ping.text.trim(),
      exportPath: _export.text.trim(),
      powerBiPushUrl: _pushUrl.text.trim(),
      salaIpsText: _salaIps.text,
      autoExport: _autoExport,
      monitorSalaIps: _monitorSala,
      pushToPowerBi: _push,
    );
    await widget.controller.updateSettings(next);
    if (mounted) {
      final count = IpListParser.parse(_salaIps.text).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvo · $count IP(s) da sala configurados')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedCount = IpListParser.parse(_salaIps.text).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Salvar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _sala,
            decoration: const InputDecoration(
              labelText: 'Nome da sala',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _salaIps,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'IPs das máquinas desta sala',
              alignLabelWithHint: true,
              helperText:
                  'Um por linha. Aceita faixa: 192.168.15.10-40 · Detectados: $parsedCount',
              border: const OutlineInputBorder(),
              hintText: '192.168.15.10\n192.168.15.11\n192.168.15.12-30',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _interval,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Intervalo de coleta (segundos)',
              helperText: 'Mínimo 10 · recomendado 15–60',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ping,
            decoration: const InputDecoration(
              labelText: 'Alvo do ping local (opcional)',
              helperText:
                  'Só para métricas deste PC. Vazio = gateway. As máquinas da sala usam a lista de IPs acima.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _export,
            decoration: const InputDecoration(
              labelText: 'Pasta de exportação (opcional)',
              helperText:
                  'Ex.: \\\\servidor\\compartilhamento\\SalaMonitor ou C:\\Dados\\PBI',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pushUrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'URL Push do Power BI Streaming Dataset',
              helperText:
                  'Power BI Service → Streaming dataset → API URL (Push URL)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Exportar CSV/JSON automaticamente'),
            value: _autoExport,
            onChanged: (v) => setState(() => _autoExport = v),
          ),
          SwitchListTile(
            title: const Text('Analisar somente IPs da sala'),
            subtitle: const Text(
              'Ignora VPN/outros dispositivos. Faz ping só nos IPs cadastrados.',
            ),
            value: _monitorSala,
            onChanged: (v) => setState(() => _monitorSala = v),
          ),
          SwitchListTile(
            title: const Text('Enviar para Power BI (Push)'),
            subtitle: const Text('Requer URL do Streaming Dataset'),
            value: _push,
            onChanged: (v) => setState(() => _push = v),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como cadastrar os IPs',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Liste só os IPs dos PCs desta sala\n'
                    '2. Exemplo de faixa: 192.168.15.10-40\n'
                    '3. Salve e clique em Iniciar\n'
                    '4. O app faz ping nesses IPs e mostra online/offline + MAC + latência\n'
                    '5. Dispositivos VPN (ex.: 26.x.x.x) e gateway não entram na lista',
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
