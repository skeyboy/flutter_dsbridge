extension FunctionExtension on Function {
  String get name {
    RegExp regex = RegExp(r"from Function '([^@]+)(@?)(\d*)':.$");
    final match = regex.firstMatch(toString());
    final result = match?.group(1) ?? '';
    return result;
  }
}
