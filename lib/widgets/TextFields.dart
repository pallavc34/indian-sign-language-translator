import 'package:material_ui/material_ui.dart';

class TextFields extends StatelessWidget {
  final Function() onPressed;
  final String text;

  const TextFields({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.all(10.0),
        child: Text(
          text,
          style: TextStyle(fontSize: 25.0),
        ),
      ),
    );
  }
}
