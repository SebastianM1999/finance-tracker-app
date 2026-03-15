# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Flutter Play Store Split (not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
