# Khione — mobile

A touch-first port of Khione (the Godot game in the parent folder): the same story,
the same seven islands, the same riddles and verbs, rebuilt as a lightweight
Three.js game that runs in iPhone Safari, as a Home Screen app, or as a native
iOS app. Art direction, camera and UI skin follow the Whisker Isle Higgsfield PoC.

**Live:** https://khione-islands.higgsfield.app (Higgsfield keeps unpublished
games private — sign in to Higgsfield in the same browser to open it).

## Layout

| Path | What it is |
| --- | --- |
| `app/public/` | **The game.** Static ES modules, no build step. |
| `app/public/js/engine/` | Shared engine: render, input, player, Oreo, world/island base, UI, audio, save, cloud save. |
| `app/public/js/islands/` | One module per island: `ahalo`, `eaton`, `calgary`, `winnipeg`, `pirate`, `englishbay`, `agrea`. |
| `app/public/assets/` | Higgsfield-generated models (meshopt GLB), textures, music and SFX, plus the Godot project's bespoke audio. |
| `app/src/logic.js` | Server side: a single-player cloud-save room (Higgsfield game template). |
| `native/` | Capacitor 6 wrapper → Xcode project for a native iOS build. |
| `design/assets.csv` | Asset manifest (what was generated, how). |
| `tools/` | `extract_clips.py` (animation clips), `package_app.sh` (zip for syncing to Higgsfield). |

## Play locally

```bash
python3 -m http.server 8420 --directory app/public
```

Open http://localhost:8420. Useful query flags: `?debug` (fps overlay + test
harness), `?island=winnipeg` (New Game starts on that island with earlier ones
done), `?slot=name` (separate save slot).

## Native iOS build

```bash
cd native && npm install && npx cap copy ios && npx cap open ios
```

In Xcode: select the **App** target → Signing & Capabilities → pick your team
(a free Apple ID works), plug in your iPhone, press Run. Re-run `npx cap copy ios`
after changing anything in `app/public`.

Capacitor's Swift package is vendored in `native/ios/App/vendor/` so Xcode never
fetches from github.com. Don't run `npx cap sync` / `npx cap update`: they rewrite
`CapApp-SPM/Package.swift` back to the GitHub URL.

## Deploy

The Higgsfield repo lives in Higgsfield's cloud sandbox. `tools/package_app.sh`
zips `app/`; the zip is uploaded, unpacked into the checkout, committed, pushed,
and deployed with the Higgsfield website tools.
