import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';

import 'i18n.dart';
import 'platform.dart';

bool _notifierReady = false;

/// Всплывающее уведомление Windows.
Future<void> showToastWin(String title, String body) async {
  if (!isWindows) return;
  try {
    if (!_notifierReady) {
      await localNotifier.setup(appName: 'Dota Draft', shortcutPolicy: ShortcutPolicy.requireCreate);
      _notifierReady = true;
    }
    await LocalNotification(title: title, body: body).show();
  } catch (_) {}
}

/// Снимок основного экрана (PNG) средствами Windows. null — не получилось.
Future<Uint8List?> captureScreen() async {
  if (!isWindows) return null;
  try {
    final path = '${Directory.systemTemp.path}\\dota_draft_shot.png';
    final ps = '''
Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -Name U -Namespace W | Out-Null
[W.U]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
\$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
\$bmp = New-Object System.Drawing.Bitmap \$b.Width, \$b.Height
\$g = [System.Drawing.Graphics]::FromImage(\$bmp)
\$g.CopyFromScreen(\$b.Location, [System.Drawing.Point]::Empty, \$b.Size)
\$bmp.Save('$path', [System.Drawing.Imaging.ImageFormat]::Png)
''';
    final r = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', ps]);
    if (r.exitCode != 0) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

/// Следит, запущена ли Dota 2 (процесс dota2.exe).
class DotaWatcher {
  Timer? _t;
  bool running = false;
  void Function(bool running)? onChange;

  void start() {
    if (!isWindows || _t != null) return;
    _t = Timer.periodic(const Duration(seconds: 8), (_) => _check());
    _check();
  }

  void stop() {
    _t?.cancel();
    _t = null;
  }

  Future<void> _check() async {
    try {
      final r = await Process.run('tasklist', ['/FI', 'IMAGENAME eq dota2.exe', '/NH']);
      final now = '${r.stdout}'.toLowerCase().contains('dota2.exe');
      if (now != running) {
        running = now;
        onChange?.call(now);
      }
    } catch (_) {}
  }
}

final dotaWatcher = DotaWatcher();

/// Иконка в трее (возле часов).
class Tray with TrayListener {
  void Function()? onShow, onOverlay, onQuit;

  Future<void> init(String iconPath) async {
    if (!isWindows) return;
    try {
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('Dota Draft');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: L('Открыть', 'Open')),
        MenuItem(key: 'overlay', label: L('Оверлей вкл/выкл', 'Toggle overlay')),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: L('Выход', 'Quit')),
      ]));
      trayManager.addListener(this);
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() => onShow?.call();

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        onShow?.call();
      case 'overlay':
        onOverlay?.call();
      case 'quit':
        onQuit?.call();
    }
  }
}

final tray = Tray();

/// Запуск вместе с Windows.
Future<bool> startupEnabled() async {
  if (!isWindows) return false;
  try {
    launchAtStartup.setup(appName: 'Dota Draft', appPath: Platform.resolvedExecutable);
    return await launchAtStartup.isEnabled();
  } catch (_) {
    return false;
  }
}

Future<void> setStartup(bool on) async {
  if (!isWindows) return;
  try {
    launchAtStartup.setup(appName: 'Dota Draft', appPath: Platform.resolvedExecutable);
    if (on) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  } catch (_) {}
}

/// Страница для OBS: http://127.0.0.1:3001/ — драфт и шанс победы для зрителей.
class ObsServer {
  HttpServer? _s;
  Map<String, dynamic> Function()? state;

  bool get running => _s != null;

  Future<void> start() async {
    if (_s != null) return;
    try {
      _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 3001, shared: true);
      _s!.listen((req) async {
        try {
          if (req.uri.path == '/state') {
            req.response.headers.contentType = ContentType.json;
            req.response.write(jsonEncode(state?.call() ?? {}));
          } else {
            req.response.headers.contentType = ContentType.html;
            req.response.write(_page);
          }
        } catch (_) {}
        await req.response.close();
      });
    } catch (_) {
      _s = null;
    }
  }

  Future<void> stop() async {
    await _s?.close(force: true);
    _s = null;
  }
}

final obs = ObsServer();

const _page = '''<!doctype html><html><head><meta charset="utf-8"><title>Dota Draft</title>
<style>
body{margin:0;background:transparent;font-family:Segoe UI,Arial,sans-serif;color:#fff}
.box{display:inline-block;background:rgba(11,11,13,.82);border-radius:12px;padding:12px 16px}
.row{display:flex;gap:6px;align-items:center;margin:4px 0}
.row img{width:72px;height:40px;object-fit:cover;border-radius:5px}
.lbl{width:70px;font-size:12px;font-weight:700;letter-spacing:.5px}
.ch{font-size:30px;font-weight:800;margin-top:6px}
.g{color:#3DD68C}.r{color:#FF5C7A}
</style></head><body><div class="box">
<div class="row"><div class="lbl g" id="la">ALLY</div><div id="a" class="row"></div></div>
<div class="row"><div class="lbl r" id="le">ENEMY</div><div id="e" class="row"></div></div>
<div class="ch" id="c"></div></div>
<script>
async function tick(){try{const s=await (await fetch('/state')).json();
const f=(id,l)=>{document.getElementById(id).innerHTML=(l||[]).map(h=>'<img src="'+h.img+'" title="'+h.name+'">').join('')};
f('a',s.allies);f('e',s.enemies);document.getElementById('la').textContent=s.la||'ALLY';document.getElementById('le').textContent=s.le||'ENEMY';
const c=document.getElementById('c');c.textContent=s.chance?s.label+' '+Math.round(s.chance*100)+'%':'';c.className='ch '+(s.chance>=.5?'g':'r');
}catch(e){} setTimeout(tick,2000)} tick();
</script></body></html>''';
