"""Configure AndroidManifest.xml after `flutter create .` (no localhost needed)."""
from pathlib import Path
manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    raise SystemExit('Run flutter create . --platforms=android first')
text = manifest.read_text()
if 'android.permission.INTERNET' not in text:
    text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
text = text.replace('android:label="moneymate"', 'android:label="MoneyMate"')
manifest.write_text(text)
print('Android Internet permission configured')
