import '../i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Поделиться драфтом: код и QR, или открыть чужой код / QR.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _apply(String code) {
    final s = StateScope.read(context);
    if (s.applyCode(code)) {
      showToast(context, L('Драфт загружен', 'Draft loaded'));
      Navigator.of(context).pop();
    } else {
      showToast(context, L('Не похоже на код драфта. Он начинается с DD1;', 'This does not look like a draft code. It starts with DD1;'));
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanScreen()));
    if (code != null && mounted) _apply(code);
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final code = s.shareCode;
    final empty = s.allies.every((e) => e == null) && s.enemies.every((e) => e == null) && s.bans.isEmpty;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Поделиться драфтом', 'Share draft'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (empty)
            AppCard(child: Text(L('Драфт пустой — добавь героев на вкладке «Драфт», чтобы поделиться.', 'The draft is empty — add heroes on the Draft tab to share.'), style: T.body))
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: QrImageView(data: code, size: 220, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(L('Друг открывает Dota Draft → «Поделиться» → «Сканировать QR».', 'Your friend opens Dota Draft → Share → Scan QR.'),
                textAlign: TextAlign.center, style: T.small),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(children: [
                Expanded(child: SelectableText(code, style: T.body.copyWith(fontSize: 13, fontFamily: 'monospace'))),
                IconButton(
                  icon: const Icon(Icons.copy, color: C.accent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showToast(context, L('Код скопирован — отправь его другу в Discord или Telegram', 'Code copied — send it to your friend in Discord or Telegram'));
                  },
                ),
              ]),
            ),
          ],
          SectionLabel(L('Открыть чужой драфт', 'Open someone else\'s draft')),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.accent),
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(L('Сканировать QR', 'Scan QR')),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: input, style: T.body, decoration: fieldDeco(L('Вставь код DD1;…', 'Paste a DD1;… code')))),
            const SizedBox(width: 6),
            IconButton(
              tooltip: L('Вставить из буфера', 'Paste from clipboard'),
              icon: const Icon(Icons.content_paste, color: C.muted),
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                if (d?.text != null) setState(() => input.text = d!.text!);
              },
            ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: C.border)),
            onPressed: () => _apply(input.text),
            child: Text(L('Открыть по коду', 'Open by code')),
          ),
          const SizedBox(height: 8),
          Text(L('Текущий драфт будет заменён.', 'The current draft will be replaced.'), style: T.small),
        ],
      ),
    );
  }
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  bool done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(L('Наведи на QR-код', 'Point at the QR code'), style: T.h2)),
      body: MobileScanner(
        onDetect: (capture) {
          if (done) return;
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && v.contains('DD1;')) {
              done = true;
              Navigator.of(context).pop(v);
              return;
            }
          }
        },
      ),
    );
  }
}
