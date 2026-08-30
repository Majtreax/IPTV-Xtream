import 'package:iptv_xtream/data/api/xtream_api.dart';
import 'package:iptv_xtream/models/category_model.dart';
import 'package:iptv_xtream/models/vod_model.dart';
import 'package:iptv_xtream/models/channel_model.dart';

// REPOSITORY FOR LOADING AND MANAGING VOD (VIDEO ON DEMAND) CONTENT
// HANDLES BOTH MOVIES AND SERIES THROUGH THE XTREAM CODES API OR M3U DATA
class VodRepository {
  final XtreamApiClient? _apiClient;
  List<Channel>? _m3uChannels;
  List<Category>? _m3uCategories;

  VodRepository({this._apiClient});

  void setM3uData({
    required List<Channel> channels,
    required List<Category> categories,
  }) {
    _m3uChannels = channels;
    _m3uCategories = categories;
  }

  // HANDLES FORMATS LIKE:
  // "NAME S01 E01"
  // "SHOW S01E10"
  static final _sePattern = RegExp(
    r'(.*?)\s*-?\s*S\s*(\d+)\s*E\s*(\d+)(.*)',
    caseSensitive: false,
  );

  // GROUP M3U CHANNELS INTO VODITEMS FOR SERIES
  List<VodItem> _m3uToVod(List<Channel> channels, String streamType) {
    final filtered = channels.where((c) => c.streamType == streamType).toList();

    if (streamType == 'series') {
      return _groupSeriesChannels(filtered);
    }

    // MOVIES: 1 CHANNEL = 1 VODITEM
    return filtered.map((c) {
      return VodItem(
        streamId: c.streamId,
        name: c.name,
        coverUrl: c.logoUrl,
        streamType: c.streamType,
        containerExtension: _extractExtension(c.streamUrl),
      );
    }).toList();
  }

  // CORE SERIES GROUPING LOGIC:
  // 1. PARSE EACH CHANNEL NAME WITH REGEX TO EXTRACT SERIESNAME, S##, E##
  // 2. GROUP ALL CHANNELS WITH THE SAME SERIESNAME INTO ONE VODITEM
  // 3. CREATE SEASON AND EPISODE STRUCTURES
  List<VodItem> _groupSeriesChannels(List<Channel> channels) {
    // SERIESNAME -> { SEASONNUM -> [EPISODE] }
    final Map<String, _SeriesAccumulator> seriesMap = {};

    for (final c in channels) {
      final match = _sePattern.firstMatch(c.name);

      String seriesName;
      int seasonNum;
      int episodeNum;

      if (match != null) {
        // MATCHED "SERIES NAME S01 E01" PATTERN
        seriesName = match.group(1)!.trim();
        seasonNum = int.tryParse(match.group(2)!) ?? 1;
        episodeNum = int.tryParse(match.group(3)!) ?? 1;
      } else {
        // NO S##E## PATTERN FOUND, TREATING AS STANDALONE EPISODE
        seriesName = c.name;
        seasonNum = 1;
        episodeNum = 1;
      }

      // INITIALIZE ACCUMULATOR FOR THIS SERIES IF NEW
      seriesMap.putIfAbsent(
        seriesName,
        () =>
            _SeriesAccumulator(firstStreamId: c.streamId, coverUrl: c.logoUrl),
      );

      // ADD THIS EPISODE
      seriesMap[seriesName]!.addEpisode(
        seasonNum: seasonNum,
        episode: Episode(
          id: c.streamId,
          episodeNum: episodeNum,
          title: c.name,
          containerExtension: _extractExtension(c.streamUrl),
        ),
      );
    }

    // CONVERT ACCUMULATORS TO VODITEMS
    return seriesMap.entries.map((entry) {
      final acc = entry.value;
      final seasons = acc.toSeasons();
      return VodItem(
        streamId: acc.firstStreamId,
        name: entry.key,
        coverUrl: acc.coverUrl,
        streamType: 'series',
        seasons: seasons,
      );
    }).toList();
  }

  String _extractExtension(String url) {
    final lastDot = url.lastIndexOf('.');
    if (lastDot == -1 || lastDot == url.length - 1) return 'mp4';
    final ext = url.substring(lastDot + 1);
    // ONLY RETURN VALID-LOOKING EXTENSIONS
    if (ext.length <= 5 && !ext.contains('/') && !ext.contains('?')) {
      return ext;
    }
    return 'mp4';
  }

  // ---------------------------------------------------------------------------
  // MOVIE CATEGORIES & STREAMS
  // ---------------------------------------------------------------------------

