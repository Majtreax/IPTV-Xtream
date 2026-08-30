import 'package:iptv_xtream/models/channel_model.dart';
import 'package:iptv_xtream/models/category_model.dart';
import 'package:iptv_xtream/models/server_model.dart';

// RESULT OF PARSING THE M3U PLAYLIST
class ParseResult {
  final List<Channel> channels;
  final List<Category> categories;
  final ServerInfo? serverInfo;

  const ParseResult({
    required this.channels,
    required this.categories,
    this.serverInfo,
  });

  @override
  String toString() {
    return 'ParseResult(channels: ${channels.length}, categories: ${categories.length}, serverInfo: $serverInfo)';
  }
}

// HANDLES STANDARD EXTENDED M3U FORMAT WITH #EXTINF LINES
// CONTAININING ATTRIBUTES LIKE TVG-ID, TVG-NAME, TVG-LOGO, AND GROUP-TITLE
class M3uParser {
  // REGEX PATTERNS COMPILED ONCE FOR REUSE
  static final RegExp _attrRegex = RegExp(r'([\w-]+)="([^"]*)"');
  static final RegExp _displayNameRegex = RegExp(r',(.+)$');
  // XTREAM CODES URL PATTERN: HTTP(S)://SERVER:PORT/USERNAME/PASSWORD/STREAMID.EXT
  static final RegExp _xtreamUrlRegex = RegExp(
    r'^(https?://[^/]+)/([^/]+)/([^/]+)/(\d+)(?:\.\w+)?$',
  );

  // PARSE M3U CONTENT STRING INTO A [PARSERESULT]
  // PROCESSES THE CONTENT LINE-BY-LINE FOR MEMORY EFFICIENCY WITH LARGE FILES
  static ParseResult parse(String content) {
    if (content.isEmpty) {
      return const ParseResult(channels: [], categories: []);
    }

    final lines = content.split('\n');
    final channels = <Channel>[];
    final categoryMap = <String, Category>{}; // GROUP-TITLE → CATEGORY
    ServerInfo? serverInfo;
    int syntheticId = 1;

    String? pendingExtInf;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;
      if (line.startsWith('#EXTM3U')) continue;

      if (line.startsWith('#EXTINF:')) {
        pendingExtInf = line;
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      if (pendingExtInf == null) continue;

      final streamUrl = line;
      final channel = _parseExtInfLine(pendingExtInf, streamUrl, syntheticId);
      pendingExtInf = null;

      if (channel == null) continue;

      channels.add(channel);
      syntheticId++;

      // AUTO-CREATE CATEGORIES FROM GROUP-TITLE
      if (channel.groupTitle.isNotEmpty &&
          !categoryMap.containsKey(channel.groupTitle)) {
        String catType = channel.streamType;
        if (catType == 'movie') catType = 'vod';

        // IF THE TITLE EXPLICITLY SAYS V/M OR V/S, OVERRIDE IT
        // BUT OTHERWISE TRUST THE STREAM URL DETECTION
        final gtUpper = channel.groupTitle.toUpperCase();
        if (gtUpper.startsWith('V/M')) {
          catType = 'vod';
        } else if (gtUpper.startsWith('V/S')) {
          catType = 'series';
        }

        categoryMap[channel.groupTitle] = Category.fromGroupTitle(
          channel.groupTitle,
          type: catType,
        );
      }

      // TRY TO DETECT XTREAM CODES CREDENTIALS FROM THE FIRST VALID URL
      serverInfo ??= _detectXtreamCredentials(streamUrl);
    }

    // SET CHANNEL COUNTS ON CATEGORIES
    final categoriesWithCounts = <Category>[];
    for (final entry in categoryMap.entries) {
      final count = channels.where((c) => c.groupTitle == entry.key).length;
      categoriesWithCounts.add(entry.value.copyWith(channelCount: count));
    }

    return ParseResult(
      channels: channels,
      categories: categoriesWithCounts,
      serverInfo: serverInfo,
    );
  }

