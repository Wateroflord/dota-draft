"""Настраивает сгенерированный Android-проект: интернет, название приложения."""
import pathlib
import re

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")
if "android.permission.INTERNET" not in text:
    text = re.sub(r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>', text, count=1)
text = re.sub(r'android:label="[^"]*"', 'android:label="Dota Draft"', text, count=1)
manifest.write_text(text, encoding="utf-8")
print(text)
