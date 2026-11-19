// Non-web: the marker is kept in memory, so it is gone on the next cold
// start of the app.
bool _marker = false;

void setSessionMarker() => _marker = true;

bool hasSessionMarker() => _marker;