  // PARSE A SINGLE #EXTINF LINE AND ITS ASSOCIATED STREAM URL INTO A [CHANNEL]
  static Channel? _parseExtInfLine(
    String extInfLine,
    String streamUrl,
    int syntheticId,
  ) {
    // EXTRACT ATTRIBUTES: TVG-ID="...", TVG-NAME="...", ETC
    final attributes = <String, String>{};
    for (final match in _attrRegex.allMatches(extInfLine)) {
      final key = match.group(1)!;
      final value = match.group(2)!;
      attributes[key] = value;
    }

    // EXTRACT DISPLAY NAME, TEXT AFTER THE LAST COMMA
    String displayName = '';
    final nameMatch = _displayNameRegex.firstMatch(extInfLine);
    if (nameMatch != null) {
      displayName = nameMatch.group(1)!.trim();
    }

    // USE DISPLAY NAME FIRST BECAUSE IT CONTAINS FULL TITLE/SEASON INFO
    // THEN FALLBACK TO TVG-NAME WHICH MIGHT ONLY BE "SERIES NAME"
    final name = displayName.isNotEmpty
        ? displayName
        : (attributes['tvg-name'] ?? '');

    if (name.isEmpty && streamUrl.isEmpty) return null;

    // TRY TO EXTRACT STREAM ID FROM URL
    int streamId = syntheticId;
    final urlMatch = _xtreamUrlRegex.firstMatch(streamUrl);
    if (urlMatch != null) {
      streamId = int.tryParse(urlMatch.group(4)!) ?? syntheticId;
    }

    final groupTitle = attributes['group-title'] ?? '';

    return Channel(
      streamId: streamId,
      name: name.isNotEmpty ? name : 'Channel $syntheticId',
      logoUrl: attributes['tvg-logo'] ?? '',
      groupTitle: groupTitle,
      streamUrl: streamUrl,
      epgChannelId: attributes['tvg-id'] ?? '',
      streamType: _detectStreamType(
        streamUrl,
        groupTitle,
        name.isNotEmpty ? name : 'Channel $syntheticId',
      ),
    );
  }

  // ATTEMPT TO DETECT XTREAM CODES SERVER CREDENTIALS FROM A STREAM URL
  // XTREAM URLS FOLLOW THE PATTERN: HTTP://SERVER:PORT/USERNAME/PASSWORD/STREAMID
  static ServerInfo? _detectXtreamCredentials(String url) {
    final match = _xtreamUrlRegex.firstMatch(url);
    if (match == null) return null;

    final serverUrl = match.group(1)!;
    final username = match.group(2)!;
    final password = match.group(3)!;

    const reservedPaths = {
      'live',
      'movie',
      'series',
      'panel_api.php',
      'player_api.php',
    };
    if (reservedPaths.contains(username.toLowerCase())) return null;

    return ServerInfo(
      serverUrl: serverUrl,
      username: username,
      password: password,
      isAuthenticated: true,
    );
  }

  // DETECT STREAM TYPE FROM URL PATH SEGMENTS
  static String _detectStreamType(String url, String groupTitle, String name) {
    final gtUpper = groupTitle.toUpperCase();
    if (gtUpper.startsWith('V/M') ||
        gtUpper.contains('MOVIE') ||
        gtUpper.contains('VOD')) {
      return 'movie';
    }
    if (gtUpper.startsWith('V/S') ||
        gtUpper.contains('SERIES') ||
        gtUpper.contains('SHOWS')) {
      return 'series';
    }

    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('/movie/')) return 'movie';
    if (lowerUrl.contains('/series/')) return 'series';

    final ext = lowerUrl.split('.').last.split('?').first;
    const movieExts = {'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'};
    if (movieExts.contains(ext)) {
      final sePattern = RegExp(r'S\d+\s*E\d+', caseSensitive: false);
      if (sePattern.hasMatch(name)) return 'series';
      return 'movie';
    }
    return 'live';
  }

  // PARSE AN M3U FILE FROM A URL
  static ParseResult parseFromLines(List<String> lines) {
    return parse(lines.join('\n'));
  }
}
