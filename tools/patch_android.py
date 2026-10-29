"""Настраивает сгенерированный Android-проект: разрешения (интернет, камера, уведомления), голос (TTS),
название приложения, desugaring для уведомлений и виджет на главный экран."""
import pathlib
import re

ROOT = pathlib.Path("android/app")
manifest = ROOT / "src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")


def permission(name):
    global text
    if name not in text:
        text = re.sub(r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="' + name + '"/>', text, count=1)


for p in ("android.permission.INTERNET", "android.permission.CAMERA", "android.permission.POST_NOTIFICATIONS",
          "android.permission.VIBRATE"):
    permission(p)

if "TTS_SERVICE" not in text:
    text = text.replace(
        "</manifest>",
        '    <queries>\n        <intent>\n            <action android:name="android.intent.action.TTS_SERVICE"/>\n'
        "        </intent>\n    </queries>\n</manifest>",
    )
text = re.sub(r'android:label="[^"]*"', 'android:label="Dota Draft"', text, count=1)

# Виджет на главный экран.
if "DotaWidgetProvider" not in text:
    receiver = '''        <receiver android:name=".DotaWidgetProvider" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/dota_widget_info"/>
        </receiver>
    </application>'''
    text = text.replace("    </application>", receiver, 1)
manifest.write_text(text, encoding="utf-8")
print(text)

# Kotlin-код виджета рядом с MainActivity.
main = next(ROOT.glob("src/main/kotlin/**/MainActivity.kt"))
pkg = re.search(r"^package\s+([\w.]+)", main.read_text(encoding="utf-8"), re.M).group(1)
(main.parent / "DotaWidgetProvider.kt").write_text(f'''package {pkg}

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DotaWidgetProvider : HomeWidgetProvider() {{
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {{
        appWidgetIds.forEach {{ widgetId ->
            val views = RemoteViews(context.packageName, R.layout.dota_widget).apply {{
                setTextViewText(R.id.widget_title, widgetData.getString("title", "Dota Draft"))
                setTextViewText(R.id.widget_line1, widgetData.getString("line1", "Открой приложение, чтобы обновить"))
                setTextViewText(R.id.widget_line2, widgetData.getString("line2", ""))
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }}
            appWidgetManager.updateAppWidget(widgetId, views)
        }}
    }}
}}
''', encoding="utf-8")

res = ROOT / "src/main/res"
(res / "layout").mkdir(parents=True, exist_ok=True)
(res / "xml").mkdir(parents=True, exist_ok=True)
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "drawable/dota_widget_bg.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#E6131416"/>
    <corners android:radius="16dp"/>
    <stroke android:width="1dp" android:color="#26272B"/>
</shape>
''', encoding="utf-8")
(res / "layout/dota_widget.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="@drawable/dota_widget_bg">
    <TextView
        android:id="@+id/widget_title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Dota Draft"
        android:textColor="#CE3535"
        android:textStyle="bold"
        android:textSize="13sp"/>
    <TextView
        android:id="@+id/widget_line1"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:textColor="#EDEDEF"
        android:textSize="13sp"
        android:maxLines="2"/>
    <TextView
        android:id="@+id/widget_line2"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="2dp"
        android:textColor="#AFB3BA"
        android:textSize="12sp"
        android:maxLines="2"/>
</LinearLayout>
''', encoding="utf-8")
(res / "xml/dota_widget_info.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="70dp"
    android:targetCellWidth="3"
    android:targetCellHeight="1"
    android:updatePeriodMillis="0"
    android:initialLayout="@layout/dota_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"/>
''', encoding="utf-8")

# Desugaring (нужен для уведомлений).
gradle = ROOT / "build.gradle.kts"
if gradle.exists():
    g = gradle.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
    if "desugar_jdk_libs" not in g:
        if re.search(r"^dependencies\s*\{", g, re.M):
            g = re.sub(r"^dependencies\s*\{", 'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")', g, count=1, flags=re.M)
        else:
            g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    gradle.write_text(g, encoding="utf-8")
    print(g)
else:
    gradle = ROOT / "build.gradle"
    g = gradle.read_text(encoding="utf-8")
    if "coreLibraryDesugaringEnabled" not in g:
        g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
    if "desugar_jdk_libs" not in g:
        g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    gradle.write_text(g, encoding="utf-8")
    print(g)
