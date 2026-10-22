"""Configure generated Flutter Android runner for HTTPS and on-device Latin OCR.

Run after flutter create . --platforms=android --project-name=moneymate.
Only Linux CI currently builds Android; generated platform directories are not committed.
"""
from pathlib import Path
import re

app = Path("android/app")
manifest = app / "src/main/AndroidManifest.xml"
if not manifest.is_file():
    raise SystemExit("Run flutter create . --platforms=android first")

text = manifest.read_text(encoding="utf-8")
if 'android.permission.INTERNET' not in text:
    text = text.replace(
        "<application",
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )
text = text.replace('android:label="moneymate"', 'android:label="MoneyMate"')
manifest.write_text(text, encoding="utf-8")

# The plugin references optional Chinese, Japanese, Korean and Devanagari ML Kit
# recognizers. MoneyMate only initializes the bundled Latin recognizer, so R8
# should not fail on references to optional, deliberately absent libraries.
rules = Path("tool/mlkit-proguard.pro")
if not rules.is_file():
    raise SystemExit("Missing checked-in tool/mlkit-proguard.pro")
proguard_path = app / "proguard-rules.pro"
with proguard_path.open("a", encoding="utf-8") as out:
    existing = proguard_path.read_text(encoding="utf-8")
    for rule in rules.read_text(encoding="utf-8").splitlines():
        if rule.startswith("-dontwarn ") and rule not in existing:
            out.write(rule + "\n")

# flutter create currently generates build.gradle.kts. Handle Groovy as well.
gradle_kts = app / "build.gradle.kts"
gradle_groovy = app / "build.gradle"
gradle = gradle_kts if gradle_kts.is_file() else gradle_groovy
if not gradle.is_file():
    raise SystemExit("Missing generated android/app/build.gradle(.kts)")
source = gradle.read_text(encoding="utf-8")
if "proguard-rules.pro" not in source:
    match = re.search(r"(?m)^([ \t]*)release\s*\{[ \t]*$", source)
    if not match:
        raise SystemExit("Unable to find Android buildTypes.release block")
    indent = match.group(1) + "    "
    if gradle.suffix == ".kts":
        rule = ('proguardFiles(getDefaultProguardFile('
                '"proguard-android-optimize.txt"), "proguard-rules.pro")')
    else:
        rule = ("proguardFiles getDefaultProguardFile("
                "'proguard-android-optimize.txt'), 'proguard-rules.pro'")
    offset = match.end()
    source = source[:offset] + "\n" + indent + rule + source[offset:]
    gradle.write_text(source, encoding="utf-8")
print(f"Configured Internet permission and Latin ML Kit R8 rules in {gradle}")
