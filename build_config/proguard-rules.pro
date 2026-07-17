# ProGuard/R8 rules for Abtin Navigator — کاهش حجم و حفظ کلاس‌های ضروری.

# Flutter core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# geolocator / sensors / permission_handler
-keep class com.baseflow.** { *; }

# sqlite / sqlcipher / drift
-keep class net.sqlcipher.** { *; }
-keep class com.tekartik.** { *; }
-dontwarn net.sqlcipher.**

# flutter_tts
-keep class com.tundralabs.fluttertts.** { *; }

# حذف لاگ‌ها در نسخه‌ی نهایی (کاهش حجم و مصرف)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
