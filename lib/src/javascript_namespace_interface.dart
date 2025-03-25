import 'package:flutter_dsbridge/src/inner/function_extension.dart';

abstract class JavaScriptNamespaceInterface {
  var functionMap = <String, Function>{};
  String? namespace;

  JavaScriptNamespaceInterface({this.namespace}) {
    register();
  }

  void register();

  bool registerFunction(Function function, {String? functionName}) {
    final name = functionName ?? function.name;
    if (name.isEmpty) {
      return false;
    }
    functionMap[name] = function;
    return true;
  }
}
