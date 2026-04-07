# Batch Installer

A portable Windows app installer you can carry on a USB drive. Pick the apps you want from an interactive menu and install them all in one go — no browser, no manual downloading.

---

## Requirements

- Windows 10 or Windows 11
- Administrator access on the target machine

---

## How to Use

1. Copy both files to your USB drive:
   - `installer.ps1`
   - `run.bat`

2. On the target machine, double-click **run.bat** (as Administrator if prompted)

3. Use the arrow keys to navigate the app list, select what you need, and press Enter to start installing

### Controls

| Key         | Action              |
|-------------|---------------------|
| Up / Down   | Navigate the list   |
| Space       | Toggle selection    |
| A           | Select all / none   |
| Enter       | Start installing    |
| Q           | Quit                |

---

## Supported Apps

| App                  | Category       | Method        |
|----------------------|----------------|---------------|
| Google Chrome        | Browser        | Direct MSI    |
| Microsoft Teams      | Communication  | Bootstrapper  |
| Adobe Creative Cloud | Creative Suite | Direct EXE    |
| TeamViewer           | Remote Access  | Direct EXE    |
| Dropbox              | Cloud Storage  | Direct EXE    |