import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/data/repositories/channel_repository.dart';
import 'package:iptv_xtream/data/repositories/vod_repository.dart';
import 'package:iptv_xtream/models/category_model.dart';
import 'package:iptv_xtream/providers/auth_provider.dart';
import 'package:iptv_xtream/providers/channel_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// CATEGORY STATE
// ---------------------------------------------------------------------------

class CategoryState {
  final List<Category> liveCategories;
  final List<Category> movieCategories;
  final List<Category> seriesCategories;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedLiveCategoryId;
  final String? selectedMovieCategoryId;
  final String? selectedSeriesCategoryId;

  const CategoryState({
    this.liveCategories = const [],
    this.movieCategories = const [],
    this.seriesCategories = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedLiveCategoryId,
    this.selectedMovieCategoryId,
    this.selectedSeriesCategoryId,
  });

  CategoryState copyWith({
    List<Category>? liveCategories,
    List<Category>? movieCategories,
    List<Category>? seriesCategories,
    bool? isLoading,
    String? errorMessage,
    String? selectedLiveCategoryId,
    String? selectedMovieCategoryId,
    String? selectedSeriesCategoryId,
  }) {
    return CategoryState(
      liveCategories: liveCategories ?? this.liveCategories,
      movieCategories: movieCategories ?? this.movieCategories,
      seriesCategories: seriesCategories ?? this.seriesCategories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedLiveCategoryId:
          selectedLiveCategoryId ?? this.selectedLiveCategoryId,
      selectedMovieCategoryId:
          selectedMovieCategoryId ?? this.selectedMovieCategoryId,
      selectedSeriesCategoryId:
          selectedSeriesCategoryId ?? this.selectedSeriesCategoryId,
    );
  }

  // GET CATEGORIES FOR A SPECIFIC TYPE
  List<Category> categoriesForType(String type) {
    switch (type) {
      case 'live':
        return liveCategories;
      case 'movie':
        return movieCategories;
      case 'series':
        return seriesCategories;
      default:
        return [];
    }
  }

