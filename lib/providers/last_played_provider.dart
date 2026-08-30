import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_xtream/models/channel_model.dart';
import 'package:iptv_xtream/models/vod_model.dart';

class LastPlayedVod {
  final VodItem item;
  final Episode? episode;
  final int? seasonNumber;
  final String streamUrl;
  final int? positionMs;
  final int? durationMs;

  const LastPlayedVod({
    required this.item,
    this.episode,
    this.seasonNumber,
    required this.streamUrl,
    this.positionMs,
    this.durationMs,
  });

  LastPlayedVod copyWith({
    VodItem? item,
    Episode? episode,
    int? seasonNumber,
    String? streamUrl,
    int? positionMs,
    int? durationMs,
  }) {
    return LastPlayedVod(
      item: item ?? this.item,
      episode: episode ?? this.episode,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      streamUrl: streamUrl ?? this.streamUrl,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        if (episode != null) 'episode': episode!.toJson(),
        if (seasonNumber != null) 'seasonNumber': seasonNumber,
        'streamUrl': streamUrl,
        if (positionMs != null) 'positionMs': positionMs,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory LastPlayedVod.fromJson(Map<String, dynamic> json) {
    return LastPlayedVod(
      item: VodItem.fromJson(json['item']),
      episode:
          json['episode'] != null ? Episode.fromJson(json['episode']) : null,
      seasonNumber: json['seasonNumber'],
      streamUrl: json['streamUrl'] ?? '',
      positionMs: json['positionMs'] as int?,
      durationMs: json['durationMs'] as int?,
    );
  }
}

class LastPlayedState {
  final Channel? lastChannel;
  final LastPlayedVod? lastMovie;
  final LastPlayedVod? lastSeries;

  const LastPlayedState({
    this.lastChannel,
    this.lastMovie,
    this.lastSeries,
  });

  LastPlayedState copyWith({
    Channel? lastChannel,
    LastPlayedVod? lastMovie,
    LastPlayedVod? lastSeries,
  }) {
    return LastPlayedState(
      lastChannel: lastChannel ?? this.lastChannel,
      lastMovie: lastMovie ?? this.lastMovie,
      lastSeries: lastSeries ?? this.lastSeries,
    );
  }

  Map<String, dynamic> toJson() => {
        if (lastChannel != null) 'lastChannel': lastChannel!.toJson(),
        if (lastMovie != null) 'lastMovie': lastMovie!.toJson(),
        if (lastSeries != null) 'lastSeries': lastSeries!.toJson(),
      };

  factory LastPlayedState.fromJson(Map<String, dynamic> json) {
    return LastPlayedState(
      lastChannel: json['lastChannel'] != null
          ? Channel.fromJson(json['lastChannel'])
          : null,
      lastMovie: json['lastMovie'] != null
          ? LastPlayedVod.fromJson(json['lastMovie'])
          : null,
      lastSeries: json['lastSeries'] != null
          ? LastPlayedVod.fromJson(json['lastSeries'])
          : null,
    );
  }
}

class LastPlayedNotifier extends StateNotifier<LastPlayedState> {
  static const String _prefKey = 'last_played_state';

  LastPlayedNotifier() : super(const LastPlayedState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefKey);
      if (jsonString != null) {
        state = LastPlayedState.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      // IGNORE
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(state.toJson()));
    } catch (e) {
      // IGNORE
    }
  }

  Future<void> setLastChannel(Channel channel) async {
    state = state.copyWith(lastChannel: channel);
    await _saveState();
  }

  Future<void> setLastMovie(
    VodItem item,
    String streamUrl, {
    int? positionMs,
    int? durationMs,
  }) async {
    state = state.copyWith(
      lastMovie: LastPlayedVod(
        item: item,
        streamUrl: streamUrl,
        positionMs: positionMs ?? state.lastMovie?.positionMs,
        durationMs: durationMs ?? state.lastMovie?.durationMs,
      ),
    );
    await _saveState();
  }

  Future<void> setLastSeries(
    VodItem item,
    Episode episode,
    int seasonNumber,
    String streamUrl, {
    int? positionMs,
    int? durationMs,
  }) async {
    state = state.copyWith(
      lastSeries: LastPlayedVod(
        item: item,
        episode: episode,
        seasonNumber: seasonNumber,
        streamUrl: streamUrl,
        positionMs: positionMs ?? (state.lastSeries?.episode?.id == episode.id ? state.lastSeries?.positionMs : null),
        durationMs: durationMs ?? (state.lastSeries?.episode?.id == episode.id ? state.lastSeries?.durationMs : null),
      ),
    );
    await _saveState();
  }

  Future<void> updatePlaybackPosition({
    required String type,
    required int positionMs,
    int? durationMs,
  }) async {
    if (type == 'series' && state.lastSeries != null) {
      state = state.copyWith(
        lastSeries: state.lastSeries!.copyWith(
          positionMs: positionMs,
          durationMs: durationMs ?? state.lastSeries!.durationMs,
        ),
      );
      await _saveState();
    } else if ((type == 'movie' || type == 'vod') && state.lastMovie != null) {
      state = state.copyWith(
        lastMovie: state.lastMovie!.copyWith(
          positionMs: positionMs,
          durationMs: durationMs ?? state.lastMovie!.durationMs,
        ),
      );
      await _saveState();
    }
  }

  Future<void> clear() async {
    state = const LastPlayedState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      // IGNORE
    }
  }
}

final lastPlayedProvider =
    StateNotifierProvider<LastPlayedNotifier, LastPlayedState>((ref) {
  return LastPlayedNotifier();
});

final lastChannelProvider = Provider<Channel?>((ref) {
  return ref.watch(lastPlayedProvider).lastChannel;
});

final lastMovieProvider = Provider<LastPlayedVod?>((ref) {
  return ref.watch(lastPlayedProvider).lastMovie;
});

final lastSeriesProvider = Provider<LastPlayedVod?>((ref) {
  return ref.watch(lastPlayedProvider).lastSeries;
});
