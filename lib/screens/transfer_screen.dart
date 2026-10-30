import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../i18n.dart';
import '../platform.dart';
import '../storage.dart';
import '../theme.dart';
import '../widgets.dart';

const _prefix = 'DDS1:';

/// Собрать код переноса: профиль, мои герои, заметки, цели, друзья, история драфтов, настройки инструментов.
Future<String> buildTransferCode() async {
  final d = await appDir();
  Future<Map<String, dynamic>> read(String name) async {
    try {
      final f = File('${d.path}/$name');
      if (await f.exists()) return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  final st = await read('draft_state.json');
  // Большие таблицы статистики заново скачаются с OpenDota по ID профиля.
  for (final k in ['played', 'vs', 'playerAvatar']) {
    st.remove(k);
  }
  final tools = await read('tools_state.json');
  for (final k in ['mapImage', 'overlayRect']) {
    tools.remove(k);
  }
  final raw = utf8.encode(jsonEncode({'s': st, 't': tools}));
  return _prefix + base64Url.encode(gzip.encode(raw));
}

/// Применить код переноса. Возвращает текст ошибки или null.
Future<String?> applyTransferCode(String code) async {
  final c = code.trim();
  final i = c.indexOf(_prefix);
  if (i < 0) return L('Это не код переноса Dota Draft', 'This is not a Dota Draft transfer code');
  try {
    final j = jsonDecode(utf8.decode(gzip.decode(base64Url.decode(c.substring(i + _prefix.length).replaceAll(RegExp(r'\s'), ''))))) as Map;
    final d = await appDir();
    final stFile = File('${d.path}/draft_state.json');
    // Сохраняем то, что не переносится (статистика профиля), если профиль тот же.
    Map<String, dynamic> old = {};
    try {
      if (await stFile.exists()) old = jsonDecode(await stFile.readAsString()) as Map<String, dynamic>;
    } catch (_) {}
    final st = Map<String, dynamic>.from(j['s'] as Map);
    if (old['accountId'] != null && old['accountId'] == st['accountId']) {
      for (final k in ['played', 'vs', 'playerAvatar']) {
        if (old.containsKey(k)) st[k] = old[k];
      }
    }
    await stFile.writeAsString(jsonEncode(st));
    final toolsFile = File('${d.path}/tools_state.json');
    Map<String, dynamic> oldTools = {};
    try {
      if (await toolsFile.exists()) oldTools = jsonDecode(await toolsFile.readAsString()) as Map<String, dynamic>;
    } catch (_) {}
    final t = Map<String, dynamic>.from(j['t'] as Map);
    for (final k in ['mapImage', 'overlayRect']) {
      if (oldTools.containsKey(k)) t[k] = oldTools[k];
    }
    await toolsFile.writeAsString(jsonEncode(t));
    return null;
  } catch (e) {
    return L('Код повреждён или не полностью скопирован', 'The code is damaged or incomplete');
  }
}

/// Перенос настроек между телефоном и ПК без сервера: код (скопировать/вставить) или QR.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  String? code;
  final input = TextEditingController();
  bool done = false;

  @override
  void initState() {
    super.initState();
    buildTransferCode().then((v) {
      if (mounted) setState(() => code = v);
    });
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _import(String text) async {
    final err = await applyTransferCode(text);
    if (!mounted) return;
    if (err != null) {
      showToast(context, err);
    } else {
      setState(() => done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = code;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Перенос телефон ↔ ПК', 'Phone ↔ PC transfer'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          Text(
            L('Переносятся: профиль, мои герои, заметки, цели, друзья, история драфтов, правки карты, таймеры и горячие клавиши. '
                'Интернет-сервер не нужен — код содержит всё сам.',
                'Transferred: profile, my heroes, notes, goals, friends, draft history, map edits, timers and hotkeys. '
                'No server needed — the code contains everything.'),
            style: T.small,
          ),
          SectionLabel(L('Отправить с этого устройства', 'Send from this device')),
          AppCard(
            child: c == null
                ? const Center(child: CircularProgressIndicator(color: C.accent))
                : Column(children: [
                    if (c.length <= 2300)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(data: c, size: 260, errorCorrectionLevel: QrErrorCorrectLevel.L),
                      )
                    else
                      Text(L('Данных много для QR — используй кнопку «Скопировать код» и перешли его себе (например, в Telegram).',
                          'Too much data for a QR — use Copy code and send it to yourself (e.g. via Telegram).'), style: T.small),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.accent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c));
                        showToast(context, L('Код скопирован (${c.length} символов)', 'Code copied (${c.length} chars)'));
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(L('Скопировать код', 'Copy code')),
                    ),
                  ]),
          ),
          SectionLabel(L('Принять на этом устройстве', 'Receive on this device')),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (done)
                Text(L('Готово! Закрой и снова открой приложение, чтобы всё применилось.', 'Done! Close and reopen the app to apply everything.'),
                    style: T.body.copyWith(color: C.ally))
              else ...[
                TextField(
                  controller: input,
                  maxLines: 3,
                  style: T.body.copyWith(fontSize: 12),
                  decoration: fieldDeco(L('Вставь код DDS1:…', 'Paste the DDS1:… code')),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
                      onPressed: () async {
                        final d = await Clipboard.getData('text/plain');
                        if (d?.text != null) input.text = d!.text!;
                        setState(() {});
                      },
                      icon: const Icon(Icons.paste, size: 18),
                      label: Text(L('Вставить', 'Paste')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: C.accent),
                      onPressed: () => _import(input.text),
                      child: Text(L('Применить', 'Apply')),
                    ),
                  ),
                ]),
                if (isAndroid) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
                    onPressed: () async {
                      final v = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _Scan()));
                      if (v != null) _import(v);
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: Text(L('Сканировать QR с экрана ПК', 'Scan the QR on the PC screen')),
                  ),
                ],
                const SizedBox(height: 6),
                Text(L('Внимание: текущие настройки на этом устройстве заменятся.', 'Note: current settings on this device will be replaced.'),
                    style: T.small.copyWith(color: C.gold)),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _Scan extends StatefulWidget {
  const _Scan();

  @override
  State<_Scan> createState() => _ScanState();
}

class _ScanState extends State<_Scan> {
  bool done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text(L('Наведи на QR-код', 'Point at the QR code'), style: T.h2)),
        body: MobileScanner(
          onDetect: (capture) {
            if (done) return;
            for (final b in capture.barcodes) {
              final v = b.rawValue;
              if (v != null && v.contains(_prefix)) {
                done = true;
                Navigator.of(context).pop(v);
                return;
              }
            }
          },
        ),
      );
}
