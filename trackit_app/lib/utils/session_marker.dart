import 'session_marker_stub.dart'
    if (dart.library.html) 'session_marker_web.dart' as impl;

/// A flag that lives only as long as the current browser tab (web:
/// sessionStorage) or the current app run (mobile: memory). Used by
/// "Remember me": when it's off, a stored login is only trusted while this
/// marker is still set, so closing the browser/app logs the user out.
void setSessionMarker() => impl.setSessionMarker();

bool hasSessionMarker() => impl.hasSessionMarker();
