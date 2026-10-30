import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import 'platform.dart';

/// Озвучка. На телефоне — flutter_tts, на Windows — голоса Windows через PowerShell
/// (родной модуль flutter_tts ронял приложение на части ПК с Windows 10).
/// Если голоса нужного языка нет — молчим (иначе английский голос читает русский текст как попало).
class Tts {
  FlutterTts? _tts;
  String _lang = 'ru-RU';
  double _rate = 0.5;
  Process? _proc;

  FlutterTts? get _t => isWindows ? null : (_tts ??= FlutterTts());

  Future<void> setLanguage(String lang) async {
    _lang = lang;
    try {
      await _t?.setLanguage(lang);
    } catch (_) {}
  }

  Future<void> setSpeechRate(double rate) async {
    _rate = rate;
    try {
      await _t?.setSpeechRate(rate);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      if (isWindows) {
        _proc?.kill();
        _proc = null;
      } else {
        await _t?.stop();
      }
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      if (!isWindows) {
        await _t?.speak(text);
        return;
      }
      // Скорость SAPI: от −10 до 10; 0.5 у flutter_tts ≈ обычная.
      final rate = ((_rate - 0.5) * 10).round().clamp(-10, 10);
      const script = r'''
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$v = $s.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -eq $env:DD_LANG } | Select-Object -First 1
if (-not $v) { $p = $env:DD_LANG.Split('-')[0]; $v = $s.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.TwoLetterISOLanguageName -eq $p } | Select-Object -First 1 }
if (-not $v) { exit 3 }
$s.SelectVoice($v.VoiceInfo.Name)
$s.Rate = [int]$env:DD_RATE
$s.Speak($env:DD_TEXT)
''';
      _proc = await Process.start(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', script],
        environment: {'DD_TEXT': text, 'DD_LANG': _lang, 'DD_RATE': '$rate'},
      );
    } catch (_) {}
  }
}
