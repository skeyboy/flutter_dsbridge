import 'dart:convert';

class CallInfo {
  late String data;
  late int callbackId;
  late String method;

  CallInfo(String handlerName, int id, List? args) {
    args ??= [];
    data = jsonEncode(args);
    callbackId = id;
    method = handlerName;
  }

  @override
  String toString() {
    final jsonMap = {'method': method, 'callbackId': callbackId, 'data': data};
    return jsonEncode(jsonMap);
  }
}
