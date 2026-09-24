import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class FaceService {
  final ImagePicker _camera = ImagePicker();
  Future<String> capture() async {
    final image = await _camera.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (image == null) {
      throw const ApiException('ยกเลิกการถ่ายภาพใบหน้า');
    }
    final bytes = await image.readAsBytes();
    if (bytes.length > 4194304) {
      throw const ApiException('รูปใบหน้าต้องไม่เกิน 4 MB');
    }
    return base64Encode(bytes);
  }
}
