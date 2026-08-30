import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_xtream/data/parsers/m3u_parser.dart';
import 'package:iptv_xtream/data/api/xtream_api.dart';
import 'package:iptv_xtream/models/server_model.dart';
import 'package:flutter/foundation.dart' show compute;

// MANAGES AUTHENTICATION STATE
class AuthRepository {
  static const String _prefKeyServerUrl = 'auth_server_url';
  static const String _prefKeyUsername = 'auth_username';
  static const String _prefKeyPassword = 'auth_password';
  static const String _prefKeyServerInfo = 'auth_server_info';
  static const String _prefKeyLoginType =
      'auth_login_type'; // 'XTREAM' OR 'M3U'
  static const String _prefKeyM3uUrl = 'auth_m3u_url';

  XtreamApiClient? _apiClient;

  // THE CURRENTLY ACTIVE API CLIENT (AVAILABLE AFTER A SUCCESSFUL LOGIN)
  XtreamApiClient? get apiClient => _apiClient;

  // ---------------------------------------------------------------------------
  // XTREAM CODES LOGIN
  // ---------------------------------------------------------------------------

  // LOGIN WITH XTREAM CODES CREDENTIALS
  // AUTHENTICATES AGAINST THE SERVER AND PERSISTS CREDENTIALS ON SUCCESS
  Future<ServerInfo> loginWithXtream({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'http://$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    _apiClient = XtreamApiClient(
      serverUrl: normalizedUrl,
      username: username.trim(),
      password: password.trim(),
    );

    final serverInfo = await _apiClient!.authenticate();

    if (!serverInfo.isAuthenticated) {
      _apiClient = null;
      throw const XtreamApiException('Invalid credentials.');
    }

    await _saveCredentials(
      serverUrl: normalizedUrl,
      username: username.trim(),
      password: password.trim(),
      serverInfo: serverInfo,
      loginType: 'xtream',
    );

    return serverInfo;
  }

  // ---------------------------------------------------------------------------
  // M3U LOGIN
  // ---------------------------------------------------------------------------

  // LOGIN BY PROVIDING AN M3U PLAYLIST URL
  // DOWNLOADS AND PARSES THE PLAYLIST, AUTO-DETECTS XTREAM CREDENTIALS
  Future<({ServerInfo? serverInfo, ParseResult parseResult})> loginWithM3u({
    required String m3uUrl,
  }) async {
    String m3uContent = '';

    if (m3uUrl.startsWith('http://') || m3uUrl.startsWith('https://')) {
      final response = await http
          .get(Uri.parse(m3uUrl))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw XtreamApiException(
          'Failed to load M3U playlist.',
          statusCode: response.statusCode,
          url: m3uUrl,
        );
      }
      m3uContent = response.body;
    } else {
      // LOCAL FILE
      final file = File(m3uUrl);
      if (!await file.exists()) {
        throw XtreamApiException('Local file not found: $m3uUrl');
      }
      m3uContent = await file.readAsString();
    }

    final parseResult = await compute(M3uParser.parse, m3uContent);

    if (parseResult.channels.isEmpty) {
      throw const XtreamApiException('Playlist contains no channels.');
    }

    ServerInfo? serverInfo = parseResult.serverInfo;

    // IF XTREAM CREDENTIALS WERE DETECTED, TRY TO AUTHENTICATE
    if (serverInfo != null && serverInfo.serverUrl.isNotEmpty) {
      try {
        _apiClient = XtreamApiClient(
          serverUrl: serverInfo.serverUrl,
          username: serverInfo.username,
          password: serverInfo.password,
        );
        serverInfo = await _apiClient!.authenticate();
      } catch (_) {
        // AUTHENTICATION FAILED, CONTINUE WITH M3U-ONLY MODE
        _apiClient = null;
      }
    }

