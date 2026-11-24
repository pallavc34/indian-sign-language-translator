import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_language_translator/screens/TranslateScreen.dart';
import 'package:sign_language_translator/screens/SignsToSpeechTranslator.dart';
import 'package:sign_language_translator/widgets/ModeSwitch.dart';

const _repository = 'https://github.com/pallavc34/indian-sign-language-translator';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _speechToSigns = true;

  Future<void> _showAbout() async {
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saniya'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saniya is the 3D signing avatar in this app. She fingerspells '
                'Indian Sign Language one letter at a time.',
              ),
              const SizedBox(height: 10),
              const Text(
                'Speech to Signs turns what you say into signs. Signs to '
                'Speech turns the alphabet keyboard into spoken words.',
              ),
              const SizedBox(height: 14),
              const Text('The code is open source.'),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(_repository),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  _repository,
                  style: TextStyle(
                    color: colors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffe1e8e6),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ModeSwitch(
                    value: _speechToSigns,
                    onChanged: (value) =>
                        setState(() => _speechToSigns = value),
                  ),
                  IconButton(
                    tooltip: 'About Saniya',
                    icon: const Icon(Icons.info_outline),
                    onPressed: _showAbout,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _speechToSigns ? 0 : 1,
              sizing: StackFit.expand,
              children: const [TranslateScreen(), SignsToSpeechTranslator()],
            ),
          ),
        ],
      ),
    );
  }
}
