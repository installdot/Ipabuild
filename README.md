# TrollApp

Minimal no-storyboard Swift/UIKit app, built via GitHub Actions with a bundled
`iPhoneOS16.5` SDK, fake-signed with `ldid`, and packaged as an `.ipa` for
sideloading with TrollStore (or any other unsandboxed installer).

## Repo layout

```
TrollApp/
├── Sources/
│   └── main.swift          # AppDelegate + RootViewController (@main entry point)
├── Info.plist
├── entitlements.plist       # no-sandbox / platform-application entitlements
├── iPhoneOS16.5.sdk/        # <-- YOU add this, see below (not included here)
└── .github/workflows/
    └── build.yml
```

## 1. Add the SDK folder

The workflow expects a folder named **`iPhoneOS16.5.sdk`** at the repo root
(same name/path referenced by `SDK_DIR` in `build.yml`). This is Apple's SDK
sysroot (headers + `.tbd` stub libraries), normally found inside an Xcode
install at:

```
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.5.sdk
```

Because this is Apple-copyrighted material, it isn't something I can generate
or bundle for you — you'll need to copy it from your own licensed Xcode
install (Xcode 14.3.1 ships iPhoneOS16.5).

Two ways to get it into CI:

- **Commit it directly** (simplest, but it's a few hundred MB — use
  [Git LFS](https://git-lfs.com) so the repo stays manageable):
  ```
  git lfs install
  git lfs track "iPhoneOS16.5.sdk/**"
  git add .gitattributes iPhoneOS16.5.sdk
  git commit -m "Add iPhoneOS16.5 SDK"
  ```
- **Fetch it at build time** instead of committing it: zip your local SDK,
  upload the zip as a private GitHub Release asset (or private storage you
  control), then add a step in `build.yml` before "Compile Swift sources"
  that downloads and unzips it into `iPhoneOS16.5.sdk/` using a repo secret
  for auth. This keeps the repo itself small and avoids committing Apple's
  files to git history.

## 2. Adjust identifiers

Edit the `env:` block at the top of `.github/workflows/build.yml`:

- `APP_NAME` — must match the executable name in `Info.plist`
- `BUNDLE_ID` — your own reverse-DNS identifier
- `DEPLOYMENT_TARGET` — matches the SDK you're building against (16.5 SDK
  can still target a lower `MinimumOSVersion`, e.g. 14.0, for wider device
  support)

## 3. Push and build

```
git push origin main
```

Or trigger manually: **Actions → Build IPA (Swift + iPhoneOS16.5 SDK) → Run
workflow**.

The finished `TrollApp.ipa` is uploaded as a workflow artifact — download it
from the run's summary page and install via TrollStore.

## Notes

- `ldid -Sentitlements.plist` embeds `entitlements.plist` into the binary
  without needing a real Apple signing certificate — TrollStore's install
  path doesn't validate the signature's trust chain the normal way.
- If your app needs more than one Swift file, just drop them all in
  `Sources/`; `swiftc Sources/*.swift` picks up everything there.
- If you later add Swift Package dependencies, `swiftc` alone won't resolve
  them — you'd switch the compile step to `swift build` with a
  `Package.swift` and a custom SDK destination JSON instead.
