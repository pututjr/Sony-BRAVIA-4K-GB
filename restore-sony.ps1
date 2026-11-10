# Kembalikan TV Sony BRAVIA ke kondisi saat backup dibuat. Jalankan dari dalam folder backup-sony-<tanggal>.
# - Menghapus Glass TV (com.gathin.tvhome), termasuk alarm adzan dan izin overlay-nya
# - Menyalakan lagi semua aplikasi yang dimatikan setelah backup
# - Menjadikan launcher bawaan Google TV sebagai Home lagi
# - Mengembalikan screensaver dan waktu tunggunya seperti saat backup
# Pakai:  powershell -ExecutionPolicy Bypass -File restore-sony.ps1 [-TvHost 192.168.1.5]
param([string]$TvHost = '192.168.1.5')

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$here = $PSScriptRoot
$me = 'com.gathin.tvhome'
function Tv([string]$cmd) { & $adb -s "$($TvHost):5555" shell $cmd }
function Saved([string]$name, [string]$fallback) {
    $f = Join-Path $here $name
    if (Test-Path $f) { $v = "$(Get-Content $f | Select-Object -Last 1)".Trim(); if ($v -and $v -ne 'null') { return $v } }
    return $fallback
}

& $adb connect "$($TvHost):5555" | Out-Null
$state = & $adb -s "$($TvHost):5555" get-state 2>$null
if ($state -ne 'device') { throw "TV di $TvHost tidak terhubung. Pastikan TV menyala dan USB debugging aktif." }
Tv 'input keyevent KEYCODE_WAKEUP' | Out-Null

$wasDisabled = Get-Content "$here\packages-disabled.txt" | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ }
$nowDisabled = Tv 'pm list packages -d' | ForEach-Object { ($_ -replace '^package:', '').Trim() } | Where-Object { $_ }

foreach ($p in $nowDisabled) {
    if ($wasDisabled -notcontains $p) {
        Write-Host "Menyalakan lagi: $p"
        Tv "pm enable --user 0 $p" | Out-Null
    }
}

Tv 'cmd package set-home-activity --user 0 com.google.android.tvlauncher/.MainActivity' | Out-Null
Tv "settings put secure screensaver_components $(Saved 'screensaver_components.txt' 'com.google.android.backdrop/.Backdrop')" | Out-Null
Tv "settings put system screen_off_timeout $(Saved 'screen_off_timeout.txt' '3600000')" | Out-Null
Tv "dumpsys deviceidle whitelist -$me" | Out-Null
Tv "pm uninstall $me" | Out-Null
Tv 'input keyevent KEYCODE_HOME' | Out-Null

$homeAct = (Tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | Select-Object -Last 1).Trim()
Write-Host "Home sekarang: $homeAct"
if ($homeAct -like 'com.google.android.tvlauncher/*') { Write-Host 'Selesai: TV kembali seperti semula. On timer Sony tidak diubah skrip ini.' }
else { Write-Host 'Perhatian: Home belum kembali ke launcher bawaan. Tekan Home di remote, lalu jalankan skrip ini sekali lagi.' }
