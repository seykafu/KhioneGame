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

## TestFlight (install on your iPhone)

`.github/workflows/khione-ios-testflight.yml` builds the app on GitHub's macOS
runners (latest Xcode) and uploads it to TestFlight on every push that touches
the game or the native project, or on demand from the Actions tab. One-time setup:

1. Join the Apple Developer Program (developer.apple.com/programs).
2. App Store Connect → Apps → **+ New App**: platform iOS, name "Khione",
   bundle ID `com.kasey.khione` (register it under Certificates, Identifiers &
   Profiles → Identifiers first if it isn't offered). Any unique SKU.
3. App Store Connect → Users and Access → Integrations → **App Store Connect API**
   → generate a key with **Admin** access. Note the Key ID and Issuer ID and
   download the `.p8` file (it can only be downloaded once).
4. GitHub → KhioneGame → Settings → Secrets and variables → Actions → add
   `APPLE_TEAM_ID` (Membership details page), `ASC_KEY_ID`, `ASC_ISSUER_ID`, and
   `ASC_KEY_P8` (paste the whole `.p8` file). If you used a different bundle ID,
   add a repository *variable* `IOS_BUNDLE_ID`.
5. Actions → **Khione iOS → TestFlight** → Run workflow. About 15 minutes later
   the build appears in App Store Connect → TestFlight; add yourself as an
   internal tester, then install from the TestFlight app on your iPhone.

Until the secrets exist, the workflow skips the build and passes.

## Deploy

The Higgsfield repo lives in Higgsfield's cloud sandbox. `tools/package_app.sh`
zips `app/`; the zip is uploaded, unpacked into the checkout, committed, pushed,
and deployed with the Higgsfield website tools.
