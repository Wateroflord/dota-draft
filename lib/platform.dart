import 'dart:io';

import 'package:flutter/foundation.dart';

/// Платформа: телефон Android или ПК с Windows.
bool get isWindows => !kIsWeb && Platform.isWindows;
bool get isAndroid => !kIsWeb && Platform.isAndroid;
