import 'package:material_ui/material_ui.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:sign_language_translator/screens/ZoomScreen.dart';

class SignsToSpeechTranslator extends StatefulWidget {
  const SignsToSpeechTranslator({super.key});

  @override
  _SignsToSpeechTranslatorState createState() =>
      _SignsToSpeechTranslatorState();
}

class _SignsToSpeechTranslatorState extends State<SignsToSpeechTranslator> {
  String theText = "";
  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    initTts();
  }

  void initTts() {
    flutterTts = FlutterTts();
  }

  void _speak() async {
    if (theText.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter some text');
      return;
    }
    await flutterTts.speak(theText);
  }

  void _addChar(String char) {
    setState(() {
      theText += char;
    });
  }

  void _backspace() {
    if (theText.isNotEmpty) {
      setState(() {
        theText = theText.substring(0, theText.length - 1);
      });
    }
  }

  void _clear() {
    setState(() {
      theText = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theText.isEmpty ? "Tap signs to build words..." : theText,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: theText.isEmpty
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: _clear,
                      icon: const Icon(FluentIcons.delete_24_regular),
                      tooltip: 'Clear Text',
                    ),
                    IconButton(
                      onPressed: _backspace,
                      icon: const Icon(FluentIcons.backspace_24_regular),
                      tooltip: 'Backspace',
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: _speak,
                      icon: const Icon(FluentIcons.speaker_2_24_regular),
                      label: const Text("Speak"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 1.0,
              ),
              itemCount: 27, // A-Z + Space
              itemBuilder: (context, index) {
                if (index == 26) {
                  return Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _addChar(" "),
                      child: const Center(
                        child: Text(
                          "SPACE",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }

                String letter = String.fromCharCode(97 + index); // a-z
                String imagePath = 'images/$letter.png';

                return Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _addChar(letter),
                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ZoomScreen(imageName: imagePath),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.asset(imagePath, fit: BoxFit.contain),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              letter.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
