import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  TextInputType _textInputType = TextInputType.text;

  void setInputType(String type) {
    TextInputType inputType = TextInputType.text;
    if (type == 'number') {
      inputType = TextInputType.number;
    } else if (type == 'textarea') {
      inputType = TextInputType.multiline;
    } else if (type == 'email') {
      inputType = TextInputType.emailAddress;
    } else if (type == 'phone') {
      inputType = TextInputType.phone;
    }
    setState(() {
      _textInputType = inputType;
    });
  }

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
          navigationDelegate: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              print('blocking navigation to $request}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
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
      // I use LayoutBuilder to re-size Webview
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Container(
                child: Center(
                  child: Stack(
                    children: <Widget>[
                      // Creating a TextField hidden behind the WebView and adding the input to the Websites input field using Javascript
                      Container(
                        height: 50,
                        width: constraints.maxWidth,
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _textController,
                          onChanged: (input) {
                            _controller.evaluateJavascript('''
                            if (window.input != null) {
                              window.input.value = '$input';
                            }''');
                          },
                          keyboardType: _textInputType,
                        ),
                      ),
                      Container(
                        height: constraints.maxHeight,
                        child: WebView(
                          initialUrl: 'https://pub.dartlang.org/packages/',
                          gestureRecognizers: Set()
                            ..add(
                              Factory<VerticalDragGestureRecognizer>(
                                () => VerticalDragGestureRecognizer(),
                              ),
                            ),
                          navigationDelegate: (_) {
                            _focusNode.unfocus();
                            setState(
                              () => _isLoading = true,
                            );
                            return NavigationDecision.navigate;
                          },
                          javascriptMode: JavascriptMode.unrestricted,
                          javascriptChannels: Set.from(
                            [
                              // Listening for Javascript messages to get Notified of Focuschanges, the current input Value and Type of the Textfield.
                              JavascriptChannel(
                                name: 'Focus',
                                onMessageReceived: (JavascriptMessage focus) {
                                  // get notified of focus changes on the input field and open/close the Keyboard.
                                  if (focus.message == 'focus') {
                                    FocusScope.of(context)
                                        .requestFocus(_focusNode);
                                  } else if (focus.message == 'focusout') {
                                    setState(() {
                                      _textController.text = '';
                                    });
                                    _focusNode.unfocus();
                                  }
                                },
                              ),
                              JavascriptChannel(
                                name: 'InputValue',
                                onMessageReceived: (JavascriptMessage value) {
                                  // set the value of the native input field to the one on the website to always make sure they have the same input.
                                  setState(() {
                                    _textController.text = value.message;
                                    _textController.selection =
                                        new TextSelection.collapsed(
                                      offset: value.message.length,
                                    );
                                  });
                                },
                              ),
                              JavascriptChannel(
                                name: 'InputType',
                                onMessageReceived: (JavascriptMessage type) {
                                  // set the type of the native input field to the one on the website to display a similar keyboard type.
                                  setInputType(type.message);
                                },
                              ),
                            ],
                          ),
                          onWebViewCreated: (controller) =>
                              _controller = controller,
                          onPageFinished: (_) {
                            /*
                            I user "event delegation" to capture the focus and focusout
                            on ALL inputs/textareas
                            */
                            _controller.evaluateJavascript('''
                              window.input = null;
                              document.body.addEventListener('focus', (evt) => {
                                let element = evt.target;
                                if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
                                  window.input = element;
                                  InputType.postMessage(input.type);
                                  InputValue.postMessage(input.value);
                                  Focus.postMessage('focus');
                                }
                              }, true);
                              document.body.addEventListener('focusout', (evt) => {
                                let element = evt.target;
                                if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA') {
                                  window.input = null;
                                  Focus.postMessage('focusout');
                                }
                              }, true);
                            ''');
                            setState(
                              () => _isLoading = false,
                            );
                          },
                        ),
                      ),
                      // overlay to show ProgressIndicator while loading.
                      _isLoading
                          ? Container(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Center(
                                child: CircularProgressIndicator(
                                  backgroundColor: Colors.cyan,
                                ),
                              ),
                            )
                          : Container()
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
