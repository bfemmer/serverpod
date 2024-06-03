import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

/// Parser for the Serverpod configuration file.
class ServerpodConfig {
  /// The servers run mode.
  final String runMode;

  /// Id of the current server.
  final String serverId;

  /// Max limit in bytes of requests to the server.
  final int maxRequestSize;

  /// Configuration for the main API server.
  final ServerConfig apiServer;

  /// Configuration for the Insights server.
  final ServerConfig? insightsServer;

  /// Configuration for the web server (optional).
  final ServerConfig? webServer;

  /// Configuration for the Postgres database.
  final DatabaseConfig? database;

  /// Configuration for Redis.
  final RedisConfig? redis;

  /// Authentication key for service protocol.
  late final String? serviceSecret;

  /// Creates a new [ServerpodConfig].
  ServerpodConfig({
    required this.apiServer,
    this.runMode = 'development',
    this.serverId = 'default',
    this.maxRequestSize = 524288,
    this.insightsServer,
    this.webServer,
    this.database,
    this.redis,
    this.serviceSecret,
  }) {
    apiServer._name = 'api';
    insightsServer?._name = 'insights';
    webServer?._name = 'web';
  }

  /// Creates a default bare bone configuration.
  factory ServerpodConfig.defaultConfig() {
    return ServerpodConfig(
      apiServer: ServerConfig(
        port: 8080,
        publicHost: 'localhost',
        publicPort: 8080,
        publicScheme: 'http',
      ),
    );
  }

  /// Creates a new [ServerpodConfig] from a YAML document.
  /// Expects the yaml document to match the specified run mode.
  ///
  /// Throws an exception if the configuration is missing required fields.
  factory ServerpodConfig.loadFromYaml(
    String runMode,
    String serverId,
    Map<String, String> passwords,
    YamlMap yaml,
  ) {
    /// Get api server setup. This field cannot be null, so if the
    /// configuration is missing an exception is thrown.
    var apiSetup = yaml['apiServer'];
    if (apiSetup == null) {
      throw Exception('apiServer is missing in config');
    }

    var apiServer = ServerConfig._fromJson(apiSetup, 'apiServer');

    /// Get insights server setup
    var insightsSetup = yaml['insightsServer'];
    var insightsServer = insightsSetup != null
        ? ServerConfig._fromJson(insightsSetup, 'insightsServer')
        : null;

    /// Get web server setup
    var webSetup = yaml['webServer'];
    var webServer =
        webSetup != null ? ServerConfig._fromJson(webSetup, 'webServer') : null;

    // Get max request size (default to 512kb)
    var maxRequestSize = yaml['maxRequestSize'] ?? 524288;

    var serviceSecret = passwords['serviceSecret'];

    // Get database setup
    var dbSetup = yaml['database'];
    var database = dbSetup != null
        ? DatabaseConfig._fromJson(dbSetup, passwords, 'database')
        : null;

    // Get Redis setup
    var redisSetup = yaml['redis'];
    var redis = redisSetup != null
        ? RedisConfig._fromJson(redisSetup, passwords, 'redis')
        : null;

    return ServerpodConfig(
      runMode: runMode,
      serverId: serverId,
      apiServer: apiServer,
      maxRequestSize: maxRequestSize,
      insightsServer: insightsServer,
      webServer: webServer,
      database: database,
      redis: redis,
      serviceSecret: serviceSecret,
    );
  }

  /// Loads and parses a server configuration file. Picks config file depending
  /// on run mode.
  factory ServerpodConfig.load(
    String runMode,
    String serverId,
    Map<String, String> passwords,
  ) {
    String data;

    data = File(_createConfigPath(runMode)).readAsStringSync();

    var doc = loadYaml(data);
    return ServerpodConfig.loadFromYaml(runMode, serverId, passwords, doc);
  }

  /// Checks if a configuration file is available on disk for the given run mode.
  static bool isConfigAvailable(String runMode) {
    return File(_createConfigPath(runMode)).existsSync();
  }

