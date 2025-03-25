import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dsbridge/src/inner/call_info.dart';
import 'package:flutter_dsbridge/src/ds_result.dart';
import 'package:flutter_dsbridge/src/javascript_namespace_interface.dart';
import 'package:flutter_dsbridge/src/inner/symbol_extension.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

typedef DsWebViewPermissionRequest =
    void Function(WebViewPermissionRequest request);
typedef DsWebViewJavaScriptAlertCallback =
    Future<void> Function(String message);
typedef DsWebViewJavaScriptConfirmCallback =
    Future<bool> Function(String message);

typedef DsWebViewJavaScriptPromptCallback =
    Future<String> Function(String message, String? defaultText);

typedef JavaScriptNamespaceInterfaces =
    Map<String, JavaScriptNamespaceInterface>;
typedef JavaScriptCloseWindowListener = Void Function();
typedef ExceptionExportInjecter = void Function(String);

class DsWebViewController extends WebViewController {
  DsWebViewJavaScriptAlertCallback? javaScriptAlertCallback;
  DsWebViewJavaScriptConfirmCallback? javaScriptConfirmCallback;
  DsWebViewJavaScriptPromptCallback? javaScriptPromptCallback;
  JavaScriptCloseWindowListener? javaScriptCloseWindowListener;
  ExceptionExportInjecter? exceptionExportInjecter;
  final _handlerMap = <int, OnReturnValue>{};
  int _callID = 0;

  List<CallInfo>? _callInfoList;

  // ignore: unused_field
  bool _alertBoxBlock = false;
  final String _jsChannel = "_dswk";
  final String _prefix = '_dsbridge=';

  final JavaScriptNamespaceInterfaces _javaScriptNamespaceInterfaces =
      <String, JavaScriptNamespaceInterface>{};
  BuildContext? _context;
  DsWebViewController({DsWebViewPermissionRequest? onPermissionRequest})
    : this.fromPlatformCreationParams(
        const PlatformWebViewControllerCreationParams(),
        onPermissionRequest: onPermissionRequest,
      );

  DsWebViewController.fromPlatformCreationParams(
    PlatformWebViewControllerCreationParams params, {
    DsWebViewPermissionRequest? onPermissionRequest,
  }) : this.fromPlatform(
         PlatformWebViewController(params),
         onPermissionRequest: onPermissionRequest,
       );

  // ignore: use_super_parameters
  DsWebViewController.fromPlatform(
    PlatformWebViewController platform, {
    DsWebViewPermissionRequest? onPermissionRequest,
  }) : super.fromPlatform(platform, onPermissionRequest: onPermissionRequest) {
    setJavaScriptMode(JavaScriptMode.unrestricted);
    _addInternalJavaScriptObject();
    addJavaScriptChannel(
      _jsChannel,
      onMessageReceived: (message) {
        _onMessageReceived(message);
      },
    );

    _setJavaScriptAlertCallback();
    _setJavaScriptConfirmCallback();
    _setJavaScriptPromptCallback();

    platform.setOnJavaScriptAlertDialog((request) async {
      javaScriptAlertCallback?.call(request.message);
    });

    platform.setOnJavaScriptConfirmDialog((request) async {
      return javaScriptConfirmCallback?.call(request.message) ??
          Future.value(false);
    });

    platform.setOnJavaScriptTextInputDialog((request) async {
      if (request.message.startsWith(_prefix)) {
        return _call(
          request.message.substring(_prefix.length),
          request.defaultText,
        );
      }
      return javaScriptPromptCallback?.call(
            request.message,
            request.defaultText,
          ) ??
          Future.value('');
    });
  }

