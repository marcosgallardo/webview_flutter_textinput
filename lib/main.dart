import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<WebViewController> _webViewController =
      Completer<WebViewController>();

  WebViewController _controller;
  FocusNode _focusNode = FocusNode();
  TextEditingController _textController = TextEditingController();
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return new Scaffold(
        appBar: new AppBar(
          title: new Text('iOS Flutter Webview'),
          actions: <Widget>[
            FutureBuilder<WebViewController>(
              future: _webViewController.future,
              builder: (BuildContext context,
                  AsyncSnapshot<WebViewController> snapshot) {
                return NavigationControls(snapshot.data);
              },
            ),
          ],
        ),
        body: WebView(
          initialUrl: 'https://pub.dartlang.org/packages/',
          javascriptMode: JavascriptMode.unrestricted,
          onWebViewCreated: (WebViewController webViewController) {
            _webViewController.complete(webViewController);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Android Flutter Webview'),
        actions: <Widget>[
          _controller != null ? NavigationControls(_controller) : Container(),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Creating a TextField hidden behind the WebView and adding the input to the Websites input field using Javascript
            Container(
              child: TextField(
                focusNode: _focusNode,
                controller: _textController,
                onChanged: (input) {
                  _controller.evaluateJavascript('''
                    if (window.input != null) {
                      window.input.value = '$input';
                    }''');
                },
              ),
            ),
            WebView(
              initialUrl: 'https://m.usdentaldepot.com',
              javascriptMode: JavascriptMode.unrestricted,
              navigationDelegate: (_) {
                setState(
                  () => _isLoading = true,
                );
                return NavigationDecision.navigate;
              },
              javascriptChannels: Set.from(
                [
                  JavascriptChannel(
                    name: 'Focus',
                    onMessageReceived: (JavascriptMessage focus) {
                      print(focus.message);
                      if (focus.message == 'focus') {
                        FocusScope.of(context).requestFocus(_focusNode);
                      } else if (focus.message == 'focusout') {
                        _textController.text = '';
                        _focusNode.unfocus();
                      }
                    },
                  ),
                  JavascriptChannel(
                    name: 'InputValue',
                    onMessageReceived: (JavascriptMessage value) {
                      print(value.message);
                      setState(() {
                        _textController.text = value.message;
                        _textController.selection = new TextSelection.collapsed(
                          offset: value.message.length,
                        );
                      });
                    },
                  ),
                ],
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onPageFinished: (_) {
                _controller.evaluateJavascript('''
                  window.input = null;
                  document.body.addEventListener('focus', (evt) => {
                    let element = evt.target;
                    if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
                      window.input = element;

                      InputValue.postMessage(input.value);
                      Focus.postMessage('focus');
                    }
                  }, true);
                  document.body.addEventListener('click', (evt) => {
                    let element = evt.target;
                    if (window.input != null && element.tagName !== 'INPUT' && element.tagName !== 'TEXTAREA') {
                      window.input = null;
                      Focus.postMessage('focusout');
                    }
                  }, true);
                ''');
                setState(
                  () => _isLoading = false,
                );
              },
            ), // overlay to show ProgressIndicator while loading.
            _isLoading
                ? Container(
                    color: Colors.white,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Container()
          ],
        ),
      ),
    );
  }
}

class NavigationControls extends StatelessWidget {
  const NavigationControls(this._webViewController);

  final WebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () async {
            if (await _webViewController.canGoBack()) {
              _webViewController.goBack();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () async {
            if (await _webViewController.canGoForward()) {
              _webViewController.goForward();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.replay),
          onPressed: () {
            _webViewController.reload();
          },
        ),
      ],
    );
  }
}