  Future<List<Category>> getMovieCategories() async {
    if (_apiClient != null) {
      try {
        return await _apiClient.getMovieCategories();
      } catch (_) {}
    }
    return _m3uCategories?.where((c) => c.type == 'vod').toList() ?? [];
  }

  Future<List<VodItem>> getMovieStreams({String? categoryId}) async {
    if (_apiClient != null) {
      try {
        return await _apiClient.getMovieStreams(categoryId: categoryId);
      } catch (_) {}
    }
    var channels = _m3uChannels ?? [];
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
    return _m3uToVod(channels, 'movie');
  }

  // ---------------------------------------------------------------------------
  // SERIES CATEGORIES & STREAMS
  // ---------------------------------------------------------------------------

  Future<List<Category>> getSeriesCategories() async {
    if (_apiClient != null) {
      try {
        return await _apiClient.getSeriesCategories();
      } catch (_) {}
    }
    return _m3uCategories?.where((c) => c.type == 'series').toList() ?? [];
  }

  Future<List<VodItem>> getSeries({String? categoryId}) async {
    if (_apiClient != null) {
      try {
        return await _apiClient.getSeries(categoryId: categoryId);
      } catch (_) {}
    }
    var channels = _m3uChannels ?? [];
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
    return _m3uToVod(channels, 'series');
  }

  Future<VodItem> getSeriesInfo(String seriesId) async {
    if (_apiClient == null) {
      throw Exception('Client not available.');
    }
    try {
      return await _apiClient.getSeriesInfo(seriesId);
    } catch (e) {
      throw _wrapError('Failed to load series info.', e);
    }
  }

  Future<VodItem> getMovieInfo(String movieId) async {
    if (_apiClient == null) {
      throw Exception('Client not available.');
    }
    try {
      return await _apiClient.getMovieInfo(movieId);
    } catch (e) {
      throw _wrapError('Failed to load movie info.', e);
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Future<List<VodItem>> searchVod(String query, {String type = 'movie'}) async {
    if (query.isEmpty) return [];

    final List<VodItem> items;
    if (type == 'series') {
      items = await getSeries();
    } else {
      items = await getMovieStreams();
    }

    final lowerQuery = query.toLowerCase();
    return items
        .where((item) => item.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // STREAM URL HELPERS
  // ---------------------------------------------------------------------------

  // BUILD STREAM URL FOR A MOVIE
  String getMovieStreamUrl(VodItem item) {
    if (_apiClient != null) {
      return _apiClient.buildVodStreamUrl(
        item.streamId,
        extension: item.containerExtension ?? 'mp4',
      );
    }
    return _m3uChannels
            ?.where((c) => c.streamId == item.streamId)
            .firstOrNull
            ?.streamUrl ??
        '';
  }

  // BUILD STREAM URL FOR A SERIES EPISODE
  // FOR M3U: THE EPISODE ID IS THE CHANNEL'S STREAMID, SO WE LOOK IT UP DIRECTLY
  String getEpisodeStreamUrl(int episodeId, {String extension = 'mp4'}) {
    if (_apiClient != null) {
      return _apiClient.buildSeriesStreamUrl(episodeId, extension: extension);
    }
    // M3U FALLBACK: EPISODE.ID == CHANNEL.STREAMID
    return _m3uChannels
            ?.where((c) => c.streamId == episodeId)
            .firstOrNull
            ?.streamUrl ??
        '';
  }

  // ---------------------------------------------------------------------------
  // INTERNAL
  // ---------------------------------------------------------------------------

  Exception _wrapError(String context, Object error) {
    if (error is XtreamApiException) return error;
    return Exception('$context: $error');
  }
}

// ACCUMULATOR USED DURING SERIES GROUPING TO COLLECT EPISODES BY SEASON
class _SeriesAccumulator {
  final int firstStreamId;
  final String coverUrl;
  final Map<int, List<Episode>> _seasons = {};

  _SeriesAccumulator({required this.firstStreamId, required this.coverUrl});

  void addEpisode({required int seasonNum, required Episode episode}) {
    _seasons.putIfAbsent(seasonNum, () => []);
    _seasons[seasonNum]!.add(episode);
  }

  List<Season> toSeasons() {
    final sortedKeys = _seasons.keys.toList()..sort();
    return sortedKeys.map((seasonNum) {
      final episodes = _seasons[seasonNum]!
        ..sort((a, b) => a.episodeNum.compareTo(b.episodeNum));
      return Season(seasonNumber: seasonNum, episodes: episodes);
    }).toList();
  }
}
