import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/data/repositories/vod_repository.dart';
import 'package:iptv_xtream/providers/category_provider.dart';
import 'package:iptv_xtream/models/vod_model.dart';

// ---------------------------------------------------------------------------
// VOD STATE
// ---------------------------------------------------------------------------

class VodState {
  final List<VodItem> items;
  final List<VodItem> filteredItems;
  final bool isLoading;
  final String? errorMessage;
  final String? activeCategoryId;
  final String searchQuery;
  final String contentType;
  final VodItem? selectedItem;

  const VodState({
    this.items = const [],
    this.filteredItems = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeCategoryId,
    this.searchQuery = '',
    this.contentType = 'movie',
    this.selectedItem,
  });

  VodState copyWith({
    List<VodItem>? items,
    List<VodItem>? filteredItems,
    bool? isLoading,
    String? errorMessage,
    String? activeCategoryId,
    String? searchQuery,
    String? contentType,
    VodItem? selectedItem,
  }) {
    return VodState(
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeCategoryId: activeCategoryId ?? this.activeCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      contentType: contentType ?? this.contentType,
      selectedItem: selectedItem ?? this.selectedItem,
    );
  }
}

// ---------------------------------------------------------------------------
// VOD NOTIFIER
// ---------------------------------------------------------------------------

class VodNotifier extends StateNotifier<VodState> {
  final VodRepository _repository;

  VodNotifier(this._repository) : super(const VodState());

  // LOAD MOVIE ITEMS
  Future<void> loadMovies({
    String? categoryId,
    Set<String>? allowedCategoryIds,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      contentType: 'movie',
    );

    try {
      var items = await _repository.getMovieStreams(categoryId: categoryId);
      if (allowedCategoryIds != null) {
        items = items
            .where((i) => allowedCategoryIds.contains(i.categoryId))
            .toList();
      }
      state = VodState(
        items: items,
        filteredItems: _applySearch(items, state.searchQuery),
        activeCategoryId: categoryId,
        searchQuery: state.searchQuery,
        contentType: 'movie',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // LOAD SERIES ITEMS
  Future<void> loadSeries({
    String? categoryId,
    Set<String>? allowedCategoryIds,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      contentType: 'series',
    );

    try {
      var items = await _repository.getSeries(categoryId: categoryId);
      if (allowedCategoryIds != null) {
        items = items
            .where((i) => allowedCategoryIds.contains(i.categoryId))
            .toList();
      }
      state = VodState(
        items: items,
        filteredItems: _applySearch(items, state.searchQuery),
        activeCategoryId: categoryId,
        searchQuery: state.searchQuery,
        contentType: 'series',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // LOAD FULL MOVIE INFO (PLOT/CAST)
  Future<void> loadMovieInfo(String movieId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final item = await _repository.getMovieInfo(movieId);
      state = state.copyWith(isLoading: false, selectedItem: item);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // LOAD FULL SERIES INFO (SEASONS/EPISODES)
  Future<void> loadSeriesInfo(String seriesId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final item = await _repository.getSeriesInfo(seriesId);
      state = state.copyWith(isLoading: false, selectedItem: item);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // FILTER BY CATEGORY
  Future<void> filterByCategory(String? categoryId) async {
    if (state.contentType == 'series') {
      await loadSeries(categoryId: categoryId);
    } else {
      await loadMovies(categoryId: categoryId);
    }
  }

  // SEARCH VOD ITEMS BY NAME
  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredItems: _applySearch(state.items, query),
    );
  }

  // CLEAR SEARCH FILTER
  void clearSearch() {
    state = state.copyWith(searchQuery: '', filteredItems: state.items);
  }

  // SELECT AN ITEM FOR DETAILED VIEW
  void selectItem(VodItem? item) {
    state = state.copyWith(selectedItem: item);
  }

  // GET THE STREAM URL FOR A MOVIE
  String getMovieStreamUrl(VodItem item) {
    return _repository.getMovieStreamUrl(item);
  }

  // GET THE STREAM URL FOR A SERIES EPISODE
  String getEpisodeStreamUrl(int episodeId, {String extension = 'mp4'}) {
    return _repository.getEpisodeStreamUrl(episodeId, extension: extension);
  }

  List<VodItem> _applySearch(List<VodItem> items, String query) {
    if (query.isEmpty) return items;
    final lowerQuery = query.toLowerCase();
    return items
        .where((item) => item.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// PROVIDERS
// ---------------------------------------------------------------------------

// MOVIES STATE PROVIDER
final moviesProvider = StateNotifierProvider<VodNotifier, VodState>((ref) {
  final repository = ref.watch(vodRepositoryProvider);
  return VodNotifier(repository);
});

// SERIES STATE PROVIDER
final seriesProvider = StateNotifierProvider<VodNotifier, VodState>((ref) {
  final repository = ref.watch(vodRepositoryProvider);
  return VodNotifier(repository);
});
