import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('checkPwaCanInstall')
external JSBoolean? _checkPwaCanInstall();

@JS('promptPwaInstallation')
external JSPromise<JSBoolean>? _promptPwaInstallation();

bool _webHasPrompt = false;

void initPwaInstallImpl() {
  try {
    web.window.addEventListener(
      'pwa_install_ready',
      ((web.Event event) {
        _webHasPrompt = true;
      }).toJS,
    );
  } catch (_) {}
}

bool canInstallImpl() {
  try {
    final res = _checkPwaCanInstall();
    return (res?.toDart ?? false) || _webHasPrompt;
  } catch (_) {
    return _webHasPrompt;
  }
}

Future<bool> promptInstallImpl() async {
  try {
    final promise = _promptPwaInstallation();
    if (promise == null) return false;
    final result = await promise.toDart;
    _webHasPrompt = false;
    return result.toDart;
  } catch (_) {
    return false;
  }
}
