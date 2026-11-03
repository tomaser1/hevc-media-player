# HEVC Media Player for Windows

A free, one-click setup for a Windows media player that plays **every video, audio and image format**, including HEVC/H.265, so you don't need to buy Microsoft's HEVC Video Extension.

It installs [mpv](https://mpv.io), which uses FFmpeg for decoding, with settings tuned so videos play:

- **At the correct resolution.** Videos open at their native pixel size. Only videos larger than your screen are shrunk to fit.
- **At the correct frame rate.** Playback is locked to your monitor's refresh rate (`video-sync=display-resample`), so 23.976, 24, 25, 50 and 60 fps play without stutter, and no fake frames are added.
- **With HDR handled properly.** HDR is passed through when Windows HDR is on, and tone-mapped to look right on SDR screens otherwise.

It also adds:

- A **control bar** ([uosc](https://github.com/tomasklaen/uosc)) with previous/next file, back/forward 10 s, play/pause, loop, speed, subtitle and audio-track pickers, volume and fullscreen.
- A **time bar** at the bottom. Click it to jump to that point, or hover over it to see the time there.
- An **info popup** when a file opens, showing the codec, resolution, fps, HDR type and whether the GPU or the CPU is decoding. Press `Shift+I` to show it again.
- Desktop and Start menu shortcuts, and registration as a video/audio player so you can set it as the default.

## Install

1. Download [`install.ps1`](install.ps1). Click **Download raw file** on its page.
2. Open **Windows PowerShell** and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\install.ps1"
   ```

3. Click **Yes** when Windows asks for admin permission. That step registers mpv as a player.
4. Right-click a video and choose **Open with → Choose another app → mpv → Always**.

To update, run the script again.

## Controls

| Action | Mouse | Keyboard |
|---|---|---|
| Play / pause | Click the video | `Space` |
| Seek | Click the time bar | `←` / `→` 5 s, `↑` / `↓` 1 min |
| Fullscreen | Double-click | `F` |
| Volume | Mouse wheel | `9` / `0` |
| Menu (tracks, speed…) | Right-click | |
| File info | | `Shift+I` |
| Screenshot (saved to your desktop) | | `S` |
| Quit | | `Q` |

## What gets installed where

| Path | Contents |
|---|---|
| `%LOCALAPPDATA%\Programs\mpv` | mpv itself (the latest build from [shinchiro/mpv-winbuild-cmake](https://github.com/shinchiro/mpv-winbuild-cmake)) |
| `%APPDATA%\mpv` | Settings (`mpv.conf`, `input.conf`), the uosc control bar and the file-info script |

**Uninstall:** run `installer\mpv-uninstall.bat` inside the mpv folder as administrator, then delete both folders above.
