# Winou mobile app

Flutter app (Android first; iOS builds but is untested). Riverpod for state, go_router
for navigation, `flutter_map` + OpenStreetMap, English and French.

## Run on your phone

The app needs `android/app/google-services.json` (Firebase console → Project settings → your
Android app `tn.winou.winou` → download). It is kept out of git.

1. Start the backend: `docker compose up -d` from the repo root.
2. Find the laptop's Wi-Fi address (`ipconfig` → "Wireless LAN adapter Wi-Fi" → IPv4),
   and put the phone on the same Wi-Fi.
3. On the phone: enable Developer options (tap *Build number* 7 times), then
   *USB debugging*. Plug it in and accept the prompt. `flutter devices` should list it.
4. Run, pointing the app at the laptop:

```bash
cd mobile
flutter run --dart-define=API_URL=http://192.168.1.14:8080
```

Without a cable: `flutter build apk --debug --dart-define=API_URL=http://<ip>:8080`, then
copy `build/app/outputs/flutter-apk/app-debug.apk` to the phone and install it.

Check the phone can reach the API by opening `http://<ip>:8080/health` in its browser.
Debug builds allow plain HTTP; release builds will need HTTPS.

### If the phone can't reach the laptop over Wi-Fi

Many routers (and every guest network) isolate Wi-Fi clients from each other. Go through
the USB cable instead: `adb reverse` makes the phone's `localhost:8080` lead to the laptop.

```bash
adb reverse tcp:8080 tcp:8080     # redo after unplugging or rebooting the phone
flutter run --dart-define=API_URL=http://127.0.0.1:8080
```

`adb` is in `%LOCALAPPDATA%\Android\Sdk\platform-tools`.

### Changing the server address in the app

The address the app is built with (`API_URL`) can be changed without rebuilding: the gear on the
sign-in screen, or My activity → ⋮ → Server address. Handy when the laptop's address changes
(phone hotspot, another Wi-Fi). Release builds allow plain HTTP for that reason (see the
manifest). For demos, see [docs/DEMO.md](../docs/DEMO.md).

## Design

Colours, fonts and component styles live in `lib/theme.dart`. Blue is the brand colour; the
others carry meaning everywhere, map markers included: coral = lost, blue = sighting,
amber = stray, green = found or confirmed, red = injured. The font is Nunito (SIL Open Font
License, bundled in `assets/fonts`). Reusable animations (staggered fade-in, the similarity ring,
the pulse on injured animals) are in `lib/widgets/animations.dart`.

The app icon is drawn by `tool/make_icon.py` (needs Pillow):

```bash
python tool/make_icon.py assets/icon
dart run flutter_launcher_icons
```

## Structure

```
lib/
  api/          API client, JSON models, Riverpod providers
  auth/         sign in / register, token kept in secure storage
  map/          main map with filters
  sightings/    camera-first sighting flow, sighting details
  reports/      lost report form and details
  me/           my activity (matches, my reports, my sightings), match details
  chat/         messages between owner and finder
  push.dart     push notifications: registration, opening the right screen from a notification
  widgets/      shared UI: photos, upload + "retake?" flow, map pickers
  l10n/         app_en.arb, app_fr.arb (generated code: flutter gen-l10n)
```

## Checks

```bash
flutter analyze
flutter test
```

## Comparing with the designs

`tool/screenshots/` renders every designed screen in light and dark with sample data, no backend
or phone needed, then puts each next to its design from `design/winou-screens.html`:

```bash
flutter test tool/screenshots --update-goldens   # tool/screenshots/out/*.png
python tool/screenshots/compare.py               # tool/screenshots/out/compare/*.png (needs Edge)
```
