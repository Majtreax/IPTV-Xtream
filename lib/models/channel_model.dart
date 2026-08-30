// REPRESENTS A SINGLE IPTV CHANNEL/STREAM
class Channel {
  final int streamId;
  final String name;
  final String logoUrl;
  final String groupTitle;
  final String categoryId;
  final String streamUrl;
  final String epgChannelId;
  final String streamType;

  const Channel({
    required this.streamId,
    required this.name,
    this.logoUrl = '',
    this.groupTitle = '',
    this.categoryId = '',
    this.streamUrl = '',
    this.epgChannelId = '',
    this.streamType = 'live',
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      streamId: _parseInt(json['stream_id'] ?? json['streamId']),
      name: (json['name'] ?? json['tvg-name'] ?? '').toString(),
      logoUrl:
          (json['stream_icon'] ?? json['logoUrl'] ?? json['tvg-logo'] ?? '')
              .toString(),
      groupTitle:
          (json['category_name'] ??
                  json['groupTitle'] ??
                  json['group-title'] ??
                  '')
              .toString(),
      categoryId: (json['category_id'] ?? json['categoryId'] ?? '').toString(),
      streamUrl: (json['streamUrl'] ?? json['stream_url'] ?? '').toString(),
      epgChannelId:
          (json['epg_channel_id'] ??
                  json['epgChannelId'] ??
                  json['tvg-id'] ??
                  '')
              .toString(),
      streamType: (json['stream_type'] ?? json['streamType'] ?? 'live')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streamId': streamId,
      'name': name,
      'logoUrl': logoUrl,
      'groupTitle': groupTitle,
      'categoryId': categoryId,
      'streamUrl': streamUrl,
      'epgChannelId': epgChannelId,
      'streamType': streamType,
    };
  }

  Channel copyWith({
    int? streamId,
    String? name,
    String? logoUrl,
    String? groupTitle,
    String? categoryId,
    String? streamUrl,
    String? epgChannelId,
    String? streamType,
  }) {
    return Channel(
      streamId: streamId ?? this.streamId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      groupTitle: groupTitle ?? this.groupTitle,
      categoryId: categoryId ?? this.categoryId,
      streamUrl: streamUrl ?? this.streamUrl,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      streamType: streamType ?? this.streamType,
    );
  }

  @override
  String toString() {
    return 'Channel(streamId: $streamId, name: $name, groupTitle: $groupTitle, categoryId: $categoryId, streamType: $streamType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Channel &&
        other.streamId == streamId &&
        other.streamType == streamType;
  }

  @override
  int get hashCode => streamId.hashCode ^ streamType.hashCode;

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
