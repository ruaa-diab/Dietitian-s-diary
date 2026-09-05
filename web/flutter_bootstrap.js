// Loads the app from the CanvasKit bundled into this build rather than
// from Google's CDN, which is what Flutter reaches for by default.
//
// Two reasons: the page then has no third-party dependency to be slow,
// blocked or unreachable on whatever network it is opened from, and a
// failed CDN fetch takes the whole app down with it — a blank white page,
// no error, nothing to act on. The files are already in this build; this
// just points at them.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
