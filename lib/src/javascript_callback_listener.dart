import 'package:flutter_dsbridge/src/ds_web_view_controller.dart';
import 'package:flutter_dsbridge/src/ds_result.dart';

class JavaScriptCallbackListener {
  String method;
  List? args;
  OnReturnValue? handler;
  JavaScriptCallbackListener({
    required this.method,
    this.args = const [],
    this.handler,
  });
}

extension DsWebViewControllerOfJavaScriptCallbackListener
    on DsWebViewController {
  void addCallListener(JavaScriptCallbackListener callback) {
    callHandler(
      callback.method,
      args: callback.args,
      handler: (retValue) => callback.handler?.call(retValue),
    );
  }
}
