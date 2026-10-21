# Benim Marketim - R8 / ProGuard kuralları
# (android/app/build.gradle.kts: isMinifyEnabled = true)

# --- Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# --- OneSignal (push bildirimleri) ---
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# --- Meta / Facebook SDK (App Events) ---
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# --- Google Play Core (Flutter deferred components; uygulamada yoksa uyarıları bastır) ---
-dontwarn com.google.android.play.core.**

# --- Kotlin / coroutines ---
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# --- Genel gürültü ---
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn sun.misc.Unsafe

# Yığın izleri okunabilir kalsın
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
