import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  /// رفع صورة (سواء للملف الشخصي أو معرض الأعمال)
  Future<String?> uploadImage({
    required XFile image,
    required String path, // المجلد الوجهة (avatars أو portfolios)
    required String fileName,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fullPath = '$path/$fileName.$fileExt';

      // رفع الصورة بنظام الـ Binary (أفضل للويب والموبايل)
      await _client.storage.from('app_images').uploadBinary(
            fullPath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return _client.storage.from('app_images').getPublicUrl(fullPath);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.sublist(uri.pathSegments.indexOf('app_images') + 1).join('/');
      await _client.storage.from('app_images').remove([path]);
    } catch (e) {
      // فشل الحذف لا يعطل التطبيق
    }
  }
}
