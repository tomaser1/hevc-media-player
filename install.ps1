# ============================================================================
#  Free "plays everything" media player for Windows (mpv + FFmpeg)
#  - HEVC/H.265, AV1, VP9, H.264, ProRes, DNxHD, MKV/MP4/MOV/AVI/TS/WEBM...
#  - Every audio format, plus images (JPG/PNG/WEBP/AVIF/HEIC/GIF)
#  - Native resolution, frame-accurate fps (display-resample), HDR aware
#  - Shows codec / resolution / fps / HDR on screen when a file opens
#  No Microsoft Store extensions needed - all decoders are built in.
#
#  Run:  right-click this file -> "Run with PowerShell"
# ============================================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # makes downloads much faster

$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\mpv'
$ConfigDir  = Join-Path $env:APPDATA 'mpv'
$TempDir    = Join-Path $env:TEMP ('mpv-setup-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $InstallDir, $ConfigDir, "$ConfigDir\scripts", $TempDir | Out-Null

Write-Host "`n== 1/5  Finding the latest mpv build ==" -ForegroundColor Cyan
$rel   = Invoke-RestMethod 'https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest' `
           -Headers @{ 'User-Agent' = 'mpv-setup-script' }
$asset = $rel.assets | Where-Object { $_.name -match '^mpv-x86_64-\d{8}-git-[0-9a-f]+\.7z$' } | Select-Object -First 1
if (-not $asset) { throw "Couldn't find a Windows x64 build in the latest release. Get it manually from https://github.com/shinchiro/mpv-winbuild-cmake/releases" }
Write-Host "   $($asset.name)"

Write-Host "`n== 2/5  Downloading & extracting ==" -ForegroundColor Cyan
$archive = Join-Path $TempDir $asset.name
Invoke-WebRequest $asset.browser_download_url -OutFile $archive

function Find-7z {
  foreach ($p in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) { if (Test-Path $p) { return $p } }
  return $null
}
$extracted = $false
$sevenZip = Find-7z
if (-not $sevenZip) {
  # Windows 11 23H2+ tar.exe understands .7z
  & tar.exe -xf $archive -C $InstallDir 2>$null
  if ($LASTEXITCODE -eq 0 -and (Test-Path "$InstallDir\mpv.exe")) { $extracted = $true }
  else {
    Write-Host "   Installing 7-Zip (free) to unpack the archive..."
    winget install --id 7zip.7zip -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
    $sevenZip = Find-7z
    if (-not $sevenZip) { throw "Please install 7-Zip from https://7-zip.org and run this script again." }
  }
}
if (-not $extracted) { & $sevenZip x $archive "-o$InstallDir" -y | Out-Null }
if (-not (Test-Path "$InstallDir\mpv.exe")) { throw "Extraction failed - mpv.exe not found in $InstallDir" }

function Write-Text([string]$Path, [string]$Text, [switch]$Append) {
  # Write UTF-8 *without* BOM - mpv/Lua choke on the BOM PowerShell 5 adds
  $enc = New-Object System.Text.UTF8Encoding($false)
  if ($Append) { [IO.File]::AppendAllText($Path, "`r`n" + $Text, $enc) } else { [IO.File]::WriteAllText($Path, $Text, $enc) }
}

Write-Host "`n== 3/5  Writing tuned config ==" -ForegroundColor Cyan
@'
# ---------- Rendering ----------
vo=gpu-next
profile=high-quality
hwdec=auto-safe              # GPU decoding for HEVC/AV1/VP9 when available, falls back to software

# ---------- Correct resolution ----------
# Videos open at their native pixel size (1:1). Only videos bigger than
# your screen are shrunk to fit. Press F for fullscreen.
autofit-larger=95%x95%
keepaspect=yes
hidpi-window-scale=no        # don't let Windows display scaling enlarge/blur the video

# ---------- Correct fps / smooth playback ----------
# Locks playback to your monitor's refresh so 23.976/24/25/29.97/50/60fps
# play without judder or dropped/duplicated frames.
video-sync=display-resample
interpolation=no             # no fake "soap opera" frames - original frames only
tscale=oversample

# ---------- HDR ----------
target-colorspace-hint=yes   # pass HDR through if Windows HDR is on
tone-mapping=auto            # otherwise tone-map nicely to SDR
hdr-compute-peak=yes

# ---------- Images ----------
image-display-duration=inf   # photos stay up until you move on

# ---------- Behaviour ----------
keep-open=yes                # don't close at the end of a file
save-position-on-quit=yes    # resume where you left off
osd-font-size=32
screenshot-format=png
screenshot-directory=~~desktop/
'@ | ForEach-Object { Write-Text "$ConfigDir\mpv.conf" $_ }

@'
-- Shows codec, resolution, fps and HDR info when a file opens.
-- Press "I" (shift+i) at any time to see it again.
local function info()
  local p = mp.get_property_native("video-params")
  if not p then
    local codec = mp.get_property("current-tracks/audio/codec") or "?"
    local sr = mp.get_property_number("audio-params/samplerate") or 0
    local ch = mp.get_property("audio-params/channel-count") or "?"
    mp.osd_message(string.format("Audio: %s  %d Hz  %s ch", codec:upper(), sr, ch), 4)
    return
  end
  local codec = (mp.get_property("current-tracks/video/codec") or "?"):upper()
  local fps   = mp.get_property_number("container-fps") or mp.get_property_number("estimated-vf-fps")
  local disp  = mp.get_property_number("display-fps")
  local hdr   = ""
  if p.gamma == "pq" then hdr = "  HDR10 (PQ)" elseif p.gamma == "hlg" then hdr = "  HDR (HLG)" end
  if mp.get_property("current-tracks/video/image") == "yes" or (fps and fps <= 1) then
    mp.osd_message(string.format("%s  %d x %d%s", codec, p.w, p.h, hdr), 4)
    return
  end
  local hw = mp.get_property("hwdec-current") or "no"
  mp.osd_message(string.format("%s  %d x %d  @ %.3f fps%s\nMonitor: %s Hz   Decoder: %s",
    codec, p.w, p.h, fps or 0, hdr,
    disp and string.format("%.2f", disp) or "?",
    (hw == "no" or hw == "") and "software (FFmpeg)" or ("GPU " .. hw)), 5)
end
mp.register_event("file-loaded", function() mp.add_timeout(0.5, info) end)
mp.add_key_binding("I", "show-file-info", info)
'@ | ForEach-Object { Write-Text "$ConfigDir\scripts\fileinfo.lua" $_ }

Write-Host "`n== 4/5  Adding on-screen controls (play/pause, skip, time bar) ==" -ForegroundColor Cyan
# uosc: a modern, free control bar for mpv - big buttons + a time bar at the bottom.
New-Item -ItemType Directory -Force -Path "$ConfigDir\script-opts" | Out-Null
$uoscOk = $false
try {
  $uoscZip = Join-Path $TempDir 'uosc.zip'
  Invoke-WebRequest 'https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip' -OutFile $uoscZip
  Remove-Item -Recurse -Force "$ConfigDir\scripts\uosc" -ErrorAction SilentlyContinue
  Expand-Archive $uoscZip -DestinationPath $ConfigDir -Force
  $uoscOk = Test-Path "$ConfigDir\scripts\uosc"
} catch { Write-Host "   Couldn't download uosc ($($_.Exception.Message)) - using mpv's built-in control bar instead." -ForegroundColor Yellow }

if ($uoscOk) {
  @'
# Built-in controls are replaced by uosc
osc=no
osd-bar=no
'@ | ForEach-Object { Write-Text "$ConfigDir\mpv.conf" $_ -Append }

  @'
# Time bar: always visible as a thin line at the bottom, grows when the mouse is near it
progress=always
progress_size=3
timeline_size=40
timeline_persistency=paused,audio
time_precision=0
# Show total length on the right (click it to switch to time remaining)
destination_time=total

# Control buttons (appear above the time bar when you move the mouse):
#   menu | subtitles audio | previous file, back 10s, play/pause, forward 10s, next file | loop | speed | fullscreen
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,space,command:skip_previous:playlist-prev?Previous file,command:replay_10:seek -10?Back 10 seconds,cycle:pause:pause:no/yes=play_arrow?Play / Pause,command:forward_10:seek 10?Forward 10 seconds,command:skip_next:playlist-next?Next file,space,<!image>cycle:repeat:loop-file:no/inf!?Loop,gap,<video,audio>speed,gap,fullscreen
controls_size=40
controls_persistency=paused,audio
'@ | ForEach-Object { Write-Text "$ConfigDir\script-opts\uosc.conf" $_ }
  # Right-click = full menu, click on video = play/pause
  @'
mbtn_right    script-binding uosc/menu
mbtn_left     cycle pause
mbtn_left_dbl cycle fullscreen
'@ | ForEach-Object { Write-Text "$ConfigDir\input.conf" $_ }
} else {
  @'
# mpv built-in controller: bar at the bottom with play/pause, skip, time bar, volume, fullscreen
layout=bottombar
seekbarstyle=bar
visibility=auto
hidetimeout=1500
deadzonesize=0
timetotal=yes
'@ | ForEach-Object { Write-Text "$ConfigDir\script-opts\osc.conf" $_ }
}

Write-Host "`n== 5/5  Shortcuts & file associations ==" -ForegroundColor Cyan
$ws = New-Object -ComObject WScript.Shell
foreach ($lnkPath in @("$([Environment]::GetFolderPath('Programs'))\mpv.lnk", "$([Environment]::GetFolderPath('Desktop'))\mpv.lnk")) {
  $lnk = $ws.CreateShortcut($lnkPath); $lnk.TargetPath = "$InstallDir\mpv.exe"; $lnk.Arguments = '--player-operation-mode=pseudo-gui'; $lnk.Save()
}
$assoc = Join-Path $InstallDir 'installer\mpv-install.bat'
if (Test-Path $assoc) {
  Write-Host "   Registering mpv as a video/audio player (Windows will ask for admin)..."
  Start-Process cmd.exe -ArgumentList "/c `"$assoc`"" -WorkingDirectory (Split-Path $assoc) -Verb RunAs -Wait
}
Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue

Write-Host @"

Done!  mpv is installed in $InstallDir

  * Right-click any video > Open with > mpv  (tick "Always")  - or set it in
    Settings > Apps > Default apps.
  * Or drag files onto the mpv window / desktop shortcut.

Controls: move the mouse over the video to show the buttons and time bar.
          Click anywhere on the time bar to jump there.
          Click the video to pause, double-click for fullscreen.
          Right-click for a full menu (subtitles, audio tracks, speed...).

Keys:  Space pause   Left/Right back/forward 5s   Up/Down back/forward 1 min
       F fullscreen   Mouse wheel volume   [ ] speed   S screenshot
       Shift+I file info   I live stats   Q quit

To update later, run updater.bat inside $InstallDir
"@ -ForegroundColor Green
Read-Host "Press Enter to close"
