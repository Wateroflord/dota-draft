import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Папка для данных приложения: на телефоне — файлы приложения, на Windows — AppData (не «Документы»).
Future<Directory> appDir() =>
    Platform.isWindows ? getApplicationSupportDirectory() : getApplicationDocumentsDirectory();
