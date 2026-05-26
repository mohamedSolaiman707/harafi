import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart'; // ستحتاج لإضافة حزمة mime في pubspec.yaml

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  /// رفع صورة (سواء للملف الشخصي أو معرض الأعمال)
  Future<String?> uploadImage({
    required XFile image,
    required String path,
    required String fileName,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      
      // تحديد نوع الملف (MIME Type) لتجنب مشاكل العرض
      final contentType = lookupMimeType(image.path, headerBytes: bytes) ?? 'image/jpeg';
      
      // الحصول على الامتداد بشكل آمن
      String fileExt = image.path.split('.').last.toLowerCase();
      if (fileExt.length > 4 || fileExt.isEmpty) {
        fileExt = contentType.split('/').last;
      }
      
      final fullPath = '$path/$fileName.$fileExt';

      print('جاري رفع الصورة إلى: $fullPath بنوع: $contentType');

      await _client.storage.from('app_images').uploadBinary(
            fullPath,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600', 
              upsert: true,
              contentType: contentType, // هام جداً لظهور الصورة
            ),
          );

      final url = _client.storage.from('app_images').getPublicUrl(fullPath);
      print('تم الرفع بنجاح! الرابط: $url');
      return url;
    } catch (e) {
      print('خطأ أثناء رفع الصورة: $e');
      return null;
    }
  }

  Future<void> deleteImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.sublist(uri.pathSegments.indexOf('app_images') + 1).join('/');
      await _client.storage.from('app_images').remove([path]);
    } catch (e) {
      print('فشل حذف الصورة: $e');
    }
  }
}
