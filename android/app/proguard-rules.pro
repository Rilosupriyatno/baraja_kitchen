#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Maps
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.common.** { *; }
-dontwarn com.google.android.common.**

# Squareup
-dontwarn com.squareup.okhttp.**
-dontwarn com.squareup.okio.**
-dontwarn javax.annotation.**
-keepnames class com.squareup.okhttp.** { *; }
-keep interface com.squareup.okhttp.** { *; }

# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Generic
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn javax.annotation.**
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class sun.misc.** { *; }
-keep class com.google.common.** { *; }

# Flutter Bluetooth Serial
-keep class io.github.edufolly.flutterbluetoothserial.** { *; }

# Play Core (Fix R8 missing class errors)
-dontwarn com.google.android.play.core.**
