{{flutter_js}}
{{flutter_build_config}}

// Keep the renderer and fallback font requests on the app's own origin.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
    fontFallbackBaseUrl: new URL('assets/fonts/', document.baseURI).href,
  },
});
