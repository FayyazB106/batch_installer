# Batch Installer

A portable app installer you can carry on a USB drive. Pick the apps you want from an interactive menu and install them all in one go — no browser, no manual downloading. Works on **Windows** and **macOS**.

---

## Requirements

### Windows
- Windows 10 or Windows 11
- Administrator access on the target machine

### macOS
- macOS 14 (Sonoma) or later for Microsoft Outlook and Office 365; other apps work on older versions
- Admin password (prompted once at the start of installation)

---

## How to Use

### Windows

1. Copy the `windows` folder to your USB drive (contains `installer.ps1` and `run.bat`)

2. On the target machine, double-click **run.bat** (as Administrator if prompted)

3. Use the arrow keys to navigate the app list, select what you need, and press Enter to start installing

### macOS

1. Copy the `macOS` folder to your USB drive (contains `installer.sh` and `run.command`)

2. On the target machine, double-click **run.command** (enter your password when prompted)

3. Type a number to toggle an app, then press Enter to start installing

### Controls

#### Windows

| Key         | Action              |
|-------------|---------------------|
| Up / Down   | Navigate the list   |
| Space       | Toggle selection    |
| A           | Select all / none   |
| Enter       | Start installing    |
| Q           | Quit                |

#### macOS

| Key         | Action              |
|-------------|---------------------|
| 1-7         | Toggle an app       |
| A           | Select all / none   |
| Enter       | Start installing    |
| Q           | Quit                |

---

## Supported Apps

### Windows

| App                  | Category       | Method        |
|----------------------|----------------|---------------|
| Google Chrome        | Browser        | Direct MSI    |
| Microsoft Teams      | Communication  | Bootstrapper  |
| Adobe Creative Cloud | Creative Suite | Direct EXE    |
| TeamViewer           | Remote Access  | Direct EXE    |
| Dropbox              | Cloud Storage  | Direct EXE    |
| Microsoft Outlook    | Email          | Direct EXE    |
| Microsoft Office 365 | Productivity   | Direct EXE    |

### macOS

| App                  | Category       | Method        |
|----------------------|----------------|---------------|
| Google Chrome        | Browser        | DMG           |
| Microsoft Teams      | Communication  | PKG           |
| Adobe Creative Cloud | Creative Suite | DMG           |
| TeamViewer           | Remote Access  | DMG           |
| Dropbox              | Cloud Storage  | DMG           |
| Microsoft Outlook    | Email          | PKG*          |
| Microsoft Office 365 | Productivity   | PKG*          |

\* Requires macOS 14 (Sonoma) or later. The installer will skip these with a message on older versions.

---

## Notes

### Windows
- If an app installs successfully but requires a reboot, the UI will show **"Installed, reboot required to finish"** and mark it as `[OK]` with a note
- If an app is already installed, the UI will show **"Already installed"** and mark it as `[WARN]`

### macOS
- Downloads that fail mid-way will automatically retry up to 3 times
- Apps that require a newer macOS version will be skipped before downloading