// REPRESENTS SERVER CONNECTION INFORMATION AND AUTHENTICATION STATE
class ServerInfo {
  final String serverUrl;
  final String username;
  final String password;
  final String? expDate;
  final int? activeCons;
  final int? maxConnections;
  final bool isAuthenticated;

  const ServerInfo({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.expDate,
    this.activeCons,
    this.maxConnections,
    this.isAuthenticated = false,
  });

  // AN EMPTY, UNAUTHENTICATED SERVER INFO INSTANCE
  const ServerInfo.empty()
    : serverUrl = '',
      username = '',
      password = '',
      expDate = null,
      activeCons = null,
      maxConnections = null,
      isAuthenticated = false;

  // WHETHER THE ACCOUNT HAS EXPIRED
  bool get isExpired {
    if (expDate == null || expDate!.isEmpty) return false;
    final epoch = int.tryParse(expDate!);
    if (epoch != null) {
      final exp = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      return DateTime.now().isAfter(exp);
    }
    final parsed = DateTime.tryParse(expDate!);
    if (parsed != null) return DateTime.now().isAfter(parsed);
    return false;
  }

  // RETURNS THE EXPIRATION DATE AS A [DATETIME], OR NULL IF NOT PARSEABLE
  DateTime? get expirationDate {
    if (expDate == null || expDate!.isEmpty) return null;
    final epoch = int.tryParse(expDate!);
    if (epoch != null) {
      return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    }
    return DateTime.tryParse(expDate!);
  }

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    // XTREAM API RETURNS NESTED 'USER_INFO' AND 'SERVER_INFO' OBJECTS
    final userInfo = json['user_info'] as Map<String, dynamic>? ?? json;
    final serverInfo = json['server_info'] as Map<String, dynamic>? ?? {};

    final serverUrl = (json['serverUrl'] ?? json['server_url'] ?? '')
        .toString();
    String resolvedUrl = serverUrl;
    if (resolvedUrl.isEmpty && serverInfo.isNotEmpty) {
      final protocol = serverInfo['https_port'] != null ? 'https' : 'http';
      final host = serverInfo['url'] ?? serverInfo['server_url'] ?? '';
      final port = serverInfo['port'] ?? serverInfo['https_port'] ?? '';
      if (host.toString().isNotEmpty) {
        resolvedUrl = '$protocol://$host:$port';
      }
    }

    return ServerInfo(
      serverUrl: resolvedUrl,
      username: (userInfo['username'] ?? json['username'] ?? '').toString(),
      password: (userInfo['password'] ?? json['password'] ?? '').toString(),
      expDate: (userInfo['exp_date'] ?? json['expDate'])?.toString(),
      activeCons: _tryParseInt(userInfo['active_cons'] ?? json['activeCons']),
      maxConnections: _tryParseInt(
        userInfo['max_connections'] ?? json['maxConnections'],
      ),
      isAuthenticated:
          (userInfo['auth'] ?? json['isAuthenticated'] ?? 0) == 1 ||
          (userInfo['auth'] ?? json['isAuthenticated'] ?? false) == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      if (expDate != null) 'expDate': expDate,
      if (activeCons != null) 'activeCons': activeCons,
      if (maxConnections != null) 'maxConnections': maxConnections,
      'isAuthenticated': isAuthenticated,
    };
  }

  ServerInfo copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? expDate,
    int? activeCons,
    int? maxConnections,
    bool? isAuthenticated,
  }) {
    return ServerInfo(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      expDate: expDate ?? this.expDate,
      activeCons: activeCons ?? this.activeCons,
      maxConnections: maxConnections ?? this.maxConnections,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  String toString() {
    return 'ServerInfo(serverUrl: $serverUrl, username: $username, isAuthenticated: $isAuthenticated, isExpired: $isExpired)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerInfo &&
        other.serverUrl == serverUrl &&
        other.username == username;
  }

  @override
  int get hashCode => serverUrl.hashCode ^ username.hashCode;

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}
