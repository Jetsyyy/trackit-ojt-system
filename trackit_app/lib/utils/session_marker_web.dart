// Web: sessionStorage survives a page reload but is cleared when the tab
// or browser is closed. Same dart:html approach as file_download_web.dart.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _key = 'trackit_session_active';

void setSessionMarker() {
  try {
    html.window.sessionStorage[_key] = '1';
  } catch (_) {
    // Storage blocked (private mode etc.) -- the login still works for
    // this page; it just won't survive a reload.
  }
}

bool hasSessionMarker() {
  try {
    return html.window.sessionStorage[_key] == '1';
  } catch (_) {
    return false;
  }
}