  String _call(String methodName, String? argStr) {
    final ret = <String, dynamic>{'code': -1};
    final list = _parseNamespace(methodName.trim());
    final namespace = list[0];
    methodName = list[1];
    final jsb = _javaScriptNamespaceInterfaces[namespace];
    if (jsb == null) {
      _printDebugInfo(
        "Js bridge called, but can't find a corresponded JavascriptInterface object, please check your code!",
      );
      return jsonEncode(ret);
    }
    dynamic arg;
    String? callback;
    if (argStr != null && argStr.isNotEmpty) {
      try {
        Map<String, dynamic> args = jsonDecode(argStr);
        if (args.containsKey('_dscbstub')) {
          callback = args['_dscbstub'];
        }
        if (args.containsKey('data')) {
          arg = args['data'];
        }
      } catch (e) {
        _printDebugInfo(
          'The argument of "$methodName" must be a JSON object string!',
        );
        return jsonEncode(ret);
      }
    }
    bool asyn = false;
    final method = jsb.functionMap[methodName];
    if (method == null) {
      _printDebugInfo(
        'Not find method "$methodName" implementation! please check if the  signature or namespace of the method is right.',
      );
      return jsonEncode(ret);
    }
    if (method.runtimeType.toString().contains((#CompletionHandler).name)) {
      asyn = true;
    }
    try {
      if (asyn) {
        method.call(arg, InnerCompletionHandler(this, callback));
      } else {
        final retData = method.call(arg);
        ret['code'] = 0;
        ret['data'] = retData;
      }
    } on NoSuchMethodError {
      _printDebugInfo(
        'Call failed：The parameter of "$methodName" in Dart is invalid.',
      );
    }
    return jsonEncode(ret);
  }

  void _printDebugInfo(String error) {
    assert(() {
      error = error.replaceAll("'", "\\'");
      runJavaScript("alert('DEBUG ERR MSG:\\n$error')");
      return true;
    }());
  }

  Future<void> _dispatchJavaScriptCall(CallInfo info) async {
    try {
      await runJavaScript(
        'window._handleMessageFromNative(${info.toString()})',
      );
    } catch (e) {
      exceptionExportInjecter?.call(e.toString());
    }
  }

  void callHandler(String method, {List? args, OnReturnValue? handler}) {
    final callInfo = CallInfo(method, ++_callID, args);
    if (handler != null) {
      _handlerMap[callInfo.callbackId] = handler;
    }
    if (_callInfoList != null) {
      _callInfoList?.add(callInfo);
    } else {
      _dispatchJavaScriptCall(callInfo);
    }
  }

  void hasJavaScriptMethod(String handlerName, OnReturnValue existCallback) {
    callHandler(
      '_hasJavascriptMethod',
      args: [handlerName],
      handler: existCallback,
    );
  }

  @override
  Future<void> loadFile(String absoluteFilePath) {
    _callInfoList = [];
    return super.loadFile(absoluteFilePath);
  }

  @override
  Future<void> loadFlutterAsset(String key) {
    _callInfoList = [];
    return super.loadFlutterAsset(key);
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) {
    _callInfoList = [];
    return super.loadHtmlString(html, baseUrl: baseUrl);
  }

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) {
    if (!uri.scheme.startsWith('javascript')) {
      _callInfoList = [];
    }
    return super.loadRequest(uri, method: method, headers: headers, body: body);
  }

  @override
  Future<void> runJavaScript(String javaScript) {
    print("执行JavaScript code : $javaScript");
    return super.runJavaScript(javaScript);
  }

  @override
  Future<void> reload() {
    _callInfoList = [];
    return super.reload();
  }

  /// release
  void dispose() {
    _javaScriptNamespaceInterfaces.clear();
    removeJavaScriptChannel(_jsChannel);
  }

  void disableJavaScriptDialogBlock(bool disable) {
    _alertBoxBlock = !disable;
  }

  void _setJavaScriptPromptCallback() {
    javaScriptPromptCallback = (message, defaultText) async {
      final context = _context;
      if (context == null) {
        return '';
      }
      final textEditingController = TextEditingController();
      if (defaultText != null) {
        textEditingController.text = defaultText;
      }
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(message),
            content: TextField(controller: textEditingController),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(textEditingController.text);
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop('');
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
      return result ?? '';
    };
  }

  void _setJavaScriptConfirmCallback() {
    javaScriptConfirmCallback = (message) async {
      final context = _context;
      if (context == null) {
        return false;
      }
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
      return result ?? false;
    };
  }

  void _setJavaScriptAlertCallback() {
    javaScriptAlertCallback = (message) async {
      final context = _context;
      if (context == null) {
        return;
      }
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    };
  }

  List<String> _parseNamespace(String method) {
    final pos = method.indexOf('.');
    var namespace = '';
    if (pos != -1) {
      namespace = method.substring(0, pos);
      method = method.substring(pos + 1);
    }
    return [namespace, method];
  }

  void _onMessageReceived(JavaScriptMessage message) {}
  void _addInternalJavaScriptObject() {
    addJavaScriptObject(
      InnerJavaScriptNamespaceInterface(this),
      namespace: '_dsb',
    );
  }

  void addJavaScriptObject(
    JavaScriptNamespaceInterface object, {
    String? namespace,
  }) {
    namespace ??= object.namespace ?? '';
    _javaScriptNamespaceInterfaces[namespace] = object;
  }

  /// remove the javascript object with supplied namespace.
  void removeJavaScriptObject(String? namespace) {
    namespace ??= '';
    _javaScriptNamespaceInterfaces.remove(namespace);
  }

  void _dispatchStartupQueue() {
    if (_callInfoList == null) {
      return;
    }
    for (final info in _callInfoList!) {
      _dispatchJavaScriptCall(info);
    }
    _callInfoList = null;
  }

  void visit(BuildContext context) {
    _context = context;
  }
}

class InnerCompletionHandler extends CompletionHandler {
  final DsWebViewController controller;
  final String? cb;

