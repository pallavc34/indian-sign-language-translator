import 'package:material_ui/material_ui.dart';

class ZoomScreen extends StatelessWidget {
  final String imageName;
  ZoomScreen({required this.imageName});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Color(0x33000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            child: Image.asset(
              imageName,
              fit: BoxFit.fitWidth,
            ),
            width: size.width,
            height: size.height,
          ),
        ),
      ),
    );
  }
}
