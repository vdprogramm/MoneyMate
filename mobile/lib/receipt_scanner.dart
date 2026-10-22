import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'receipt_parser.dart';

/// Image recognition happens locally; no invoice images sent to the backend.
Future<ReceiptData?> scanReceipt(ImageSource source) async {
  final picked=await ImagePicker().pickImage(source:source,maxWidth:2200,imageQuality:90);
  if (picked==null) return null;
  final recognizer=TextRecognizer(script:TextRecognitionScript.latin);
  try {
    final result=await recognizer.processImage(InputImage.fromFilePath(picked.path));
    return parseReceiptText(result.text);
  } finally {
    await recognizer.close();
  }
}
