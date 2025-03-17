# DSBridge for Flutter

>Modern cross-platform JavaScript bridge, through which you can invoke each other's functions synchronously or asynchronously between JavaScript and Flutter applications.

## Overview

flutter_dsbridge_annotation for Flutter is fully **compatible** with Android and iOS DSBridge's dsbridge.js.

No need to modify any code in your existing web projects which using dsbridge.js.

DSBridge for Flutter is based on Flutter official [webview_flutter](https://pub.dev/packages/webview_flutter).

## Installation

1. Add the dependency

   ```yml
   dependencies:
     ...
     flutter_dsbridge: x.y.z
   ```

## Examples

See the `example` package. run the `example` project and to see it in action.

To use flutter_dsbridge_annotation in your own project, just see the example.

### Simple use

export object as JavaScriptObject

```dart
@DSBridge(enableDebug: true)
class JsApi {
  @dsBridge()
  String testSyn(dynamic msg) {
    print('msg=$msg');
    return "$msg［syn call］";
  }

  @dsBridge(async: true)
  void testAsyn(dynamic msg, CompletionHandler handler) {
    handler.complete("$msg [ asyn call]");
  }

  @dsBridge()
  String testNoArgSyn(dynamic arg) {
    return "testNoArgSyn called [ syn call]";
  }

  @dsBridge(async: true)
  void testNoArgAsyn(dynamic arg, CompletionHandler handler) {
    handler.complete("testNoArgAsyn called [ asyn call]");
  }

  @dsBridge(async: true)
  void callProgress(dynamic args, CompletionHandler handler) {
    var i = 10;
    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (i == 0) {
        timer.cancel();
        handler.complete(0);
      } else {
        handler.setProgressData(i--);
      }
    });
  }
}
```

Inject the JSObject into webView
```dart
    final DWebViewController controller =
        DWebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setBackgroundColor(Colors.white)
      ..loadFlutterAsset('assets/js-call-dart.html')
      ..addJavaScriptObject(JsApiWrapper())
      ..addJavaScriptObject(JsEchoApiWrapper(), namespace: 'echo')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            print('process=$progress');
          },
          onPageStarted: (url) {
            print('url onPageStarted');
          },
          onPageFinished: (url) {
            print('url onPageFinished');
          },
        ),
      );
```

this will export an object as the bridge between JS and Native, then you can get JS callback (sync or async) by this bridge

So you can simple call item as follow case:
```dart
FilledButton(
                child: const Text('addValue(3,4)'),
                onPressed: () {
                  _controller.callHandler(
                    'addValue',
                    args: [3, 4],
                    handler: (retValue) {
                      Fluttertoast.showToast(msg: retValue.toString());
                    },
                  );
                },
              ),
              FilledButton(
                child: const Text("append('I','love','you')"),
                onPressed: () {
                  _controller.callHandler(
                    'append',
                    args: ["I", "love", "you"],
                    handler: (retValue) {
                      Fluttertoast.showToast(msg: retValue.toString());
                    },
                  );
                },
              ),
```

and the equal js as are these:
```javascript
 dsBridge.register('addValue', function (r, l) {
        return r + l;
    })

    dsBridge.registerAsyn('append', function (arg1, arg2, arg3, responseCallback) {
        responseCallback(arg1 + " " + arg2 + " " + arg3);
    })
```
more examples are in the example demo . you can download to enjoy it.

## Finally

If you like DSBridge for Flutter, please click star/like to let more people know it, Thanks!