class AdminValidators {
  static String? techName(String? v) {
    if (v == null || v.trim().isEmpty) return 'اسم الفني مطلوب';
    if (v.trim().length < 3) return 'الاسم قصير جداً';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'الرقم مطلوب';
    final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 10) return 'رقم غير صحيح';
    return null;
  }

  static String? visitPrice(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v);
    if (n == null || n < 0) return 'سعر غير صحيح';
    return null;
  }

  static String? orderDescription(String? v) {
    if (v == null || v.trim().isEmpty) return 'وصف المشكلة مطلوب';
    if (v.trim().length < 10) return 'وصف المشكلة قصير جداً';
    return null;
  }
}
