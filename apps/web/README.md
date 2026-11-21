# BMC Sathi · Roads (web app)

The Flutter web client for BMC Sathi. Setup, running and tests are in the [root README](../../README.md).

```bash
flutter run -d web-server --web-port 5173 --web-hostname localhost
flutter test
flutter analyze
```

## Brand assets

- The mark is a teal (`#0E6F66`) rounded square with two road edges and a dashed centre line. It is not a BMC crest, logo or seal (see `design/DESIGN.md`).
- `web/favicon.svg` is the source drawing. The `LogoMark` widget in `lib/core/widgets.dart` draws the same shape in the app.
- `web/favicon.png` (32 px) and `web/icons/*.png` are rendered from that SVG. The maskable icons keep the mark inside the safe zone, and `apple-touch-icon.png` has a full teal background with square corners because iOS rounds the corners itself.
