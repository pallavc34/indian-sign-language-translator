import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class TranslationDisplayScreen extends StatefulWidget {
  final String speech;

  const TranslationDisplayScreen({super.key, required this.speech});

  @override
  State<TranslationDisplayScreen> createState() =>
      _TranslationDisplayScreenState();
}

class _TranslationDisplayScreenState extends State<TranslationDisplayScreen> {
  late List<String> _characters;
  int _currentIndex = 0;
  Timer? _timer;
  bool _isPlaying = true;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _processSpeech();
    _startAnimation();
  }

  void _processSpeech() {
    _characters = widget.speech.replaceAll(' ', '').split('');
  }

  void _startAnimation() {
    _timer?.cancel();
    if (_characters.isEmpty) return;

    _timer = Timer.periodic(Duration(milliseconds: (1500 ~/ _speed)), (timer) {
      if (_currentIndex < _characters.length - 1) {
        setState(() => _currentIndex++);
      } else {
        _timer?.cancel();
        setState(() => _isPlaying = false);
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_currentIndex >= _characters.length - 1) {
          _currentIndex = 0;
        }
        _startAnimation();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _replay() {
    setState(() {
      _currentIndex = 0;
      _isPlaying = true;
    });
    _startAnimation();
  }

  void _changeSpeed() {
    setState(() {
      if (_speed == 1.0)
        _speed = 1.5;
      else if (_speed == 1.5)
        _speed = 2.0;
      else if (_speed == 2.0)
        _speed = 0.5;
      else
        _speed = 1.0;

      if (_isPlaying) {
        _startAnimation();
      }
    });
  }

  String _getImageName(String char) {
    if (char.isEmpty) return 'spinningwheel.gif';
    final lowerChar = char.toLowerCase();
    if (RegExp(r'[a-z]').hasMatch(lowerChar)) {
      return '$lowerChar.png';
    }
    return 'spinningwheel.gif';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.speech,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: _characters.isEmpty
                      ? const Text("No translatable text")
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return FadeTransition(
                                opacity: animation, child: child);
                          },
                          child: Card(
                            key: ValueKey<int>(_currentIndex),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            clipBehavior: Clip.antiAlias,
                            child: Container(
                              constraints: const BoxConstraints(
                                  maxWidth: 400, maxHeight: 400),
                              width: double.infinity,
                              color: Colors.white,
                              padding: const EdgeInsets.all(32),
                              child: Image.asset(
                                'images/${_getImageName(_characters[_currentIndex])}',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                        FluentIcons.error_circle_24_regular,
                                        size: 64),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (_characters.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_characters.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(FluentIcons.arrow_reply_24_regular),
                    iconSize: 32,
                    onPressed: _replay,
                    tooltip: 'Replay',
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton.large(
                    onPressed: _togglePlayPause,
                    elevation: 0,
                    child: Icon(
                      _isPlaying
                          ? FluentIcons.pause_24_filled
                          : FluentIcons.play_24_filled,
                    ),
                  ),
                  const SizedBox(width: 24),
                  ActionChip(
                    label: Text('${_speed}x'),
                    onPressed: _changeSpeed,
                    tooltip: 'Speed',
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
