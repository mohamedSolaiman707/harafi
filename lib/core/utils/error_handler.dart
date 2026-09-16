import 'package:flutter/material.dart';

class AppErrorHandler {
  static String translate(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('network') || message.contains('socketexception') || message.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت، تأكد من تشغيل الواي فاي أو البيانات 📶';
    }
    if (message.contains('invalid-password') || message.contains('invalid login credentials') || message.contains('invalid_credentials')) {
      return 'كلمة المرور غير صحيحة، جرب مرة أخرى 🔑';
    }
    if (message.contains('user-not-found') || message.contains('user not found')) {
      return 'هذا الرقم غير مسجل لدينا، تأكد من الرقم أو أنشئ حساباً جديداً 📱';
    }
    if (message.contains('already-exists') ||
        message.contains('already_exists') ||
        message.contains('unique_violation') ||
        message.contains('already registered') ||
        message.contains('user_already_exists') ||
        message.contains('user already exists') ||
        message.contains('duplicate key')) {
      return 'هذا الهاتف مسجل بالفعل في النظام، جرب تسجيل الدخول ⚠️';
    }
    if (message.contains('timeout')) {
      return 'السيرفر استغرق وقتاً طويلاً للرد، حاول مرة أخرى ⏱️';
    }
    if (message.contains('jwt expired') || message.contains('401') || message.contains('invalid token')) {
      return 'انتهت جلستك، يرجى تسجيل الخروج والدخول مرة أخرى للأمان 🔒';
    }
    if (message.contains('row-level security') || message.contains('rls') || message.contains('permission denied')) {
      return 'خطأ في صلاحيات الحساب، يرجى المحاولة لاحقاً 🔒';
    }

    // إظهار نص الخطأ الحقيقي للمطور والعميل بدلاً من الإخفاء العام
    if (error is String && error.isNotEmpty) {
      return error;
    }

    return 'عذراً، حدث خطأ غير متوقع ($error). جرب مرة أخرى 🛠️';
  }

  static void showSnackBar(BuildContext context, Object error) {
    final translatedMessage = translate(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          translatedMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
