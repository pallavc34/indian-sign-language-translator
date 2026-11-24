import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// A local WebGL scene. The model is sent in bounded chunks because WebKit
/// and Android WebView have different file-origin and message size limits.
class SaniyaStage extends StatefulWidget {
  const SaniyaStage({
    super.key,
    required this.onReady,
    required this.onLetter,
    required this.onDone,
    this.topInset = 0,
  });

  final ValueChanged<bool> onReady;
  final void Function(int id, int word, int index) onLetter;
  final ValueChanged<int> onDone;

  /// Space kept clear at the top so the mode switch can sit above the
  /// platform view and receive taps.
  final double topInset;

  @override
  State<SaniyaStage> createState() => SaniyaStageState();
}

class SaniyaStageState extends State<SaniyaStage> {
  WebViewController? _viewer;
  bool _ready = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> _open() async {
    final generation = ++_generation;
    try {
      final viewer = WebViewController();
      await viewer.setJavaScriptMode(JavaScriptMode.unrestricted);
      await viewer.setBackgroundColor(const Color(0xffe1e8e6));
      await viewer.addJavaScriptChannel(
        'SaniyaBridge',
        onMessageReceived: (message) => _receive(generation, message.message),
      );
      final script = await rootBundle.loadString('assets/saniya/viewer.js');
      if (!_current(generation)) return;
      setState(() {
        _viewer = viewer;
        _ready = false;
        _failed = false;
      });
      await viewer.loadHtmlString(
        '''
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>*{margin:0}html,body{height:100%;overflow:hidden}body{background:radial-gradient(ellipse at 50% 34%,#f3f4ee,#d4dfdc)}canvas{display:block}</style></head>
<body><script>window.onerror=function(message){SaniyaBridge.postMessage(JSON.stringify({type:'error',message:String(message)}))};</script>
<script>try { ${script.replaceAll('</script', r'<\/script')} } catch(e) { SaniyaBridge.postMessage(JSON.stringify({type:'error',message:String(e)+' '+e.stack})); }</script></body></html>''',
      );
    } catch (error) {
      _failure(generation, error);
    }
  }

  Future<void> _receive(int generation, String message) async {
    if (!_current(generation)) return;
    try {
      final event = jsonDecode(message) as Map<String, dynamic>;
      switch (event['type']) {
        case 'boot':
          final data = await rootBundle.load(
            'avatar/likeness/ISL_Avatar_Likeness.glb',
          );
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          const chunk = 512 * 1024;
          for (var start = 0; start < bytes.length; start += chunk) {
            if (!_current(generation)) return;
            final end = math.min(start + chunk, bytes.length);
            final encoded = base64Encode(
              Uint8List.sublistView(bytes, start, end),
            );
            await _viewer!.runJavaScript('Saniya.chunk("$encoded")');
          }
          if (_current(generation))
            await _viewer!.runJavaScript('void Saniya.load()');
        case 'ready':
          setState(() => _ready = true);
          widget.onReady(true);
        case 'letter':
          widget.onLetter(
            event['id'] as int,
            event['word'] as int,
            event['index'] as int,
          );
        case 'done':
          widget.onDone(event['id'] as int);
        case 'error':
          _failure(generation, event['message']);
      }
    } catch (error) {
      _failure(generation, error);
    }
  }

  void _failure(int generation, Object? error) {
    if (!_current(generation)) return;
    debugPrint('Saniya viewer: $error');
    ++_generation;
    if (mounted) {
      setState(() {
        _failed = true;
        _ready = false;
      });
    }
    // The first failure can happen synchronously inside initState, so the
    // parent must not be rebuilt while the tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(false);
    });
  }

  Future<void> play(List<String> words, int id) async {
    if (!_ready) return;
    final generation = _generation;
    try {
      await _viewer!.runJavaScript('Saniya.play(${jsonEncode(words)},$id)');
    } catch (error) {
      _failure(generation, error);
    }
  }

  /// Hybrid composition renders the WebView into a Flutter texture, so the
  /// switch and other controls can sit above it and still receive taps.
  Widget _webView() {
    final controller = _viewer!;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xffe1e8e6)),
        if (_viewer != null && !_failed)
          Positioned(
            top: widget.topInset,
            left: 0,
            right: 0,
            bottom: 0,
            child: Semantics(
              label: 'Saniya, your signing avatar',
              image: true,
              child: IgnorePointer(child: _webView()),
            ),
          ),
        if (!_ready) ...[
          Image.asset(
            'assets/saniya/welcome.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            semanticLabel: 'Saniya in her welcome pose',
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _failed
                  ? FilledButton.tonal(
                      onPressed: _open,
                      child: const Text('Reload Saniya'),
                    )
                  : const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Loading Saniya',
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
