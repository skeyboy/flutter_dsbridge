import 'package:flutter_dsbridge/src/ds_web_view_controller.dart';
import 'package:flutter_dsbridge/src/ds_webview_widget.dart';

export './src/ds_web_view_controller.dart';
export './src/ds_webview_widget.dart';
export 'src/javascript_namespace_interface.dart';
export './src/javascript_callback_listener.dart';
export './src/ds_result.dart';

@Deprecated('you can use DsWebViewController instead')
typedef DWebViewController = DsWebViewController;

@Deprecated('you can use DsWebViewWidget instead')
typedef DWebViewWidget = DsWebViewWidget;
