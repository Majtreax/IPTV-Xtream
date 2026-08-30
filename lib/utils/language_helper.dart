// CENTRALIZED LANGUAGE CLASSIFICATION AND DEDUPLICATION (7 LANGUAGES ONLY)

class LanguageHelper {
  static const List<String> supportedLanguages = [
    'TR',
    'EN',
    'GER',
    'FRA',
    'SPA',
    'POR',
    'RU',
  ];

  static String? detectLanguageCode(Map<String, dynamic> track) {
    final lang = (track['language'] as String?)?.toLowerCase().trim() ?? '';
    final title = (track['title'] as String?)?.toLowerCase().trim() ?? '';
    final id = (track['id']?.toString() ?? '').toLowerCase().trim();

    // TURKISH
    if (lang == 'tr' ||
        lang == 'tur' ||
        lang.startsWith('tr-') ||
        lang.startsWith('tr_') ||
        title.contains('turk') ||
        title.contains('türk') ||
        id.contains('tur') ||
        id == 'tr') {
      return 'TR';
    }

    // ENGLISH
    if (lang == 'en' ||
        lang == 'eng' ||
        lang.startsWith('en-') ||
        lang.startsWith('en_') ||
        title.contains('english') ||
        title.contains('eng') ||
        id.contains('eng') ||
        id == 'en') {
      return 'EN';
    }

    // GERMAN
    if (lang == 'de' ||
        lang == 'ger' ||
        lang == 'deu' ||
        lang.startsWith('de-') ||
        lang.startsWith('de_') ||
        title.contains('german') ||
        title.contains('deutsch') ||
        title.contains('ger') ||
        id.contains('ger') ||
        id.contains('deu') ||
        id == 'de') {
      return 'GER';
    }

    // FRENCH
    if (lang == 'fr' ||
        lang == 'fre' ||
        lang == 'fra' ||
        lang.startsWith('fr-') ||
        lang.startsWith('fr_') ||
        title.contains('french') ||
        title.contains('français') ||
        title.contains('francais') ||
        title.contains('fra') ||
        title.contains('fre') ||
        id.contains('fra') ||
        id.contains('fre') ||
        id == 'fr') {
      return 'FRA';
    }

    // SPANISH
    if (lang == 'es' ||
        lang == 'spa' ||
        lang == 'esp' ||
        lang.startsWith('es-') ||
        lang.startsWith('es_') ||
        title.contains('spanish') ||
        title.contains('español') ||
        title.contains('espanol') ||
        title.contains('castellano') ||
        title.contains('castilian') ||
        title.contains('spa') ||
        title.contains('esp') ||
        id.contains('spa') ||
        id.contains('esp') ||
        id == 'es') {
      return 'SPA';
    }

    // PORTUGUESE
    if (lang == 'pt' ||
        lang == 'por' ||
        lang == 'pob' ||
        lang.startsWith('pt-') ||
        lang.startsWith('pt_') ||
        title.contains('portuguese') ||
        title.contains('português') ||
        title.contains('portugues') ||
        title.contains('brazilian') ||
        title.contains('por') ||
        title.contains('pob') ||
        id.contains('por') ||
        id.contains('pob') ||
        id == 'pt') {
      return 'POR';
    }

    // RUSSIAN
    if (lang == 'ru' ||
        lang == 'rus' ||
        lang.startsWith('ru-') ||
        lang.startsWith('ru_') ||
        title.contains('russian') ||
        title.contains('русский') ||
        title.contains('rus') ||
        id.contains('rus') ||
        id == 'ru') {
      return 'RU';
    }

    return null;
  }

  static bool isForcedTrack(Map<String, dynamic> track) {
    final title = (track['title'] as String?)?.toLowerCase().trim() ?? '';
    final id = (track['id']?.toString() ?? '').toLowerCase().trim();
    return title.contains('forced') ||
        title.contains('forzado') ||
        title.contains('forzada') ||
        title.contains('force') ||
        title.contains('forcé') ||
        title.contains('forçado') ||
        id.contains('forced');
  }

  static String getLabel(Map<String, dynamic> track, [int? index]) {
    final id = track['id']?.toString().toLowerCase().trim() ?? '';
    final lang = track['language']?.toString().toLowerCase().trim() ?? '';
    final label = track['label']?.toString() ?? '';

    if (id == 'no' || id == 'none' || lang == 'off' || label == 'OFF') {
      return 'OFF';
    }
    if (label.isNotEmpty) {
      return label;
    }
    final code = detectLanguageCode(track);
    if (code != null) return code;
    return index != null ? '[$index]' : 'TRACK';
  }

  static List<Map<String, dynamic>> filterAndDeduplicateTracks(
    List<Map<String, dynamic>> list, {
    bool isSubtitle = false,
  }) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final item in list) {
      final id = item['id']?.toString().toLowerCase().trim() ?? '';
      final lang = item['language']?.toString().toLowerCase().trim() ?? '';
      if (id == 'no' || id == 'none' || lang == 'off') continue;

      final code = detectLanguageCode(item);
      if (code != null) {
        grouped.putIfAbsent(code, () => []).add(item);
      }
    }

    final result = <Map<String, dynamic>>[];

    if (isSubtitle) {
      result.add({
        'original_index': -1,
        'id': 'no',
        'label': 'OFF',
        'title': 'Off',
        'language': 'OFF',
      });
    }

    for (final lang in supportedLanguages) {
      final tracks = grouped[lang];
      if (tracks == null || tracks.isEmpty) continue;

      if (isSubtitle) {
        // FILTER OUT FORCED TRACKS IF FULL SUBTITLE TRACKS EXIST
        final nonForced = tracks.where((t) => !isForcedTrack(t)).toList();
        final selected = nonForced.isNotEmpty ? nonForced : tracks;

        if (selected.length == 1) {
          result.add({
            ...selected[0],
            'label': lang,
          });
        } else {
          // NUMBER MULTIPLE TRACKS AS SPA [1] AND SPA [2]
          for (int i = 0; i < selected.take(2).length; i++) {
            result.add({
              ...selected[i],
              'label': '$lang [${i + 1}]',
            });
          }
        }
      } else {
        // FOR AUDIO TAKE FIRST STANDARD AUDIO TRACK FOR EACH LANGUAGE
        result.add({
          ...tracks.first,
          'label': lang,
        });
      }
    }

    return result;
  }
}