  InnerCompletionHandler(this.controller, this.cb);

  @override
  void complete([retValue]) {
    completeProcess(retValue, true);
  }

  @override
  void setProgressData(value) {
    completeProcess(value, false);
  }

  Future<void> completeProcess(dynamic retValue, bool complete) async {
    final ret = {'code': 0, 'data': retValue};
    if (cb == null) {
      return;
    }
    var script = '$cb(${jsonEncode(ret)}.data);';
    if (complete) {
      script += 'delete window.$cb';
    }
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      controller.exceptionExportInjecter?.call(e.toString());
    }
  }
}

class InnerJavaScriptNamespaceInterface extends JavaScriptNamespaceInterface {
  final DsWebViewController controller;

  InnerJavaScriptNamespaceInterface(this.controller) : super(namespace: null);

  @override
  void register() {
    registerFunction(hasNativeMethod);
    registerFunction(closePage);
    registerFunction(disableJavascriptDialogBlock);
    registerFunction(dsinit);
    registerFunction(returnValue);
  }

  @pragma('vm:entry-point')
  bool hasNativeMethod(dynamic args) {
    if (args == null || args.isEmpty) {
      return false;
    }
    var methodName = args['name'].trim();
    final type = args['type'].trim();
    final list = controller._parseNamespace(methodName);
    final namespace = list[0];
    methodName = list[1];
    final jsb = controller._javaScriptNamespaceInterfaces[namespace];
    if (jsb == null) {
      return false;
    }
    bool asyn = false;
    final method = jsb.functionMap[methodName];
    if (method == null) {
      return false;
    }
    if (method.runtimeType.toString().contains((#CompletionHandler).name)) {
      asyn = true;
    }
    if (type == 'all' || (asyn && type == 'asyn') || (!asyn && type == 'syn')) {
      return true;
    }
    return false;
  }

  @pragma('vm:entry-point')
  void closePage(dynamic args) {
    controller.javaScriptCloseWindowListener?.call();
  }

  @pragma('vm:entry-point')
  void disableJavascriptDialogBlock(dynamic args) {
    controller._alertBoxBlock = !args['disable'];
  }

  @pragma('vm:entry-point')
  void dsinit(dynamic args) {
    controller._dispatchStartupQueue();
  }

  @pragma('vm:entry-point')
  void returnValue(dynamic args) {
    int id = args['id'];
    bool isCompleted = args['complete'];
    final handler = controller._handlerMap[id];
    dynamic data;
    if (args.containsKey('data')) {
      data = args['data'];
    }
    handler?.call(data);
    if (isCompleted) {
      controller._handlerMap.remove(id);
    }
  }
}
