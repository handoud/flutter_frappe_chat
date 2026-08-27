import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/chat_theme.dart';

/// Inline player for a voice note.
class ChatAudioPlayer extends StatefulWidget {
  /// Absolute URL of the audio file.
  final String audioUrl;

  /// Whether the current user sent it.
  final bool isMe;

  /// Colours and shapes.
  final FrappeChatTheme theme;

  /// Headers used to fetch the file.
  ///
  /// flutter_sound cannot send headers itself, so when these are non-empty the
  /// file is downloaded to a temporary file first and played from there. That
  /// is what makes private attachments (`/private/files/...`) playable.
  final Map<String, String> headers;

  const ChatAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.theme = const FrappeChatTheme(),
    this.headers = const {},
  });

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  StreamSubscription<PlaybackDisposition>? _progress;
  bool _ready = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 200));
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    unawaited(_progress?.cancel());
    unawaited(_player.closePlayer());
    super.dispose();
  }

  /// Resolves what flutter_sound should open.
  ///
  /// A public URL is streamed directly. A private one needs credentials that
  /// flutter_sound cannot attach, so it is fetched here and cached on disk.
  Future<String> _resolveSource() async {
    if (widget.headers.isEmpty) return widget.audioUrl;

    final tempDir = await getTemporaryDirectory();
    final name = Uri.parse(widget.audioUrl).pathSegments.last;
    final file = File('${tempDir.path}/frappe_chat_$name');

    if (!await file.exists()) {
      final response =
          await http.get(Uri.parse(widget.audioUrl), headers: widget.headers);
      if (response.statusCode != 200) {
        throw Exception('Could not download audio (${response.statusCode})');
      }
      await file.writeAsBytes(response.bodyBytes, flush: true);
    }

    return file.path;
  }

  Future<void> _play() async {
    if (!_ready) return;

    if (_isPaused) {
      await _player.resumePlayer();
      if (mounted) setState(() => _isPaused = false);
      return;
    }

    unawaited(_progress?.cancel());
    _progress = _player.onProgress?.listen((event) {
      if (!mounted) return;
      setState(() {
        _position = event.position;
        _duration = event.duration;
      });
    });

    try {
      final source = await _resolveSource();

      await _player.startPlayer(
        fromURI: source,
        whenFinished: () {
          if (!mounted) return;
          setState(() {
            _isPlaying = false;
            _isPaused = false;
            _position = Duration.zero;
          });
        },
      );
    } catch (e) {
      debugPrint('flutter_frappe_chat: could not play audio — $e');
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> _pause() async {
    await _player.pausePlayer();
    if (mounted) setState(() => _isPaused = true);
  }

  Future<void> _seek(double milliseconds) =>
      _player.seekToPlayer(Duration(milliseconds: milliseconds.round()));

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final maxMs = _duration.inMilliseconds.toDouble();
    final valueMs = _position.inMilliseconds.toDouble().clamp(0, maxMs);
    final showPause = _isPlaying && !_isPaused;

    return SizedBox(
      width: 240,
      child: Row(
        children: [
          IconButton(
            tooltip: showPause ? 'Pause' : 'Play',
            icon: Icon(
              showPause
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: theme.accent,
              size: 34,
            ),
            onPressed: _ready ? (showPause ? _pause : _play) : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    activeTrackColor: theme.accent,
                    thumbColor: theme.accent,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs > 0 ? maxMs : 1,
                    value: maxMs > 0 ? valueMs.toDouble() : 0,
                    onChanged: maxMs > 0 ? _seek : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _format(_position),
                        style: TextStyle(fontSize: 10, color: theme.metaColor),
                      ),
                      Text(
                        _format(_duration),
                        style: TextStyle(fontSize: 10, color: theme.metaColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
