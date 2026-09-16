# UTUVO Paw

The uninstaller with paws. Drop an app in, the cat sniffs out every leftover file
(caches, preferences, support folders, saved state, containers, launch agents…),
then knocks them all off the desk — straight into the Trash. Nothing is deleted permanently.

Free, open source, MIT. macOS 14+.

## Build

```bash
bash scripts/build-app.sh          # → build/UTUVO Paw.app (ad-hoc signed)
open "build/UTUVO Paw.app"
```

```bash
swift test                          # matcher + safety tests
```

## How it decides what belongs to an app

- **Bundle identifier** must appear as a whole token: `com.acme.cliply`, `com.acme.cliply.plist`,
  `group.com.acme.cliply`, `com.acme.cliply.helper` all match; `com.acme.cliplypro` does not.
- **App name / executable name** match only exactly or as `Name.ext` / `Name-…`.
  Plain substring matches are never used, so `Music` does not eat `MusicBrainz`.
- Scanned roots: `~/Library/{Application Support, Caches, Preferences, Preferences/ByHost,
  Saved Application State, Containers, Group Containers, Application Scripts, Logs,
  HTTPStorages, WebKit, Cookies, LaunchAgents, Autosave Information}` and the matching
  `/Library/…` roots. Items under `/Library` are listed but never touched (badge **admin**).
- Everything goes through `FileManager.trashItem`. Paths outside `~/Library`, `/Library`
  or an `.app` bundle are refused by `Trasher.isSafe`.

## Layout

```
Sources/UTUVOPaw/   SwiftUI app (PawApp, ContentView, PawModel, LeftoverScanner, AppInspector)
Sources/UTUVOPaw/Assets/   cat art (PNG)
Resources/          Info.plist, AppIcon.icns
scripts/build-app.sh
Tests/              Matcher, Trasher safety, AppInspector
```
