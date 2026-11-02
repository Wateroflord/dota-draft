import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'i18n.dart';

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Запросы к Google Gemini (разбор матча). Ключ бесплатный: aistudio.google.com/apikey.
class Gemini {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  static const models = ['gemini-flash-latest', 'gemini-3.8-flash', 'gemini-3.6-flash', 'gemini-3.5-flash-lite'];

  /// Проверка ключа. null — ключ рабочий, иначе текст ошибки.
  static Future<String?> testKey(String key) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/models?pageSize=50'), headers: {'x-goog-api-key': key.trim()})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      return L('Ключ не принят (${res.statusCode}): ${_err(res.bodyBytes)}', 'Key rejected (${res.statusCode}): ${_err(res.bodyBytes)}');
    } on TimeoutException {
      return L('Сервер не ответил. Проверь интернет.', 'No response. Check your internet.');
    } catch (e) {
      return L('Нет соединения: $e', 'No connection: $e');
    }
  }

  /// Текстовый ответ на [prompt]. Если модель недоступна, пробует следующую.
  static Future<String> generate(String key, String prompt) async {
    if (key.trim().isEmpty) {
      throw GeminiException(L('Добавь ключ Gemini: «Мои герои» → «ИИ-разбор матчей».', 'Add a Gemini key: My heroes → AI match review.'));
    }
    var last = L('ИИ не ответил', 'The AI did not answer');
    for (final m in models) {
      final http.Response res;
      try {
        res = await http
            .post(
              Uri.parse('$_base/models/$m:generateContent'),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': key.trim()},
              body: jsonEncode({
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
              }),
            )
            .timeout(const Duration(seconds: 90));
      } on TimeoutException {
        throw GeminiException(L('ИИ слишком долго отвечает. Попробуй ещё раз.', 'The AI is taking too long. Try again.'));
      } catch (_) {
        throw GeminiException(L('Нет соединения с интернетом.', 'No internet connection.'));
      }
      if (res.statusCode == 404 || res.statusCode >= 500) {
        last = L('Модель $m недоступна (${res.statusCode})', 'Model $m unavailable (${res.statusCode})');
        continue;
      }
      if (res.statusCode == 429) {
        throw GeminiException(L('Превышен лимит запросов Gemini. Подожди минуту.', 'Gemini rate limit reached. Wait a minute.'));
      }
      if (res.statusCode != 200) {
        final msg = _err(res.bodyBytes);
        if (res.statusCode == 400 && msg.toLowerCase().contains('model')) {
          last = msg;
          continue;
        }
        throw GeminiException(L('Ошибка Gemini (${res.statusCode}): $msg', 'Gemini error (${res.statusCode}): $msg'));
      }
      try {
        final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
        final parts = (((j['candidates'] as List).first as Map)['content'] as Map)['parts'] as List;
        final text = parts
            .whereType<Map>()
            .where((p) => p['thought'] != true && p['text'] is String)
            .map((p) => p['text'] as String)
            .join()
            .trim();
        if (text.isNotEmpty) return text;
      } catch (_) {}
      last = L('ИИ вернул пустой ответ', 'The AI returned an empty answer');
    }
    throw GeminiException(last);
  }

  static String _err(List<int> b) {
    try {
      final j = jsonDecode(utf8.decode(b));
      if (j is Map && j['error'] is Map) return (j['error'] as Map)['message']?.toString() ?? '';
    } catch (_) {}
    return '';
  }
}
