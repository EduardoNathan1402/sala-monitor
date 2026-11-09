# Arquitetura — Sala Monitor

Visão técnica curta do fluxo de dados no desktop Windows.

```text
┌────────────────────────────────────────────────────────────┐
│                     Flutter UI (Material 3)                │
│  Home (cards + charts + host list)  ·  Settings            │
└────────────────────────────┬───────────────────────────────┘
                             │ ListenableBuilder
┌────────────────────────────▼───────────────────────────────┐
│                   MonitorController                        │
│  timer · histórico · salas · start/stop · status           │
└──────┬───────────────────────────────┬─────────────────────┘
       │                               │
       ▼                               ▼
 MetricsCollector                 ExportService
  · Test-Connection (ping)         · metricas_*.csv
  · Get-CimInstance (local)        · hosts_rede.csv
  · probe IPs da sala              · ultimo_snapshot.json
  · enrich WMI remoto (opcional)
```

## Princípios

1. **Lista fechada de IPs** — o painel só mostra o que você cadastrou (não varre ARP/VPN).
2. **Coleta periódica** — intervalo configurável (mín. 10 s).
3. **Exportação local** — CSV/JSON para pasta escolhida ou `C:\SalaMonitor\dados`.
4. **Desktop-first** — pensado para TV / mesa do técnico, não para mobile.

## Pastas relevantes

| Caminho | Papel |
|---------|--------|
| `lib/screens/` | UI |
| `lib/services/` | coleta, export, settings |
| `lib/models/` | estruturas de métricas/hosts |
| `windows/` | runner nativo |
