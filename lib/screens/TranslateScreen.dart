import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:sign_language_translator/widgets/SaniyaStage.dart';

List<String> fingerspellingWords(String text) =>
    RegExp(r'[a-z]+').allMatches(text.toLowerCase()).map((m) => m[0]!).toList();

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen>
    with WidgetsBindingObserver {
  final _stage = GlobalKey<SaniyaStageState>();
  final _text = TextEditingController();
  final _speech = SpeechToText();
  bool _ready = false, _capturing = false, _starting = false, _playing = false;
  int _utterance = 0, _playback = 0;
  Timer? _endOfSpeech;
  List<String> _words = [];
  static const phrases = [
    'Hello',
    'How are you?',
    'What is your name?',
    'Thank you',
    'Welcome',
    'Good morning',
    'Yes',
    'No',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_capturing) {
        _cancelSpeech();
        setState(() {});
      }
      if (_playing) _stopPlayback();
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _cancelSpeech() {
    ++_utterance;
    _endOfSpeech?.cancel();
    if (_capturing || _starting) {
      _capturing = _starting = false;
      unawaited(_speech.cancel());
    }
  }

  void _stopPlayback() {
    unawaited(_stage.currentState?.play([], ++_playback));
    setState(() => _playing = false);
  }

  void _sign(String text) {
    _cancelSpeech();
    _words = fingerspellingWords(text);
    FocusManager.instance.primaryFocus?.unfocus();
    if (_words.isEmpty) {
      _stopPlayback();
      _notice('Enter a word using A–Z');
      return;
    }
    setState(() => _playing = true);
    unawaited(_stage.currentState?.play(_words, ++_playback));
  }

  void _speechStatus(String status) {
    if (!mounted || !_capturing) return;
    if (status == SpeechToText.doneStatus) _finishUtterance();
    if (status == SpeechToText.notListeningStatus) _waitForFinalResult();
  }

  void _waitForFinalResult() {
    _endOfSpeech?.cancel();
    // Some recognizers stop the audio stream before delivering the final text.
    _endOfSpeech = Timer(const Duration(seconds: 3), _finishUtterance);
  }

  void _finishUtterance() {
    if (!mounted || !_capturing) return;
    _endOfSpeech?.cancel();
    _capturing = _starting = false;
    if (_text.text.trim().isEmpty) {
      setState(() {});
      _notice('No speech heard. Tap the mic to try again.');
    } else {
      _sign(_text.text);
    }
  }

  void _captureError(String message) {
    if (!mounted || !_capturing) return;
    ++_utterance;
    setState(() => _capturing = _starting = false);
    _notice(message);
  }

  Future<void> _microphone() async {
    if (_starting) return;
    if (_capturing) {
      _waitForFinalResult();
      try {
        await _speech.stop();
      } catch (_) {
        _finishUtterance();
      }
      return;
    }
    if (_playing) _stopPlayback();
    final session = ++_utterance;
    setState(() => _starting = _capturing = true);
    try {
      void onError(Object error) => _captureError(
        'Speech recognition stopped. Try the mic again or type a word.',
      );
      // The plugin is a singleton. Reattach callbacks when returning to this tab.
      _speech.statusListener = _speechStatus;
      _speech.errorListener = onError;
      final available = await _speech.initialize(
        onStatus: _speechStatus,
        onError: onError,
      );
      if (!mounted || session != _utterance) return;
      if (!available) {
        _captureError(
          'Speech unavailable. Check microphone and speech permissions, or type below.',
        );
        return;
      }
      _text.clear();
      setState(() {});
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!mounted || session != _utterance || !_capturing) return;
          _text.value = TextEditingValue(
            text: result.recognizedWords,
            selection: TextSelection.collapsed(
              offset: result.recognizedWords.length,
            ),
          );
          if (result.finalResult) _finishUtterance();
        },
      );
    } catch (_) {
      if (session == _utterance)
        _captureError('Could not start listening. Try again or type below.');
    } finally {
      if (mounted && session == _utterance) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelSpeech();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pill = BorderRadius.circular(999);
    final stage = SaniyaStage(
      key: _stage,
      topInset: 0,
      onReady: (value) {
        setState(() {
          _ready = value;
          if (!value) _playing = false;
        });
      },
      onLetter: (id, word, letter) {},
      onDone: (id) {
        if (id != _playback || !_playing) return;
        setState(() => _playing = false);
      },
    );
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: stage),
                if (_playing)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: IconButton.filledTonal(
                      tooltip: 'Stop signing',
                      icon: const Icon(Icons.stop_circle_outlined),
                      onPressed: _stopPlayback,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        readOnly: _capturing,
                        textInputAction: TextInputAction.go,
                        onSubmitted: _ready ? _sign : null,
                        decoration: InputDecoration(
                          hintText: 'Say or type a word',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: pill,
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: pill,
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: pill,
                            borderSide: BorderSide(
                              color: colors.primary,
                              width: 1.5,
                            ),
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Sign text',
                            icon: const Icon(Icons.play_arrow_rounded),
                            onPressed: _ready ? () => _sign(_text.text) : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconButton.filled(
                      tooltip: _capturing ? 'Finish listening' : 'Microphone',
                      onPressed: _ready && !_starting ? _microphone : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: _capturing ? colors.error : null,
                      ),
                      icon: Icon(_capturing ? Icons.stop : Icons.mic),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final phrase in phrases)
                        ActionChip(
                          label: Text(phrase),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(color: colors.outlineVariant),
                          onPressed: _ready
                              ? () {
                                  _text.text = phrase;
                                  _sign(phrase);
                                }
                              : null,
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
