class IpListParser {
  /// Aceita linhas, vírgulas ou espaços.
  /// Formatos:
  /// - 192.168.15.10
  /// - 192.168.15.10-40
  /// - 192.168.15.10-192.168.15.40
  static List<String> parse(String raw) {
    final tokens = raw
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('#'))
        .toList();

    final ips = <String>{};
    for (final token in tokens) {
      if (token.contains('-')) {
        ips.addAll(_expandRange(token));
      } else if (_isIpv4(token)) {
        ips.add(token);
      }
    }

    final list = ips.toList()
      ..sort((a, b) => _ipKey(a).compareTo(_ipKey(b)));
    return list;
  }

  static List<String> _expandRange(String token) {
    final parts = token.split('-');
    if (parts.length != 2) return const [];

    final left = parts[0].trim();
    final right = parts[1].trim();

    if (!_isIpv4(left)) return const [];

    // 192.168.15.10-40
    if (RegExp(r'^\d{1,3}$').hasMatch(right)) {
      final octets = left.split('.').map(int.parse).toList();
      final start = octets[3];
      final end = int.parse(right);
      if (end < start || end > 255) return const [];
      return [
        for (var i = start; i <= end; i++)
          '${octets[0]}.${octets[1]}.${octets[2]}.$i',
      ];
    }

    // 192.168.15.10-192.168.15.40
    if (!_isIpv4(right)) return const [];
    final a = left.split('.').map(int.parse).toList();
    final b = right.split('.').map(int.parse).toList();
    if (a[0] != b[0] || a[1] != b[1] || a[2] != b[2]) return const [];
    if (b[3] < a[3]) return const [];
    return [
      for (var i = a[3]; i <= b[3]; i++) '${a[0]}.${a[1]}.${a[2]}.$i',
    ];
  }

  static bool _isIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static int _ipKey(String ip) {
    final parts = ip.split('.');
    var key = 0;
    for (final p in parts) {
      key = (key << 8) + (int.tryParse(p) ?? 0);
    }
    return key;
  }
}
