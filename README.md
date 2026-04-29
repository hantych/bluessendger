# 👻 Ghost Mesh

A peer-to-peer Bluetooth/Wi-Fi messenger for Android.

- **No accounts.** No sign-up, no email, no phone number.
- **No servers.** Phones talk to each other directly using Google Nearby Connections.
- **Auto-discovery.** Open the app on two phones — they find each other automatically.
- **Device-name nicknames.** Your model name (e.g. "Pixel 7") is what others see.
- **Range:** about 30–100 meters, works fully offline.
- **Special feature — Ghost messages 👻:** toggle the ghost mode and your message
  is wiped from both phones the moment they go out of range.

## How to build the APK (5 minutes, no programming)

You will use **GitHub Actions** to compile the APK in the cloud — you do not
need to install Android Studio, Java, Flutter, or anything else.

### 1. Create a GitHub repository
1. Go to <https://github.com> and sign in (or sign up).
2. Click the **New** button (top-right ➕).
3. Name it `ghost-mesh`, choose **Public** or **Private**, click **Create repository**.

### 2. Upload the project files
1. On your new repository page, click **Add file → Upload files**.
2. **Drag the entire `ghost_mesh` folder content** into the upload area.
   GitHub will keep the folder structure.
3. ⚠️ Make sure the `.github/workflows/build.yml` file uploaded —
   if not, create it manually: *Add file → Create new file*, type
   `.github/workflows/build.yml` as the path, paste the YAML contents.
4. Scroll down, type a commit message ("initial commit"), click **Commit changes**.

### 3. Wait for the APK
1. Open the **Actions** tab at the top of the repo.
2. You will see a workflow named **Build APK** running (yellow circle).
3. Wait 5–15 minutes until it turns green ✅.
4. Click the finished workflow → scroll down → under **Artifacts** click
   `ghost-mesh-apk` → it downloads as a `.zip`.
5. Unzip it. Inside is `app-release.apk`.

### 4. Install the APK on your phone
1. Transfer the `.apk` to your Android phone (Telegram-to-self,
   Google Drive, USB cable — anything works).
2. Open the file on the phone.
3. Android will warn about "unknown sources" — tap **Settings**, allow
   the app you opened the file from to install APKs, return.
4. Tap **Install**.
5. On first launch, grant Bluetooth, Location, and Nearby Devices permissions.

### 5. Test it
1. Install the APK on **two phones** that are within ~30 m of each other.
2. Open the app on both — Bluetooth and Location must be ON.
3. Within ~30 seconds the phones should appear on each other's radar.
4. Tap the connected peer → start chatting.

## Troubleshooting

| Problem | Fix |
|---|---|
| Workflow fails on GitHub | Open the failed run → click the failing step → copy the error → paste back to your AI helper for a fix |
| Phones don't see each other | Both must have Bluetooth + Location ON; Android 12+ also needs the "Nearby devices" permission granted in app settings |
| "App not installed" on phone | Either the existing version is signed with a different key (uninstall the old one first), or your phone blocks debug-signed APKs (allow in settings) |
| Connection drops constantly | Some Chinese OEM ROMs (Xiaomi/MIUI, Huawei/EMUI) aggressively kill background apps — disable battery optimization for Ghost Mesh |

## Known limitations

- **Android only.** iOS support would require a complete rewrite — Apple
  doesn't expose the equivalent peer-to-peer APIs in the same way.
- **No encryption.** Messages travel in cleartext over Nearby Connections.
  This is by design (per the original requirements).
- **No internet.** This build only does local peer-to-peer. Adding internet
  fallback would require a signaling server, which contradicts the
  "no servers" requirement.
- **No multi-hop mesh.** Messages only reach phones within direct radio range
  of you. True mesh forwarding (relaying through other phones) is not
  implemented in this version.

## Architecture

```
lib/
├── main.dart                       — entry point + permissions gate
├── models/
│   ├── peer.dart                   — discovered device data class
│   └── message.dart                — chat message + wire format
├── services/
│   ├── mesh_service.dart           — Google Nearby Connections wrapper
│   ├── storage_service.dart        — SQLite chat history
│   └── notification_service.dart   — local push notifications
├── providers/
│   └── app_provider.dart           — central state (peers, messages, log)
├── screens/
│   ├── radar_screen.dart           — main screen with radar visualisation
│   ├── chat_screen.dart            — 1-on-1 chat
│   └── settings_screen.dart        — name + activity log
└── widgets/
    └── radar_painter.dart          — CustomPainter for the radar
```

## License

MIT — do whatever you want.
