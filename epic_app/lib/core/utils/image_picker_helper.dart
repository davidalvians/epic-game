import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  final String name;
  final Uint8List bytes;

  PickedImage(this.name, this.bytes);
}

class ImagePickerHelper {
  static Future<PickedImage?> pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      return PickedImage(pickedFile.name, bytes);
    }
    return null;
  }
}