  // GET THE SELECTED CATEGORY ID FOR A SPECIFIC TYPE
  String? selectedIdForType(String type) {
    switch (type) {
      case 'live':
        return selectedLiveCategoryId;
      case 'movie':
        return selectedMovieCategoryId;
      case 'series':
        return selectedSeriesCategoryId;
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// CATEGORY NOTIFIER
// ---------------------------------------------------------------------------

class CategoryNotifier extends StateNotifier<CategoryState> {
  final ChannelRepository _channelRepo;
  final VodRepository _vodRepo;

  CategoryNotifier(this._channelRepo, this._vodRepo)
    : super(const CategoryState()) {
    _initSelections();
  }

  Future<void> _initSelections() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      selectedLiveCategoryId: prefs.getString('sel_cat_live'),
      selectedMovieCategoryId: prefs.getString('sel_cat_movie'),
      selectedSeriesCategoryId: prefs.getString('sel_cat_series'),
    );
  }

  bool _isAllowedCategory(Category c) {
    // NORMALIZE TURKISH CHARACTERS & UPPERCASE FOR SAFER MATCHING
    final nameNormalized = c.name
        .toUpperCase()
        .replaceAll('Ç', 'C')
        .replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G')
        .replaceAll('Ü', 'U')
        .replaceAll('Ö', 'O')
        .replaceAll('İ', 'I');

    final idNormalized = c.id
        .toUpperCase()
        .replaceAll('Ç', 'C')
        .replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G')
        .replaceAll('Ü', 'U')
        .replaceAll('Ö', 'O')
        .replaceAll('İ', 'I');

    final cleanName = nameNormalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final cleanId = idNormalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // FILTER OUT ANY MATCH IN NAME OR GROUP ID
    if (cleanName.contains('XXX') ||
        cleanId.contains('XXX') ||
        cleanName.contains('KURAN') ||
        cleanId.contains('KURAN')) {
      return false;
    }

    if (nameNormalized.startsWith('V/S TR ∞')) {
      if (nameNormalized.contains('PAZARTESI') ||
          nameNormalized.contains('SALI') ||
          nameNormalized.contains('CARSAMBA') ||
          nameNormalized.contains('PERSEMBE') ||
          nameNormalized.contains('CUMA') ||
          nameNormalized.contains('CUMARTESI') ||
          nameNormalized.contains('PAZAR')) {
        return false;
      }
    }
    return true;
  }

  // LOAD ALL CATEGORIES FOR ALL CONTENT TYPES
  Future<void> loadAllCategories() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final results = await Future.wait([
        _channelRepo.getCategories(),
        _vodRepo.getMovieCategories(),
        _vodRepo.getSeriesCategories(),
      ]);

      state = CategoryState(
        liveCategories: results[0].where(_isAllowedCategory).toList(),
        movieCategories: results[1].where(_isAllowedCategory).toList(),
        seriesCategories: results[2].where(_isAllowedCategory).toList(),
        selectedLiveCategoryId: state.selectedLiveCategoryId,
        selectedMovieCategoryId: state.selectedMovieCategoryId,
        selectedSeriesCategoryId: state.selectedSeriesCategoryId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // LOAD ONLY LIVE TV CATEGORIES
  Future<void> loadLiveCategories() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final categories = await _channelRepo.getCategories();
      state = state.copyWith(
        liveCategories: categories.where(_isAllowedCategory).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // LOAD ONLY MOVIE CATEGORIES
  Future<void> loadMovieCategories() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final categories = await _vodRepo.getMovieCategories();
      state = state.copyWith(
        movieCategories: categories.where(_isAllowedCategory).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // LOAD ONLY SERIES CATEGORIES
  Future<void> loadSeriesCategories() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final categories = await _vodRepo.getSeriesCategories();
      state = state.copyWith(
        seriesCategories: categories.where(_isAllowedCategory).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _saveSelection(String key, String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, id);
    }
  }

  // SELECT A LIVE TV CATEGORY
  void selectLiveCategory(String? categoryId) {
    state = state.copyWith(selectedLiveCategoryId: categoryId);
    _saveSelection('sel_cat_live', categoryId);
  }

  // SELECT A MOVIE CATEGORY
  void selectMovieCategory(String? categoryId) {
    state = state.copyWith(selectedMovieCategoryId: categoryId);
    _saveSelection('sel_cat_movie', categoryId);
  }

  // SELECT A SERIES CATEGORY
  void selectSeriesCategory(String? categoryId) {
    state = state.copyWith(selectedSeriesCategoryId: categoryId);
    _saveSelection('sel_cat_series', categoryId);
  }

  // CLEAR ALL SELECTIONS
  void clearSelections() {
    state = CategoryState(
      liveCategories: state.liveCategories,
      movieCategories: state.movieCategories,
      seriesCategories: state.seriesCategories,
    );
    _saveSelection('sel_cat_live', null);
    _saveSelection('sel_cat_movie', null);
    _saveSelection('sel_cat_series', null);
  }
}

// ---------------------------------------------------------------------------
// PROVIDERS
// ---------------------------------------------------------------------------

// VOD REPOSITORY PROVIDER
final vodRepositoryProvider = Provider<VodRepository>((ref) {
  final authState = ref.watch(authProvider);
  final authRepo = ref.read(authRepositoryProvider);
  final repository = VodRepository(apiClient: authRepo.apiClient);

  if (authState.m3uData != null) {
    repository.setM3uData(
      channels: authState.m3uData!.channels,
      categories: authState.m3uData!.categories,
    );
  }

  return repository;
});

// CATEGORY STATE PROVIDER
final categoryProvider = StateNotifierProvider<CategoryNotifier, CategoryState>(
  (ref) {
    final channelRepo = ref.watch(channelRepositoryProvider);
    final movieRepo = ref.watch(vodRepositoryProvider);
    return CategoryNotifier(channelRepo, movieRepo);
  },
);

// PROVIDES LIVE CATEGORIES ONLY
final liveCategoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(categoryProvider).liveCategories;
});

// PROVIDES MOVIE CATEGORIES ONLY
final movieCategoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(categoryProvider).movieCategories;
});

// PROVIDES SERIES CATEGORIES ONLY
final seriesCategoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(categoryProvider).seriesCategories;
});
