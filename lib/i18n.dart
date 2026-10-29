/// Язык интерфейса: русский по умолчанию, английский — по выбору в настройках.
bool isEn = false;

/// Текст на текущем языке.
String L(String ru, String en) => isEn ? en : ru;