    // PERSIST M3U URL AND ANY DETECTED CREDENTIALS
    if (serverInfo != null && _apiClient != null) {
      // SUCCESSFULLY AUTHENTICATED WITH XTREAM API
      // SAVE AS AN XTREAM LOGIN SO WE DON'T DEPEND ON THE M3U FILE ON NEXT STARTUP
      await _saveCredentials(
        serverUrl: serverInfo.serverUrl,
        username: serverInfo.username,
        password: serverInfo.password,
        serverInfo: serverInfo,
        loginType: 'xtream',
      );
    } else {
      // M3U ONLY MODE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyM3uUrl, m3uUrl);
      await prefs.setString(_prefKeyLoginType, 'm3u');

      if (serverInfo != null) {
        await _saveCredentials(
          serverUrl: serverInfo.serverUrl,
          username: serverInfo.username,
          password: serverInfo.password,
          serverInfo: serverInfo,
          loginType: 'm3u',
        );
      }
    }

    return (serverInfo: serverInfo, parseResult: parseResult);
  }

  // ---------------------------------------------------------------------------
  // SESSION RESTORE
  // ---------------------------------------------------------------------------

  // ATTEMPT TO RESTORE A PREVIOUSLY SAVED SESSION
  // RETURNS THE [SERVERINFO] IF CREDENTIALS ARE AVAILABLE, NULL OTHERWISE
  Future<ServerInfo?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    final serverUrl = prefs.getString(_prefKeyServerUrl);
    final username = prefs.getString(_prefKeyUsername);
    final password = prefs.getString(_prefKeyPassword);

    if (serverUrl == null || username == null || password == null) return null;
    if (serverUrl.isEmpty || username.isEmpty) return null;

    // RESTORE CACHED SERVER INFO
    final serverInfoJson = prefs.getString(_prefKeyServerInfo);
    ServerInfo? cached;
    if (serverInfoJson != null) {
      try {
        cached = ServerInfo.fromJson(
          json.decode(serverInfoJson) as Map<String, dynamic>,
        );
      } catch (_) {
        // CORRUPTED CACHE, WILL RE-AUTHENTICATE
      }
    }

    // RE-CREATE THE API CLIENT
    _apiClient = XtreamApiClient(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );

    // RETURN CACHED INFO IMMEDIATELY
    return cached ??
        ServerInfo(
          serverUrl: serverUrl,
          username: username,
          password: password,
          isAuthenticated: true,
        );
  }

  // THE SAVED LOGIN TYPE ('XTREAM' OR 'M3U')
  Future<String?> getSavedLoginType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyLoginType);
  }

  // THE SAVED M3U URL (ONLY VALID WHEN LOGINTYPE IS 'M3U')
  Future<String?> getSavedM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyM3uUrl);
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  // CLEAR ALL SAVED CREDENTIALS AND DISPOSE THE API CLIENT
  Future<void> logout() async {
    _apiClient?.dispose();
    _apiClient = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyServerUrl);
    await prefs.remove(_prefKeyUsername);
    await prefs.remove(_prefKeyPassword);
    await prefs.remove(_prefKeyServerInfo);
    await prefs.remove(_prefKeyLoginType);
    await prefs.remove(_prefKeyM3uUrl);
    await prefs.remove('last_played_channel');
    await prefs.remove('fav_col_0');
    await prefs.remove('fav_col_1');
    await prefs.remove('fav_col_2');
    await prefs.remove('sel_cat_live');
    await prefs.remove('sel_cat_movie');
    await prefs.remove('sel_cat_series');
  }

  // ---------------------------------------------------------------------------
  // INTERNAL
  // ---------------------------------------------------------------------------

  Future<void> _saveCredentials({
    required String serverUrl,
    required String username,
    required String password,
    required ServerInfo serverInfo,
    required String loginType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyServerUrl, serverUrl);
    await prefs.setString(_prefKeyUsername, username);
    await prefs.setString(_prefKeyPassword, password);
    await prefs.setString(_prefKeyServerInfo, json.encode(serverInfo.toJson()));
    await prefs.setString(_prefKeyLoginType, loginType);
  }
}
