enum ReadingMode { light, dark, sepia }

extension ReadingModeX on ReadingMode {
  String get label {
    switch (this) {
      case ReadingMode.dark:
        return 'Dark';
      case ReadingMode.light:
        return 'Light';
      case ReadingMode.sepia:
        return 'Sepia';
    }
  }

  String get key => name;
}
