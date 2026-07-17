# معماری آبتین (تکمیل‌شده)

## لایه‌ها
```
lib/
  core/
    bootstrap.dart          # DB + routing + TTS init
    database/               # SQLCipher + migration
    native/                 # GraphHopper/Valhalla MethodChannel
    services/               # routing, geocoding, location, tts, tiles
    ai/                     # smart offline ETA/preference
    deeplink/ platform/ security/ theme/ providers/ widgets/
  features/
    navigation/             # controller, map, AR hooks, hazards, lane
    routing/                # A*, Kalman, settings UI
    maps/                   # graph JSON loader
    search/ favorites/ voice/ settings/ ar/
android/…/MainActivity.kt   # native channel stubs
ios/Runner/AppDelegate.swift
```

## جریان مسیر
1. `RoutingService.route` → native engine اگر آماده
2. وگرنه `OfflineRoutingEngine` (A*) روی گراف asset/JSON
3. `NavigationController.startRoute` → follow + TTS + car projection
4. GPS sample → map-match؛ انحراف >45m → `reroute()` آفلاین
5. `HazardMonitor` از SQLite هشدار می‌دهد

## داده
- SQLCipher file: favorites, history, maps, settings, hazards
- Assets: graph, POIs, GLB, fonts, gauges
- Tile cache: flutter_map_tile_caching (download once)

## تست
`flutter test` — routing, DB, deeplink, voice commands, widget smoke
