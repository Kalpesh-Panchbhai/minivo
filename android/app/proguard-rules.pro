# ─── Flutter ────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase (Core / Analytics / Crashlytics) ──────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Crashlytics requires line numbers + source info for usable stack traces.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ─── AdMob / Google Mobile Ads ──────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.ads.**

# ─── Play Core (deferred components — referenced by Flutter Play Store split) ─
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ─── Kotlin reflection / metadata ───────────────────────────────────────
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlin.**

# ─── Generic safety ─────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
