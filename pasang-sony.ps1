# Pasang Glass TV versi Sony BRAVIA (jadwal sholat, screensaver jam flip, pengingat 5 menit, adzan) sebagai Home.
# Aman: Glass TV diuji jalan dulu SEBELUM launcher bawaan dimatikan. Kalau ada yang gagal,
# skrip langsung mengembalikan launcher bawaan.
# Launcher bawaan hanya DIMATIKAN (pm disable-user), tidak dihapus. Kembalikan dengan restore-sony.ps1.
# Pakai:  powershell -ExecutionPolicy Bypass -File pasang-sony.ps1 [-TvHost 192.168.1.5]
param([string]$TvHost = '192.168.1.5')
$ErrorActionPreference = 'Stop'

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$apk = "$PSScriptRoot\glass-tv\launcher\app\build\outputs\apk\release\app-release.apk"
$dev = "$($TvHost):5555"
$stock = 'com.google.android.tvlauncher'
$me = 'com.gathin.tvhome'
function Tv([string]$cmd) { & $adb -s $dev shell $cmd }

function Healthy {
    Start-Sleep 4; $a = (Tv "pidof $me"); Start-Sleep 3; $b = (Tv "pidof $me")
    $focus = (Tv 'dumpsys window | grep -m1 mCurrentFocus')
    return ($a -and $a -eq $b -and "$focus" -like "*$me*")
}
function Undo([string]$why) {
    Write-Host "GAGAL: $why. Mengembalikan launcher bawaan..."
    Tv "pm enable --user 0 $stock" | Out-Null
    Tv "cmd package set-home-activity --user 0 $stock/.MainActivity" | Out-Null
    Tv "pm uninstall $me" | Out-Null
    Tv 'input keyevent KEYCODE_HOME' | Out-Null
    throw "Dibatalkan, TV kembali ke launcher bawaan. ($why)"
}

if (-not (Test-Path $apk)) { throw "APK belum di-build: $apk" }
& $adb connect $dev | Out-Null
if ((& $adb -s $dev get-state 2>$null) -ne 'device') { throw "TV di $TvHost tidak terhubung." }

# Memasang APK saat screensaver tampil membuat TV langsung standby; bangunkan dulu.
Tv 'input keyevent KEYCODE_WAKEUP' | Out-Null
Start-Sleep 2

Write-Host '1/5 Memasang APK...'
& $adb -s $dev install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Pemasangan APK gagal. Tidak ada yang diubah.' }

Write-Host '2/5 Menjalankan Glass TV untuk diuji...'
Tv "am start -n $me/.MainActivity" | Out-Null
if (-not (Healthy)) { Undo 'Glass TV tidak tampil atau terus restart' }

Write-Host '3/5 Menjadikan Glass TV sebagai Home (launcher bawaan dimatikan, tidak dihapus)...'
Tv "cmd package set-home-activity --user 0 $me/.MainActivity" | Out-Null
Tv "pm disable-user --user 0 $stock" | Out-Null
Tv 'input keyevent KEYCODE_HOME' | Out-Null
$homeAct = "$(Tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | Select-Object -Last 1)".Trim()
if ($homeAct -notlike "$me/*" -or -not (Healthy)) { Undo "Home mengarah ke '$homeAct'" }

Write-Host '4/5 Screensaver jadwal sholat (muncul setelah 5 menit, batas tercepat di TV Sony)...'
Tv "settings put secure screensaver_components $me/.ClockDream" | Out-Null
Tv 'settings put secure screensaver_enabled 1' | Out-Null
Tv 'settings put system screen_off_timeout 300000' | Out-Null

Write-Host '5/5 Izin pengingat & adzan: tampil di atas aplikasi lain, dan alarm tidak ditunda hemat daya...'
Tv "appops set $me SYSTEM_ALERT_WINDOW allow" | Out-Null
Tv "dumpsys deviceidle whitelist +$me" | Out-Null
# Membuka Home sekali lagi agar jadwal adzan berikutnya langsung dihitung.
Tv 'input keyevent KEYCODE_HOME' | Out-Null
Start-Sleep 2
$alarm = "$(Tv "dumpsys alarm | grep -A2 ADZAN_FIRE | grep -o 'when=20[^ ]* [^ ]*' | head -1")".Trim()

Write-Host "Selesai. Home sekarang: $homeAct"
if ($alarm) { Write-Host "Pengingat/adzan berikutnya: $($alarm -replace '^when=', '')" }
else { Write-Host 'Perhatian: jadwal adzan belum terlihat. Tekan Home di remote sekali, lalu cek lagi.' }
Write-Host 'Atur TV nyala/mati otomatis lewat Settings > Timers > On timer (lihat README).'
