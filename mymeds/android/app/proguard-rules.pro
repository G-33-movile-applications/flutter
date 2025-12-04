# Keep ML Kit Text Recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Keep optional language-specific text recognizers
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep Google Play Services classes used by ML Kit
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep generic signatures for flutter_local_notifications and TypeToken
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Keep flutter_local_notifications classes
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Preserve TypeToken generic information
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep all classes that use TypeToken
-keepclassmembers class * {
    *** *TypeToken*;
}

# Keep generic type information for serialization
-keepattributes Signature
-keep class * implements java.io.Serializable {
    *;
}
