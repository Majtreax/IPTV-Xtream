import 'package:http/http.dart' as http;
import 'package:iptv_xtream/data/api/xtream_api.dart';
import 'package:iptv_xtream/data/parsers/m3u_parser.dart';
import 'package:iptv_xtream/models/channel_model.dart';
import 'package:iptv_xtream/models/category_model.dart';
import 'package:flutter/foundation.dart' show compute;

// REPOSITORY FOR LOADING AND MANAGING CHANNELS
// SUPPORTS TWO DATA SOURCES:
// - XTREAM CODES API (VIA [XTREAMAPICLIENT])
// - M3U PLAYLIST (VIA [M3UPARSER])
class ChannelRepository {
  final XtreamApiClient? _apiClient;

  // CACHED CHANNELS FROM M3U PARSE (USED WHEN NO API CLIENT IS AVAILABLE)
  List<Channel>? _m3uChannels;
  List<Category>? _m3uCategories;

  ChannelRepository({this._apiClient});

  // INJECT M3U-PARSED DATA FOR OFFLINE/M3U-ONLY MODE
  void setM3uData({
    required List<Channel> channels,
    required List<Category> categories,
  }) {
    _m3uChannels = channels;
    _m3uCategories = categories;
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------------------------

  // LOAD LIVE TV CATEGORIES
  Future<List<Category>> getCategories() async {
    if (_apiClient != null) {
      try {
        return await _apiClient.getLiveCategories();
      } catch (_) {}
    }
    return _m3uCategories?.where((c) => c.type == 'live').toList() ?? [];
  }

  // ---------------------------------------------------------------------------
  // CHANNELS
  // ---------------------------------------------------------------------------

  // LOAD ALL LIVE CHANNELS, OPTIONALLY FILTERED BY [CATEGORYID]
  Future<List<Channel>> getChannels({String? categoryId}) async {
    List<Channel> channels;

    if (_apiClient != null) {
      try {
        channels = await _apiClient.getLiveStreams(categoryId: categoryId);
      } catch (_) {
        channels = _m3uChannels ?? [];
      }
    } else {
      channels = _m3uChannels ?? [];
    }

    // FILTER BY CATEGORY IF WE HAVE M3U DATA AND A CATEGORYID
    if (_apiClient == null) {
      channels = channels.where((c) => c.streamType == 'live').toList();
      if (categoryId != null && categoryId.isNotEmpty) {
        final category = _m3uCategories
            ?.where((c) => c.id == categoryId)
            .firstOrNull;
        if (category != null) {
          channels = channels
              .where((ch) => ch.groupTitle == category.name)
              .toList();
        }
      }
    }

    return channels;
  }

  // SEARCH CHANNELS BY NAME (CASE-INSENSITIVE)
  Future<List<Channel>> searchChannels(String query) async {
    final allChannels = await getChannels();
    if (query.isEmpty) return allChannels;

    final lowerQuery = query.toLowerCase();
    return allChannels
        .where((ch) => ch.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // LOAD CHANNELS FROM AN M3U URL
  Future<ParseResult> loadFromM3uUrl(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load M3U playlist: HTTP ${response.statusCode}',
      );
    }

    final result = await compute(M3uParser.parse, response.body);
    setM3uData(channels: result.channels, categories: result.categories);
    return result;
  }

  // LOAD CHANNELS FROM RAW M3U CONTENT STRING
  Future<ParseResult> loadFromM3uContent(String content) async {
    final result = await compute(M3uParser.parse, content);
    setM3uData(channels: result.channels, categories: result.categories);
    return result;
  }

  // GET THE STREAM URL FOR A CHANNEL
  String getStreamUrl(Channel channel) {
    if (channel.streamUrl.isNotEmpty) return channel.streamUrl;
    if (_apiClient != null) {
      return _apiClient.buildLiveStreamUrl(channel.streamId);
    }
    return '';
  }
}
