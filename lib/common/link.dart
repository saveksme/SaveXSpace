import 'dart:async';

import 'package:app_links/app_links.dart';

import 'print.dart';

typedef InstallConfigCallBack = void Function(String url);

class LinkManager {
  static LinkManager? _instance;
  late AppLinks _appLinks;
  StreamSubscription? subscription;

  LinkManager._internal() {
    _appLinks = AppLinks();
  }

  void _handleUri(Uri uri, Function(String url) callback) {
    commonPrint.log('onAppLink raw: $uri');
    commonPrint.log('onAppLink scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}, query: ${uri.query}');
    commonPrint.log('onAppLink queryParameters: ${uri.queryParameters}');
    // Support both xspace://install-config?url=X and xspace://install-config/url=X formats
    if (uri.host == 'install-config' || uri.path.contains('install-config')) {
      final parameters = uri.queryParameters;
      final url = parameters['url'];
      commonPrint.log('onAppLink url param: $url');
      if (url != null && url.isNotEmpty) {
        callback(url);
      }
    }
  }

  Future<void> initAppLinksListen(
      Function(String url) installConfigCallBack) async {
    commonPrint.log('initAppLinksListen');
    destroy();
    // Handle initial link (app launched via deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, installConfigCallBack);
      }
    } catch (_) {}
    // Handle subsequent links (app already running)
    subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri, installConfigCallBack),
    );
  }

  void destroy() {
    if (subscription != null) {
      subscription?.cancel();
      subscription = null;
    }
  }

  factory LinkManager() {
    _instance ??= LinkManager._internal();
    return _instance!;
  }
}

final linkManager = LinkManager();
