import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iptv_xtream/models/channel_model.dart';
import 'package:iptv_xtream/models/category_model.dart';
import 'package:iptv_xtream/models/vod_model.dart';
import 'package:iptv_xtream/models/server_model.dart';

// EXCEPTION THROWN WHEN THE XTREAM API CALL FAILS
class XtreamApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? url;

  const XtreamApiException(this.message, {this.statusCode, this.url});

  @override
  String toString() =>
      'XtreamApiException: $message (status: $statusCode, url: $url)';
}

// CLIENT FOR THE XTREAM CODES API
// ALL ENDPOINTS FOLLOW THE PATTERN:
// {SERVERURL}/PLAYER_API.PHP?USERNAME={USER}&PASSWORD={PASS}&ACTION={ACTION}
class XtreamApiClient {
  final String serverUrl;
  final String username;
  final String password;
  final http.Client _httpClient;
  final Duration timeout;

  ServerInfo? _cachedServerInfo;

  XtreamApiClient({
    required this.serverUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client();

  // THE BASE URL FOR ALL API CALLS
  String get _baseUrl {
    final cleanUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return '$cleanUrl/player_api.php?username=$username&password=$password';
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  // AUTHENTICATE WITH THE XTREAM CODES SERVER
  // CALLS THE API WITHOUT AN ACTION (BASE ENDPOINT) WHICH RETURNS USER_INFO AND SERVER_INFO
  Future<ServerInfo> authenticate() async {
    final data = await _getJson(_baseUrl);

    _cachedServerInfo = ServerInfo.fromJson({
      ...data,
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
    });

    return _cachedServerInfo!;
  }

  // RETURNS THE CACHED SERVER INFO (REQUIRES [AUTHENTICATE] TO BE CALLED FIRST)
  ServerInfo? get serverInfo => _cachedServerInfo;

  // ---------------------------------------------------------------------------
  // LIVE TV
  // ---------------------------------------------------------------------------

  // FETCH ALL LIVE STREAM CATEGORIES
  Future<List<Category>> getLiveCategories() async {
    final data = await _getJsonList('$_baseUrl&action=get_live_categories');
    return data
        .map((json) => Category.fromJson({...json, 'type': 'live'}))
        .toList();
  }

  // FETCH LIVE STREAMS, OPTIONALLY FILTERED BY [CATEGORYID]
  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    var url = '$_baseUrl&action=get_live_streams';
    if (categoryId != null && categoryId.isNotEmpty) {
      url += '&category_id=$categoryId';
    }
    final data = await _getJsonList(url);
    return data.map((json) {
      final channel = Channel.fromJson({...json, 'stream_type': 'live'});
      // BUILD THE STREAM URL IF NOT PROVIDED
      return channel.streamUrl.isNotEmpty
          ? channel
          : channel.copyWith(streamUrl: buildLiveStreamUrl(channel.streamId));
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // MOVIES
  // ---------------------------------------------------------------------------

  // FETCH ALL MOVIE CATEGORIES
  Future<List<Category>> getMovieCategories() async {
    final data = await _getJsonList('$_baseUrl&action=get_vod_categories');
    return data
        .map((json) => Category.fromJson({...json, 'type': 'vod'}))
        .toList();
  }

  // FETCH MOVIES LIST, OPTIONALLY FILTERED BY [CATEGORYID]
  Future<List<VodItem>> getMovieStreams({String? categoryId}) async {
    var url = '$_baseUrl&action=get_vod_streams';
    if (categoryId != null && categoryId.isNotEmpty) {
      url += '&category_id=$categoryId';
    }
    final data = await _getJsonList(url);
    return data
        .map((json) => VodItem.fromJson({...json, 'stream_type': 'movie'}))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // SERIES
  // ---------------------------------------------------------------------------

  // FETCH ALL SERIES CATEGORIES
  Future<List<Category>> getSeriesCategories() async {
    final data = await _getJsonList('$_baseUrl&action=get_series_categories');
    return data
        .map((json) => Category.fromJson({...json, 'type': 'series'}))
        .toList();
  }

  // FETCH SERIES LIST, OPTIONALLY FILTERED BY [CATEGORYID]
  Future<List<VodItem>> getSeries({String? categoryId}) async {
    var url = '$_baseUrl&action=get_series';
    if (categoryId != null && categoryId.isNotEmpty) {
      url += '&category_id=$categoryId';
    }
    final data = await _getJsonList(url);
    return data
        .map((json) => VodItem.fromJson({...json, 'stream_type': 'series'}))
        .toList();
  }

  // FETCH DETAILED INFO FOR A MOVIE
  Future<VodItem> getMovieInfo(String movieId) async {
    final data = await _getJson(
      '$_baseUrl&action=get_vod_info&vod_id=$movieId',
    );
    final movieData = data['movie_data'] as Map<String, dynamic>? ?? {};
    return VodItem.fromJson({...data, ...movieData, 'stream_type': 'movie'});
  }

  // FETCH FULL DETAILS (SEASONS, EPISODES, INFO) FOR A GIVEN SERIES
  Future<VodItem> getSeriesInfo(String seriesId) async {
    final data = await _getJson(
      '$_baseUrl&action=get_series_info&series_id=$seriesId',
    );
    return VodItem.fromJson({...data, 'stream_type': 'series'});
  }


  // ---------------------------------------------------------------------------
  // STREAM URL BUILDERS
  // ---------------------------------------------------------------------------

  // BUILD A LIVE STREAM URL
  // FORMAT: {SERVER}/LIVE/{USER}/{PASS}/{STREAMID}.TS
  String buildLiveStreamUrl(int streamId, {String extension = 'ts'}) {
    final cleanUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return '$cleanUrl/live/$username/$password/$streamId.$extension';
  }

  // BUILD A MOVIE STREAM URL
  // FORMAT: {SERVER}/MOVIE/{USER}/{PASS}/{STREAMID}.{EXT}
  String buildVodStreamUrl(int streamId, {String extension = 'mp4'}) {
    final cleanUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return '$cleanUrl/movie/$username/$password/$streamId.$extension';
  }

  // BUILD A SERIES EPISODE STREAM URL
  // FORMAT: {SERVER}/SERIES/{USER}/{PASS}/{STREAMID}.{EXT}
  String buildSeriesStreamUrl(int streamId, {String extension = 'mp4'}) {
    final cleanUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    return '$cleanUrl/series/$username/$password/$streamId.$extension';
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HTTP HELPERS
  // ---------------------------------------------------------------------------

  // PERFORM A GET REQUEST EXPECTING A JSON OBJECT RESPONSE
  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _get(url);
    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw XtreamApiException(
      'Expected JSON object but got ${decoded.runtimeType}',
      url: url,
    );
  }

  // PERFORM A GET REQUEST EXPECTING A JSON ARRAY RESPONSE
  Future<List<Map<String, dynamic>>> _getJsonList(String url) async {
    final response = await _get(url);
    final decoded = json.decode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    // SOME XTREAM SERVERS RETURN AN EMPTY OBJECT {} INSTEAD OF [] FOR NO RESULTS
    if (decoded is Map) return [];
    throw XtreamApiException(
      'Expected JSON array but got ${decoded.runtimeType}',
      url: url,
    );
  }

  // CORE HTTP GET WITH ERROR HANDLING AND TIMEOUT
  Future<http.Response> _get(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await _httpClient.get(uri).timeout(timeout);

      if (response.statusCode != 200) {
        throw XtreamApiException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          statusCode: response.statusCode,
          url: url,
        );
      }
      return response;
    } on XtreamApiException {
      rethrow;
    } on FormatException catch (e) {
      throw XtreamApiException('Invalid response format: $e', url: url);
    } catch (e) {
      throw XtreamApiException('Network error: $e', url: url);
    }
  }

  // CLOSE THE UNDERLYING HTTP CLIENT
  void dispose() {
    _httpClient.close();
  }
}
