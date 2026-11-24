import 'package:material_ui/material_ui.dart';

class MyImagesWidget extends StatelessWidget {
  final Function() onImageClick;
  final Function() onLongPress;
  final AssetImage image;
  MyImagesWidget(
      {required this.image,
      required this.onImageClick,
      required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onImageClick,
        onLongPress: onLongPress,
        child: Image(
          image: image,
        ),
      ),
    );
  }
}
