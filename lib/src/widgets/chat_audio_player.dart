import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

class ChatAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const ChatAudioPlayer({
    Key? key,
    required this.audioUrl,
    required this.isMe,
  }) : super(key: key);

  @override
  _ChatAudioPlayerState createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player!.openPlayer();
    _player!.setSubscriptionDuration(const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _player!.closePlayer();
    _playerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _play() async {
    if (_isPaused) {
      await _player!.resumePlayer();
    } else {
      await _player!.startPlayer(
          fromURI: widget.audioUrl,
          codec: Codec.aacADTS, // Try default or auto detection
          whenFinished: () {
            setState(() {
              _isPlaying = false;
              _isPaused = false;
              _position = Duration.zero;
            });
          });
      _playerSubscription = _player!.onProgress!.listen((e) {
        setState(() {
          _position = e.position;
          _duration = e.duration;
        });
      });
    }

    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  Future<void> _pause() async {
    await _player!.pausePlayer();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
    });
  }

  Future<void> _seek(double value) async {
    await _player!.seekToPlayer(Duration(milliseconds: value.toInt()));
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.black54 : Colors.grey[800];
    final activeColor = widget.isMe ? const Color(0xFF075E54) : Colors.blue;

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: activeColor,
              size: 36,
            ),
            onPressed: _isPlaying ? _pause : _play,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 4,
                    activeTrackColor: activeColor,
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: activeColor,
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    value: (_position.inMilliseconds.toDouble() <=
                                _duration.inMilliseconds.toDouble() &&
                            _position.inMilliseconds.toDouble() >= 0)
                        ? _position.inMilliseconds.toDouble()
                        : 0,
                    onChanged: (value) {
                      _seek(value);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(fontSize: 10, color: color),
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
