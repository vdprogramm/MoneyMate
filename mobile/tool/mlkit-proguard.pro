# The text-recognition Flutter plugin contains code paths for these optional
# language add-ons. MoneyMate instantiates ONLY TextRecognitionScript.latin;
# Latin recognizer classes come from the plugin's default Android dependency.
# Do not suppress missing classes for the Latin recognizer or other libraries.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
