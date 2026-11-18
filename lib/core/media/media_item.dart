enum MediaKind { audio, video }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.path,
    required this.kind,
    this.artist,
    this.album,
    this.durationMs = 0,
    this.sizeBytes = 0,
    this.dateAdded = 0,
  });

  final String id;
  final String title;
  final String path;
  final MediaKind kind;
  final String? artist;
  final String? album;
  final int durationMs;
  final int sizeBytes;
  final int dateAdded;

  factory MediaItem.fromMap(Map<Object?, Object?> map) => MediaItem(
        id: map['id'] as String,
        title: map['title'] as String? ?? 'Unknown title',
        path: map['path'] as String,
        kind: map['type'] == 'video' ? MediaKind.video : MediaKind.audio,
        artist: map['artist'] as String?,
        album: map['album'] as String?,
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        dateAdded: (map['dateAdded'] as num?)?.toInt() ?? 0,
      );
}