  static String _createConfigPath(String runMode) {
    return path.joinAll(['config', '$runMode.yaml']);
  }

  @override
  String toString() {
    var str = '';

    str += apiServer.toString();
    if (insightsServer != null) str += insightsServer.toString();
    if (webServer != null) str += webServer.toString();

    if (database != null) str += database.toString();
    if (redis != null) str += redis.toString();

    return str;
  }
}

/// Configuration for a server.
class ServerConfig {
  String? _name;

  /// The port the server will be running on.
  final int port;

  /// Public facing host name.
  final String publicHost;

  /// Public facing port.
  final int publicPort;

  /// Public facing scheme, i.e. http or https.
  final String publicScheme;

  ///
  ServerConfig({
    required this.port,
    required this.publicScheme,
    required this.publicHost,
    required this.publicPort,
  });

  factory ServerConfig._fromJson(Map serverSetup) {
    return ServerConfig(
      port: serverSetup['port'] as int,
      publicHost: serverSetup['publicHost'] as String,
      publicPort: serverSetup['publicPort'] as int,
      publicScheme: serverSetup['publicScheme'] as String,
    );
  }

  @override
  String toString() {
    var str = '';
    str += '$_name port: $port\n';
    str += '$_name public host: $publicHost\n';
    str += '$_name public port: $publicPort\n';
    str += '$_name public scheme: $publicScheme\n';

    return str;
  }
}

/// Configuration for a Postgres database,
class DatabaseConfig {
  /// Database host.
  final String host;

  /// Database port.
  final int port;

  /// Database user name.
  final String user;

  /// Database password.
  final String password;

  /// Database name.
  final String name;

  /// True if the database requires an SSL connection.
  final bool requireSsl;

  /// True if the database is running on a unix socket.
  final bool isUnixSocket;

  /// Creates a new [DatabaseConfig].
  DatabaseConfig({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.name,
    this.requireSsl = false,
    this.isUnixSocket = false,
  });

  factory DatabaseConfig._fromJson(Map dbSetup, Map<String, String> passwords) {
    assert(passwords['database'] != null, 'Database password is missing');
    return DatabaseConfig(
      host: dbSetup['host']!,
      port: dbSetup['port']!,
      name: dbSetup['name']!,
      user: dbSetup['user']!,
      requireSsl: dbSetup['requireSsl'] ?? false,
      isUnixSocket: dbSetup['isUnixSocket'] ?? false,
      password: passwords['database']!,
    );
  }

  @override
  String toString() {
    var str = '';
    str += 'database host: $host\n';
    str += 'database port: $port\n';
    str += 'database name: $name\n';
    str += 'database user: $user\n';
    str += 'database require SSL: $requireSsl\n';
    str += 'database unix socket: $isUnixSocket\n';
    str += 'database pass: ********\n';
    return str;
  }
}

/// Configuration for Redis.
class RedisConfig {
  /// True if Redis should be enabled.
  final bool enabled;

  /// Redis host.
  final String host;

  /// Redis port.
  final int port;

  /// Redis user name (optional).
  final String? user;

  /// Redis password (optional, but recommended).
  final String? password;

  /// Creates a new [RedisConfig].
  RedisConfig({
    required this.enabled,
    required this.host,
    required this.port,
    this.user,
    this.password,
  });

  factory RedisConfig._fromJson(Map redisSetup, Map<String, String> passwords) {
    return RedisConfig(
      enabled: redisSetup['enabled'] ?? false,
      host: redisSetup['host']!,
      port: redisSetup['port']!,
      user: redisSetup['user'],
      password: passwords['redis'],
    );
  }

  @override
  String toString() {
    var str = '';
    str += 'redis host: $host\n';
    str += 'redis port: $port\n';
    if (user != null) {
      str += 'redis user: $user\n';
    }
    if (password != null) {
      str += 'redis pass: ********\n';
    }
    return str;
  }
}
