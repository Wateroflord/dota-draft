import 'package:winter_core/winter_core.dart';

import 'i18n.dart';

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Запросы к Google Gemini (разбор матча) через общий клиент winter_core.
/// Ключ бесплатный: aistudio.google.com/apikey.
class Gemini {
  static const models = WinterGemini.models;

  /// Проверка ключа. null — ключ рабочий, иначе текст ошибки.
  static Future<String?> testKey(String key) async {
    final e = await WinterGemini.testKey(key);
    if (e == null) return null;
    return switch (e.kind) {
      GeminiFail.timeout => L('Сервер не ответил. Проверь интернет.', 'No response. Check your internet.'),
      GeminiFail.offline => L('Нет соединения: ${e.detail}', 'No connection: ${e.detail}'),
      _ => L('Ключ не принят (${e.code}): ${e.detail}', 'Key rejected (${e.code}): ${e.detail}'),
    };
  }

  /// Текстовый ответ на [prompt]. Если модель недоступна, пробует следующую.
  static Future<String> generate(String key, String prompt) async {
    try {
      return (await WinterGemini.generate(key: key, parts: [WinterGemini.text(prompt)])).trim();
    } on GeminiError catch (e) {
      throw GeminiException(switch (e.kind) {
        GeminiFail.noKey => L('Добавь ключ Gemini: «Мои герои» → «ИИ-разбор матчей».', 'Add a Gemini key: My heroes → AI match review.'),
        GeminiFail.timeout => L('ИИ слишком долго отвечает. Попробуй ещё раз.', 'The AI is taking too long. Try again.'),
        GeminiFail.offline => L('Нет соединения с интернетом.', 'No internet connection.'),
        GeminiFail.rateLimit => L('Превышен лимит запросов Gemini. Подожди минуту.', 'Gemini rate limit reached. Wait a minute.'),
        GeminiFail.unavailable => L('Модели Gemini сейчас недоступны', 'Gemini models are unavailable right now'),
        GeminiFail.empty || GeminiFail.blocked || GeminiFail.badResponse => L('ИИ вернул пустой ответ', 'The AI returned an empty answer'),
        GeminiFail.badKey || GeminiFail.http => L('Ошибка Gemini (${e.code}): ${e.detail}', 'Gemini error (${e.code}): ${e.detail}'),
      });
    }
  }
}
