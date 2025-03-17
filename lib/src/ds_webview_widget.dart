import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dsbridge/src/ds_web_view_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// ignore: must_be_immutable
class DsWebViewWidget extends WebViewWidget {
  DsWebViewController? _controller;

  DsWebViewWidget({
    super.key,
    super.gestureRecognizers,
    super.layoutDirection,
    required DsWebViewController controller,
  }) : _controller = controller,
       super(controller: controller);
  DsWebViewWidget.fromPlatformCreationParams({
    super.key,
    required PlatformWebViewWidgetCreationParams params,
  }) : super.fromPlatform(platform: PlatformWebViewWidget(params));

  // ignore: use_super_parameters
  DsWebViewWidget.fromPlatform({
    super.key,
    required PlatformWebViewWidget platform,
  }) : super.fromPlatform(platform: platform);

  @override
  Widget build(BuildContext context) {
    _controller?.visit(context);
    return super.build(context);
  }
}
