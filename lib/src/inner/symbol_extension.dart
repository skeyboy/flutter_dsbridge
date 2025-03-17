extension SymbolExtension on Symbol {
  String get name {
    RegExp regex = RegExp(r'^Symbol\("(.+)"\)$');
    final match = regex.firstMatch(toString());
    return match?.group(1) ?? '';
  }
}
