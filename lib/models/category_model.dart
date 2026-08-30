// REPRESENTS A CONTENT CATEGORY (LIVE TV GROUP, MOVIE GENRE, SERIES GENRE)
class Category {
  final String id;
  final String name;
  final String type;
  final String? parentId;
  final int? channelCount;

  const Category({
    required this.id,
    required this.name,
    this.type = 'live',
    this.parentId,
    this.channelCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['category_id'] ?? json['id'] ?? '').toString(),
      name: (json['category_name'] ?? json['name'] ?? '').toString(),
      parentId: json['parent_id']?.toString() ?? json['parentId']?.toString(),
      type: (json['type'] ?? 'live').toString(),
      channelCount: _tryParseInt(json['channelCount'] ?? json['channel_count']),
    );
  }

  // CREATE A CATEGORY FROM AN M3U GROUP-TITLE STRING
  factory Category.fromGroupTitle(String groupTitle, {String type = 'live'}) {
    // GENERATE A DETERMINISTIC ID FROM THE GROUP TITLE
    final id = groupTitle.hashCode.abs().toString();
    return Category(id: id, name: groupTitle, type: type);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (parentId != null) 'parentId': parentId,
      'type': type,
      if (channelCount != null) 'channelCount': channelCount,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? parentId,
    String? type,
    int? channelCount,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      channelCount: channelCount ?? this.channelCount,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, type: $type, channelCount: $channelCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id && other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode;

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}
