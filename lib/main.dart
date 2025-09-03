import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'theme.dart';

WebViewEnvironment? webViewEnvironment;

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    assert(availableVersion != null,
        'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.');

    webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: 'YOUR_CUSTOM_PATH'));
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(MaterialApp(home: const MyApp(), debugShowCheckedModeBanner: false, theme: theme));
  
  doWhenWindowReady(() {
    const initialSize = Size(1200, 800);
    appWindow.minSize = const Size(800, 600);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "";
    appWindow.show();
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class TabData {
  GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? controller;
  String url = "";
  double progress = 0;
  
  TabData({this.url = "https://search.brave.com"});
}

class _MyAppState extends State<MyApp> {
  List<TabData> tabs = [TabData()];
  int currentTabIndex = 0;
  bool showTabs = true;
  
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  final urlController = TextEditingController();
  
  TabData get currentTab => tabs[currentTabIndex];
  InAppWebViewController? get webViewController => currentTab.controller;
  String get url => currentTab.url;
  double get progress => currentTab.progress;

  @override
  void initState() {
    super.initState();

    pullToRefreshController = kIsWeb ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );
  }

  void createNewTab() {
    setState(() {
      tabs.add(TabData());
      currentTabIndex = tabs.length - 1;
      urlController.text = currentTab.url;
    });
  }
  
  void switchToTab(int index) {
    setState(() {
      currentTabIndex = index;
      urlController.text = currentTab.url;
    });
  }
  
  void closeTab(int index) {
    setState(() {
      if (tabs.length > 1) {
        tabs.removeAt(index);
        if (currentTabIndex >= tabs.length) {
          currentTabIndex = tabs.length - 1;
        }
        urlController.text = currentTab.url;
      }
    });
  }

  void goBack() {
    webViewController?.goBack();
  }

  void goForward() {
    webViewController?.goForward();
  }

  void refresh() {
    webViewController?.reload();
  }

  void toggleTabs() {
    setState(() {
      showTabs = !showTabs;
    });
  }

  bool handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrl = event.logicalKey == LogicalKeyboardKey.controlLeft ||
                     event.logicalKey == LogicalKeyboardKey.controlRight;
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

      if (isCtrlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyT) {
          createNewTab();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyZ) {
          goBack();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
          refresh();
          return true;
        }
      }
    }
    return false;
  }
  
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): createNewTab,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): goBack,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): refresh,
        const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true): toggleTabs,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              Container(
                height: 30,
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: MoveWindow(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 20,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).colorScheme.secondary),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: TextField(
                                    controller: urlController,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Search or enter URL',
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    onSubmitted: (value) {
                                      var url = WebUri(value);
                                      if (url.scheme.isEmpty) {
                                        url = WebUri("https://search.brave.com/search?q=$value");
                                      }
                                      webViewController?.loadUrl(urlRequest: URLRequest(url: url));
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        MinimizeWindowButton(),
                        MaximizeWindowButton(),
                        CloseWindowButton(),
                      ],
                    ),
                  ],
                ),
              ),
              if (tabs.length > 1 && showTabs)
                Container(
                  height: 28,
                  color: Theme.of(context).colorScheme.primary,
                  child: Row(
                    children: [
                      ...tabs.asMap().entries.map((entry) {
                        int index = entry.key;
                        TabData tab = entry.value;
                        bool isActive = index == currentTabIndex;
                        
                        return Container(
                          constraints: const BoxConstraints(maxWidth: 200),
                          decoration: BoxDecoration(
                            color: isActive ? Theme.of(context).colorScheme.surface : Colors.transparent,
                            border: Border(
                              right: BorderSide(color: Theme.of(context).colorScheme.secondary),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => switchToTab(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Text(
                                      tab.url.isEmpty ? 'New Tab' : 
                                        (tab.url.length > 30 ? '${tab.url.substring(0, 30)}...' : tab.url),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isActive ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              if (tabs.length > 1)
                                GestureDetector(
                                  onTap: () => closeTab(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.close, size: 12, color: Colors.grey.shade600),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      GestureDetector(
                        onTap: createNewTab,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Icon(Icons.add, size: 14, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: currentTabIndex,
                  children: tabs.map((tab) => Stack(children: [
                    InAppWebView(
                      key: tab.webViewKey,
                      webViewEnvironment: webViewEnvironment,
                      initialUrlRequest:
                          URLRequest(url: WebUri(tab.url)),
                      initialSettings: settings,
                      pullToRefreshController: pullToRefreshController,
                      onWebViewCreated: (controller) {
                        tab.controller = controller;
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          tab.url = url.toString();
                          if (tabs.indexOf(tab) == currentTabIndex) {
                            urlController.text = tab.url;
                          }
                        });
                      },
                      onPermissionRequest: (controller, request) async {
                        return PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.GRANT);
                      },
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        var uri = navigationAction.request.url!;

                        if (![
                          "http",
                          "https",
                          "file",
                          "chrome",
                          "data",
                          "javascript",
                          "about"
                        ].contains(uri.scheme)) {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                            return NavigationActionPolicy.CANCEL;
                          }
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                      onLoadStop: (controller, url) async {
                        pullToRefreshController?.endRefreshing();
                        setState(() {
                          tab.url = url.toString();
                          if (tabs.indexOf(tab) == currentTabIndex) {
                            urlController.text = tab.url;
                          }
                        });
                      },
                      onReceivedError: (controller, request, error) {
                        pullToRefreshController?.endRefreshing();
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          pullToRefreshController?.endRefreshing();
                        }
                        setState(() {
                          tab.progress = progress / 100;
                        });
                      },
                      onUpdateVisitedHistory: (controller, url, androidIsReload) {
                        setState(() {
                          tab.url = url.toString();
                          if (tabs.indexOf(tab) == currentTabIndex) {
                            urlController.text = tab.url;
                          }
                        });
                      },
                      onConsoleMessage: (controller, consoleMessage) {
                        if (kDebugMode) {
                          print(consoleMessage);
                        }
                      },
                    ),
                    if (tab.progress < 1.0)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(value: tab.progress),
                      ),
                  ])).toList(),
                ),
              ),
             ],
          ),
          ),
        ),
    );
 }
}