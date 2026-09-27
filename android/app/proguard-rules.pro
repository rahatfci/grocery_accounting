# --- Firebase ---
# Components are discovered from the manifest and instantiated via their no-arg
# constructor; R8 full mode removes those constructors without this rule.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# --- ML Kit text recognition ---
# google_mlkit_text_recognition references the Chinese, Devanagari, Japanese and
# Korean recognizer options, but those ship in optional artifacts this app does
# not include (it only uses the default Latin script). R8 fails on the missing
# classes unless told they are expected to be absent.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
