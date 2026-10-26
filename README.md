# Wallfree

Wallfree is a free, local-first wallpaper app for macOS and Windows. Import pictures from your computer, preview them, save favorites, and apply a static wallpaper across your displays.

## Download and install

Open the [latest GitHub release](https://github.com/Hiteshpariyar/wallfree/releases/latest) and download the installer for your system:

- **macOS:** `Wallfree-macOS.dmg`. Open the disk image, then drag `wallfree.app` into Applications. This build is unsigned; on first launch, macOS may require Control-clicking the app and choosing **Open**.
- **Windows:** `Wallfree-Windows-Setup-<version>.exe`. Run the installer and follow its prompts. The installer is unsigned, so Windows SmartScreen may show its standard warning.

Release installers are built automatically for both platforms when a version tag such as `v1.0.0` is pushed. The repository's **Actions** page also stores installers from regular builds for 30 days.

## Features

- Import JPG, JPEG, PNG, WebP, and BMP images through the system file picker.
- Keep imported images and favorites on your computer between launches.
- Preview and apply a static image using the native desktop wallpaper API.
- No account, ads, subscription, online wallpaper catalog, or telemetry.

The app does not currently support live/video wallpapers, per-display image selection, or an online catalog.

## App icon

Wallfree uses an original landscape-in-a-frame mark created for this project. The design uses a dark rounded tile and a simple high-contrast silhouette; no pixels or logo artwork from the visual reference were reused. The editable vector source is `assets/brand/wallfree-icon.svg`.

## Build from source

This is a Flutter desktop app. Install Flutter and enable desktop support for your target platform.

### macOS

You need macOS and Xcode. In this directory, run:

```sh
flutter pub get
flutter run -d macos
flutter build macos --release
```

### Windows

You need Windows and Visual Studio with the **Desktop development with C++** workload. In PowerShell, run:

```powershell
flutter pub get
flutter run -d windows
flutter build windows --release
```

Windows desktop apps must be built on Windows. The included GitHub Actions workflow builds the macOS disk image and Windows installer on their respective hosted runners.

## Free and local-first

Wallfree's source code and build workflow are free to use. Wallpaper images are stored in the app's local application-support folder. Wallfree has no server component and can be used offline.
