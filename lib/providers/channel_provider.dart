import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/data/repositories/channel_repository.dart';
import 'package:iptv_xtream/providers/auth_provider.dart';
import 'package:iptv_xtream/providers/category_provider.dart';
import 'package:iptv_xtream/models/channel_model.dart';

// ---------------------------------------------------------------------------
// CHANNEL STATE
// ---------------------------------------------------------------------------

class ChannelState {
  final List<Channel> channels;
  final List<Channel> filteredChannels;
  final bool isLoading;
  final String? errorMessage;
  final String? activeCategoryId;
  final String searchQuery;

  const ChannelState({
    this.channels = const [],
    this.filteredChannels = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeCategoryId,
    this.searchQuery = '',
  });

  ChannelState copyWith({
    List<Channel>? channels,
    List<Channel>? filteredChannels,
    bool? isLoading,
    String? errorMessage,
    String? activeCategoryId,
    String? searchQuery,
  }) {
    return ChannelState(
      channels: channels ?? this.channels,
      filteredChannels: filteredChannels ?? this.filteredChannels,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeCategoryId: activeCategoryId ?? this.activeCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// ---------------------------------------------------------------------------
// CHANNEL NOTIFIER
// ---------------------------------------------------------------------------

class ChannelNotifier extends StateNotifier<ChannelState> {
  final ChannelRepository _repository;

  ChannelNotifier(this._repository) : super(const ChannelState());

  // LOAD ALL CHANNELS (OPTIONALLY FOR A SPECIFIC CATEGORY)
  Future<void> loadChannels({String? categoryId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final channels = await _repository.getChannels(categoryId: categoryId);
      state = ChannelState(
        channels: channels,
        filteredChannels: _applySearch(channels, state.searchQuery),
        activeCategoryId: categoryId,
        searchQuery: state.searchQuery,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // FILTER CHANNELS BY CATEGORY
  Future<void> filterByCategory(String? categoryId) async {
    await loadChannels(categoryId: categoryId);
  }

  // SEARCH CHANNELS BY NAME
  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredChannels: _applySearch(state.channels, query),
    );
  }

  // CLEAR THE SEARCH FILTER
  void clearSearch() {
    state = state.copyWith(searchQuery: '', filteredChannels: state.channels);
  }

  // GET THE STREAM URL FOR A CHANNEL
  String getStreamUrl(Channel channel) {
    return _repository.getStreamUrl(channel);
  }

  // APPLY SEARCH FILTER TO A LIST OF CHANNELS
  List<Channel> _applySearch(List<Channel> channels, String query) {
    if (query.isEmpty) return channels;
    final lowerQuery = query.toLowerCase();
    return channels
        .where((ch) => ch.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// PROVIDERS
// ---------------------------------------------------------------------------

// CHANNEL REPOSITORY PROVIDER, DEPENDS ON THE AUTH STATE FOR THE API CLIENT
final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  final authState = ref.watch(authProvider);
  final authRepo = ref.read(authRepositoryProvider);

  final repository = ChannelRepository(apiClient: authRepo.apiClient);

  // IF M3U DATA WAS LOADED DURING AUTH, INJECT IT
  if (authState.m3uData != null) {
    repository.setM3uData(
      channels: authState.m3uData!.channels,
      categories: authState.m3uData!.categories,
    );
  }

  return repository;
});

// CHANNEL STATE PROVIDER
final channelProvider = StateNotifierProvider<ChannelNotifier, ChannelState>((
  ref,
) {
  final repository = ref.watch(channelRepositoryProvider);
  return ChannelNotifier(repository);
});

// PROVIDES ONLY THE FILTERED (SEARCH-APPLIED) CHANNEL LIST
final filteredChannelsProvider = Provider<List<Channel>>((ref) {
  return ref.watch(channelProvider).filteredChannels;
});

// PROVIDES THE CHANNEL COUNT
final channelCountProvider = Provider<int>((ref) {
  return ref.watch(channelProvider).channels.length;
});

// FETCHES CHANNELS FOR A SPECIFIC CATEGORY ID DYNAMICALLY (FOR DASHBOARD GRIDS)
final channelsByCategoryProvider =
    FutureProvider.family<List<Channel>, String?>((ref, categoryId) async {
      final repository = ref.watch(channelRepositoryProvider);
      final allowedLiveCats = ref.watch(liveCategoriesProvider);
      final allowedLiveCatIds = allowedLiveCats.map((c) => c.id).toSet();
      final allowedLiveCatNames = allowedLiveCats.map((c) => c.name).toSet();

      final channels = await repository.getChannels(categoryId: categoryId);
      if (allowedLiveCatIds.isNotEmpty) {
        return channels.where((ch) {
          if (ch.categoryId.isNotEmpty) {
            return allowedLiveCatIds.contains(ch.categoryId);
          }
          if (ch.groupTitle.isNotEmpty) {
            return allowedLiveCatNames.contains(ch.groupTitle);
          }
          return true;
        }).toList();
      }
      return channels;
    });
