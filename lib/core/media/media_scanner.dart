import 'package:flutter/services.dart';

import 'media_item.dart';

class MediaScanner {
  static const _channel = MethodChannel('echoplay/local_media');
  static const _pageSize = 200;

  Future<int> get androidSdkInt async =>
      await _channel.invokeMethod<int>('sdkInt') ?? 0;

  Future<Map<String, bool>> requestMediaAccess() async {
    final result = await _channel.invokeMapMethod<String, bool>('requestMediaAccess');
    return result ?? const {};
  }

  Future<List<MediaItem>> scan({
    String kind = 'all',
    void Function(int discoveredCount)? onProgress,
  }) async {
    final items = <MediaItem>[];
    final kinds = kind == 'all' ? const ['audio', 'video'] : [kind];

    for (final mediaKind in kinds) {
      var offset = 0;
      while (true) {
        final page = await _channel.invokeListMethod<Object?>('scanPage', {
          'kind': mediaKind,
          'offset': offset,
          'limit': _pageSize,
        });
        final rawItems = page ?? const <Object?>[];
        if (rawItems.isEmpty) break;

        items.addAll(rawItems
            .whereType<Map<Object?, Object?>>()
            .map(MediaItem.fromMap));
        offset += rawItems.length;
        onProgress?.call(items.length);

        if (rawItems.length < _pageSize) break;
        // Yield between pages so Flutter can render and handle input.
        await Future<void>.delayed(Duration.zero);
      }
    }
    return List.unmodifiable(items);
  }
}
