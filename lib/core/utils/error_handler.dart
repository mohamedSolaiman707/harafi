import 'package:flutter/material.dart';

class AppErrorHandler {
  static String translate(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('network') || message.contains('socketexception') || message.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت، تأكد من تشغيل الواي فاي أو البيانات 📶';
    }
    if (message.contains('invalid-password') || message.contains('invalid login credentials')) {
      return 'كلمة المرور غير صحيحة، جرب مرة أخرى 🔑';
    }
    if (message.contains('user-not-found') || message.contains('user not found')) {
      return 'هذا الرقم غير مسجل لدينا، تأكد من الرقم أو أنشئ حساباً جديداً 📱';
    }
    if (message.contains('already-exists') || message.contains('unique_violation') || message.contains('already registered')) {
      return 'هذه البيانات مسجلة بالفعل في النظام ⚠️';
    }
    if (message.contains('timeout')) {
      return 'السيرفر استغرق وقتاً طويلاً للرد، حاول مرة أخرى ⏱️';
    }
    if (message.contains('jwt expired') || message.contains('401') || message.contains('invalid token')) {
      return 'انتهت جلستك، يرجى تسجيل الخروج والدخول مرة أخرى للأمان 🔒';
    }

    return 'عذراً، حدث خطأ غير متوقع. جرب مرة أخرى أو تواصل مع الدعم 🛠️';
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
