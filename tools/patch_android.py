"""Настраивает сгенерированный Android-проект: интернет, камера (QR), голос (TTS), название приложения."""
import pathlib
import re

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")
if "android.permission.INTERNET" not in text:
    text = re.sub(r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>', text, count=1)
if "android.permission.CAMERA" not in text:
    text = re.sub(r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="android.permission.CAMERA"/>', text, count=1)
if "TTS_SERVICE" not in text:
    text = text.replace(
        "</manifest>",
        '    <queries>\n        <intent>\n            <action android:name="android.intent.action.TTS_SERVICE"/>\n'
        "        </intent>\n    </queries>\n</manifest>",
    )
text = re.sub(r'android:label="[^"]*"', 'android:label="Dota Draft"', text, count=1)
manifest.write_text(text, encoding="utf-8")
print(text)
