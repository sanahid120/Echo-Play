import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import 'core/media/media_item.dart';
import 'core/media/media_scanner.dart';

const _violet = Color(0xFF9A7BFF);
const _background = Color(0xFF101014);

void main() => runApp(const EchoPlayApp());

class EchoPlayApp extends StatelessWidget {
  const EchoPlayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EchoPlay',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _violet,
            brightness: Brightness.dark,
            surface: const Color(0xFF1A1A21),
          ),
          useMaterial3: true,
        ),
        home: const PlayerShell(),
      );
}

class PlayerShell extends StatefulWidget {
  const PlayerShell({super.key});

  @override
  State<PlayerShell> createState() => _PlayerShellState();
}

class _PlayerShellState extends State<PlayerShell> {
  final _scanner = MediaScanner();
  final _audio = AudioPlayer();
  final _search = TextEditingController();
  Timer? _searchDebounce;
  List<MediaItem> _items = [];
  MediaItem? _current;
  String _query = '';
  String _filter = 'all';
  int _destination = 0;
  int _scannedCount = 0;
  int _lastPublishedScanCount = 0;
  bool _loading = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
      _scannedCount = 0;
      _lastPublishedScanCount = 0;
    });
    try {
      final sdk = await _scanner.androidSdkInt;
      var kind = 'all';
      final permissions = await _scanner.requestMediaAccess();
      final hasAudio = permissions['audio'] ?? false;
      final hasVideo = permissions['video'] ?? false;
      if (!hasAudio && !hasVideo) {
        throw Exception('Allow audio or video access to scan this device.');
      }
      if (sdk >= 33) {
        if (!hasAudio) kind = 'video';
        if (!hasVideo) kind = 'audio';
      }
      final items = await _scanner.scan(
        kind: kind,
        onProgress: (count) {
          if (count - _lastPublishedScanCount < 1000) return;
          _lastPublishedScanCount = count;
          if (mounted) setState(() => _scannedCount = count);
        },
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _scannedCount = items.length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playAudio(MediaItem item) async {
    try {
      await _audio.setFilePath(item.path);
      await _audio.play();
      if (mounted) setState(() => _current = item);
    } catch (error) {
      if (mounted) _message('Could not play this file: $error');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchDebounce?.cancel();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((item) {
      final modeMatches = _filter == 'all' ||
          (_filter == 'audio' && item.kind == MediaKind.audio) ||
          (_filter == 'video' && item.kind == MediaKind.video);
      return modeMatches &&
          (_query.isEmpty ||
              '${item.title} ${item.artist ?? ''} ${item.album ?? ''} ${item.path}'
                  .toLowerCase()
                  .contains(_query));
    }).toList();
    final audioCount = _items.where((item) => item.kind == MediaKind.audio).length;
    final videoCount = _items.length - audioCount;

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.graphic_eq_rounded, color: _violet),
          SizedBox(width: 10),
          Text('EchoPlay', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Scan device media',
            onPressed: _loading ? null : _scan,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search your device library',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          _searchDebounce?.cancel();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: const Color(0xFF1A1A21),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_destination == 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 16),
              child: Row(children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'LOCAL SONGS',
                    count: audioCount,
                    icon: Icons.music_note_rounded,
                    tint: _violet,
                    onTap: () => setState(() {
                      _filter = 'audio';
                      _destination = 1;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'LOCAL VIDEOS',
                    count: videoCount,
                    icon: Icons.movie_rounded,
                    tint: const Color(0xFF51D6D0),
                    onTap: () => setState(() {
                      _filter = 'video';
                      _destination = 2;
                    }),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Expanded(
                  child: Text('On this device',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                if (_items.isNotEmpty)
                  Text('${_items.length} files',
                      style: TextStyle(color: Colors.white.withValues(alpha: .55))),
              ]),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _destination == 1 ? 'Music' : _destination == 2 ? 'Videos' : 'Library',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${visible.length} files',
                    style: TextStyle(color: Colors.white.withValues(alpha: .55))),
              ]),
            ),
          Expanded(child: _libraryBody(visible)),
        ]),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_current != null) _MiniPlayer(item: _current!, player: _audio),
        NavigationBar(
          selectedIndex: _destination,
          onDestinationSelected: (index) => setState(() {
            _destination = index;
            _filter = switch (index) { 1 => 'audio', 2 => 'video', _ => 'all' };
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note_rounded), label: 'Music'),
            NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie_rounded), label: 'Videos'),
            NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'Library'),
          ],
        ),
      ]),
    );
  }

  Widget _libraryBody(List<MediaItem> visible) {
    if (_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: _violet),
          const SizedBox(height: 14),
          Text(_scannedCount == 0
              ? 'Scanning local media…'
              : 'Scanning local media · $_scannedCount found'),
        ]),
      );
    }
    if (_error != null) {
      return _EmptyState(
        icon: Icons.folder_off_outlined,
        title: 'Media access needed',
        detail: _error!,
        button: 'Try again',
        onPressed: _scan,
      );
    }
    if (_items.isEmpty) {
      return _EmptyState(
        icon: Icons.library_music_outlined,
        title: 'Your library starts here',
        detail: 'Scan this device to find music and videos stored locally.',
        button: 'Scan device',
        onPressed: _scan,
      );
    }
    if (visible.isEmpty) {
      return const Center(child: Text('No matching local media found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 3),
      itemBuilder: (context, index) {
        final item = visible[index];
        return _MediaRow(
          item: item,
          onTap: () => item.kind == MediaKind.audio
              ? _playAudio(item)
              : Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => LocalVideoScreen(item: item),
                  )),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.count, required this.icon, required this.tint, required this.onTap});
  final String label;
  final int count;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF1B1B22),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: tint),
              const SizedBox(height: 14),
              Text('$count', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10, letterSpacing: 1.1, color: Colors.white.withValues(alpha: .55))),
            ]),
          ),
        ),
      );
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({required this.item, required this.onTap});
  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.kind == MediaKind.video;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isVideo ? const Color(0xFF123634) : const Color(0xFF29213D),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
            color: isVideo ? const Color(0xFF51D6D0) : _violet),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        isVideo ? item.path.split(Platform.pathSeparator).skip(3).join(' / ') : (item.artist ?? item.album ?? item.path.split(Platform.pathSeparator).last),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(_formatDuration(item.durationMs), style: const TextStyle(fontSize: 12, color: Colors.white54)),
      onTap: onTap,
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.item, required this.player});
  final MediaItem item;
  final AudioPlayer player;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 5),
        padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
        decoration: BoxDecoration(color: const Color(0xFF26222F), borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          const Icon(Icons.music_note_rounded, color: _violet),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(item.artist ?? 'On this device', style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ])),
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton(
                onPressed: () => playing ? player.pause() : player.play(),
                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              );
            },
          ),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail, required this.button, required this.onPressed});
  final IconData icon;
  final String title;
  final String detail;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 54, color: _violet),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.folder_open_rounded), label: Text(button)),
          ]),
        ),
      );
}

class LocalVideoScreen extends StatefulWidget {
  const LocalVideoScreen({super.key, required this.item});
  final MediaItem item;

  @override
  State<LocalVideoScreen> createState() => _LocalVideoScreenState();
}

class _LocalVideoScreenState extends State<LocalVideoScreen> {
  late final VideoPlayerController _controller = VideoPlayerController.file(File(widget.item.path));
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
      _controller.play();
    }).catchError((Object error) {
      if (mounted) setState(() => _error = 'This video could not be opened. It may be missing or use an unsupported codec.');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        backgroundColor: Colors.black,
        body: Center(
          child: _error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
              : !_controller.value.isInitialized
                  ? const CircularProgressIndicator(color: _violet)
                  : AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(alignment: Alignment.bottomCenter, children: [
                        VideoPlayer(_controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: _violet)),
                        Center(
                          child: IconButton.filledTonal(
                            iconSize: 38,
                            onPressed: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
                            icon: Icon(_controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          ),
                        ),
                      ]),
                    ),
        ),
      );
}

String _formatDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
