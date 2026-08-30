// REPRESENTS A SINGLE EPISODE WITHIN A SEASON
class Episode {
  final int id;
  final int episodeNum;
  final String title;
  final String? containerExtension;
  final String? plot;
  final double? rating;
  final String? releaseDate;
  final String? coverUrl;
  final int? durationSeconds;

  const Episode({
    required this.id,
    required this.episodeNum,
    required this.title,
    this.containerExtension,
    this.plot,
    this.rating,
    this.releaseDate,
    this.coverUrl,
    this.durationSeconds,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: _parseInt(json['id'] ?? json['episode_id']),
      episodeNum: _parseInt(json['episode_num'] ?? json['episodeNum']),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      containerExtension:
          json['container_extension']?.toString() ??
          json['containerExtension']?.toString(),
      plot: json['plot']?.toString() ?? json['info']?['plot']?.toString(),
      rating: _tryParseDouble(json['rating'] ?? json['info']?['rating']),
      releaseDate:
          json['releaseDate']?.toString() ??
          json['info']?['release_date']?.toString(),
      coverUrl:
          json['coverUrl']?.toString() ??
          json['info']?['movie_image']?.toString(),
      durationSeconds: _tryParseInt(
        json['duration_secs'] ??
            json['durationSeconds'] ??
            json['info']?['duration_secs'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'episodeNum': episodeNum,
      'title': title,
      if (containerExtension != null) 'containerExtension': containerExtension,
      if (plot != null) 'plot': plot,
      if (rating != null) 'rating': rating,
      if (releaseDate != null) 'releaseDate': releaseDate,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
  }

  Episode copyWith({
    int? id,
    int? episodeNum,
    String? title,
    String? containerExtension,
    String? plot,
    double? rating,
    String? releaseDate,
    String? coverUrl,
    int? durationSeconds,
  }) {
    return Episode(
      id: id ?? this.id,
      episodeNum: episodeNum ?? this.episodeNum,
      title: title ?? this.title,
      containerExtension: containerExtension ?? this.containerExtension,
      plot: plot ?? this.plot,
      rating: rating ?? this.rating,
      releaseDate: releaseDate ?? this.releaseDate,
      coverUrl: coverUrl ?? this.coverUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  String toString() =>
      'Episode(id: $id, episodeNum: $episodeNum, title: $title)';

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

// REPRESENTS A SEASON OF A SERIES
class Season {
  final int seasonNumber;
  final String? name;
  final String? coverUrl;
  final List<Episode> episodes;

  const Season({
    required this.seasonNumber,
    this.name,
    this.coverUrl,
    this.episodes = const [],
  });

  factory Season.fromJson(
    Map<String, dynamic> json, {
    List<Episode> episodes = const [],
  }) {
    return Season(
      seasonNumber: Episode._parseInt(
        json['season_number'] ?? json['seasonNumber'],
      ),
      name: json['name']?.toString(),
      coverUrl: json['cover']?.toString() ?? json['coverUrl']?.toString(),
      episodes: episodes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seasonNumber': seasonNumber,
      if (name != null) 'name': name,
      if (coverUrl != null) 'coverUrl': coverUrl,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }

  Season copyWith({
    int? seasonNumber,
    String? name,
    String? coverUrl,
    List<Episode>? episodes,
  }) {
    return Season(
      seasonNumber: seasonNumber ?? this.seasonNumber,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      episodes: episodes ?? this.episodes,
    );
  }

  @override
  String toString() =>
      'Season(seasonNumber: $seasonNumber, episodes: ${episodes.length})';
}

// REPRESENTS A VOD ITEM
class VodItem {
  final int streamId;
  final String name;
  final String? coverUrl;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final String? containerExtension;
  final String streamType;
  final List<Season>? seasons;
  final String? categoryId;

  const VodItem({
    required this.streamId,
    required this.name,
    this.coverUrl,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.containerExtension,
    this.streamType = 'movie',
    this.seasons,
    this.categoryId,
  });

  factory VodItem.fromJson(Map<String, dynamic> json) {
    // XTREAM API NESTS MOVIES/SERIES INFO INSIDE AN 'INFO' KEY SOMETIMES
    final info = json['info'] as Map<String, dynamic>? ?? {};

    return VodItem(
      streamId: Episode._parseInt(
        json['stream_id'] ?? json['series_id'] ?? json['streamId'],
      ),
      name: (json['name'] ?? json['title'] ?? info['name'] ?? '').toString(),
      coverUrl:
          (json['stream_icon'] ??
                  json['cover'] ??
                  json['coverUrl'] ??
                  info['cover'] ??
                  info['movie_image'])
              ?.toString(),
      plot: (json['plot'] ?? info['plot'] ?? info['description'])?.toString(),
      cast: (json['cast'] ?? info['cast'])?.toString(),
      director: (json['director'] ?? info['director'])?.toString(),
      genre: (json['genre'] ?? json['category_name'] ?? info['genre'])
          ?.toString(),
      releaseDate:
          (json['releaseDate'] ??
                  json['release_date'] ??
                  info['releasedate'] ??
                  info['release_date'])
              ?.toString(),
      rating: _tryParseDouble(
        json['rating'] ??
            json['rating_5based'] ??
            info['rating'] ??
            info['rating_5based'],
      ),
      containerExtension:
          (json['container_extension'] ?? json['containerExtension'])
              ?.toString(),
      streamType:
          (json['stream_type'] ??
                  json['streamType'] ??
                  (json['series_id'] != null ? 'series' : 'movie'))
              .toString(),
      categoryId: (json['category_id'] ?? json['categoryId'])?.toString(),
      seasons: _parseSeasonsFromJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streamId': streamId,
      'name': name,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (plot != null) 'plot': plot,
      if (cast != null) 'cast': cast,
      if (director != null) 'director': director,
      if (genre != null) 'genre': genre,
      if (releaseDate != null) 'releaseDate': releaseDate,
      if (rating != null) 'rating': rating,
      if (containerExtension != null) 'containerExtension': containerExtension,
      'streamType': streamType,
      if (categoryId != null) 'categoryId': categoryId,
      if (seasons != null) 'seasons': seasons!.map((s) => s.toJson()).toList(),
    };
  }

  VodItem copyWith({
    int? streamId,
    String? name,
    String? coverUrl,
    String? plot,
    String? cast,
    String? director,
    String? genre,
    String? releaseDate,
    double? rating,
    String? containerExtension,
    String? streamType,
    List<Season>? seasons,
    String? categoryId,
  }) {
    return VodItem(
      streamId: streamId ?? this.streamId,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      plot: plot ?? this.plot,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      genre: genre ?? this.genre,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      containerExtension: containerExtension ?? this.containerExtension,
      streamType: streamType ?? this.streamType,
      seasons: seasons ?? this.seasons,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  @override
  String toString() {
    return 'VodItem(streamId: $streamId, name: $name, streamType: $streamType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VodItem &&
        other.streamId == streamId &&
        other.streamType == streamType;
  }

  @override
  int get hashCode => streamId.hashCode ^ streamType.hashCode;

  // PARSE SEASONS FROM THE XTREAM API 'EPISODES' STRUCTURE
  // THE API RETURNS EPISODES GROUPED BY SEASON NUMBER AS KEYS
  static List<Season>? _parseSeasonsFromJson(Map<String, dynamic> json) {
    final episodesData = json['episodes'];
    final seasonsData = json['seasons'];
    if (episodesData == null &&
        seasonsData == null &&
        json['seasons'] == null) {
      return null;
    }

    final List<Season> seasons = [];

    if (episodesData is Map<String, dynamic>) {
      // XTREAM API FORMAT: { "1": [ {EPISODE}, ... ], "2": [ ... ] }
      for (final entry in episodesData.entries) {
        final seasonNum = int.tryParse(entry.key) ?? 0;
        final episodeList = entry.value;
        final List<Episode> episodes = [];
        if (episodeList is List) {
          for (final ep in episodeList) {
            if (ep is Map<String, dynamic>) {
              episodes.add(Episode.fromJson(ep));
            }
          }
        }
        String? seasonName;
        String? seasonCover;
        if (seasonsData is List) {
          for (final s in seasonsData) {
            if (s is Map<String, dynamic>) {
              final sNum = Episode._parseInt(s['season_number']);
              if (sNum == seasonNum) {
                seasonName = s['name']?.toString();
                seasonCover = s['cover']?.toString();
                break;
              }
            }
          }
        }
        seasons.add(
          Season(
            seasonNumber: seasonNum,
            name: seasonName,
            coverUrl: seasonCover,
            episodes: episodes,
          ),
        );
      }
      seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    } else if (json['seasons'] is List) {
      for (final s in json['seasons'] as List) {
        if (s is Map<String, dynamic>) {
          final episodes =
              (s['episodes'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .map(Episode.fromJson)
                  .toList() ??
              [];
          seasons.add(Season.fromJson(s, episodes: episodes));
        }
      }
    }
    return seasons.isEmpty ? null : seasons;
  }

  static double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
