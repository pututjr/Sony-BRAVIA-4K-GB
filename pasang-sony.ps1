# Pasang Glass TV versi Sony BRAVIA (jadwal sholat, screensaver jam flip, pengingat 5 menit, adzan) sebagai Home.
# Langsung pakai: adb diunduh otomatis bila belum ada, TV di-backup otomatis, lalu APK siap pakai di folder apk\ dipasang.
# Aman: Glass TV diuji jalan dulu SEBELUM launcher bawaan dimatikan. Kalau ada yang gagal,
# skrip langsung mengembalikan launcher bawaan. Launcher bawaan hanya DIMATIKAN, tidak dihapus.
#
# Pakai:  powershell -ExecutionPolicy Bypass -File pasang-sony.ps1 -TvHost 192.168.1.5
#         powershell -ExecutionPolicy Bypass -File pasang-sony.ps1 -TvHost 192.168.1.5 -Kota Jakarta -Lat -6.2088 -Lng 106.8456
# Tanpa -Kota/-Lat/-Lng, jadwal sholat memakai Malang.
param(
    [string]$TvHost = '192.168.1.5',
    [string]$Kota = '',
    [double]$Lat = [double]::NaN,
    [double]$Lng = [double]::NaN,
    [string]$Apk = ''
)
$ErrorActionPreference = 'Stop'

$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
$dev = "$($TvHost):5555"
$stock = 'com.google.android.tvlauncher'
$me = 'com.gathin.tvhome'
function Tv([string]$cmd) { & $adb -s $dev shell $cmd }

# APK: pilihan -Apk, lalu hasil build sendiri (glass-tv\...), lalu APK siap pakai di folder apk\.
if (-not $Apk) {
    $built = "$PSScriptRoot\glass-tv\launcher\app\build\outputs\apk\release\app-release.apk"
    $Apk = if (Test-Path $built) { $built } else { "$PSScriptRoot\apk\glass-tv-sony.apk" }
}
if (-not (Test-Path $Apk)) { throw "APK tidak ditemukan: $Apk" }

# adb: unduh Android platform-tools resmi dari Google bila belum ada (tanpa hak admin).
if (-not (Test-Path $adb)) {
    Write-Host 'adb belum ada, mengunduh Android platform-tools dari Google...'
    $ProgressPreference = 'SilentlyContinue'
    New-Item -ItemType Directory -Force $sdk | Out-Null
    $zip = "$env:TEMP\platform-tools.zip"
    Invoke-WebRequest 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
    Expand-Archive $zip $sdk -Force
    Remove-Item $zip
}

function Healthy {
    # Sampai 3 kali: saat Glass TV yang sudah jadi Home diperbarui, Android menjalankannya ulang sendiri
    # sekali, sehingga nomor prosesnya berganti di percobaan pertama walau aplikasinya sehat.
    for ($try = 1; $try -le 3; $try++) {
        Start-Sleep 4; $a = (Tv "pidof $me"); Start-Sleep 3; $b = (Tv "pidof $me")
        $focus = (Tv 'dumpsys window | grep -m1 mCurrentFocus')
        if ($a -and $a -eq $b -and "$focus" -like "*$me*") { return $true }
        if ($try -lt 3) { Tv "am start -n $me/.MainActivity" | Out-Null }
    }
    return $false
}
function Undo([string]$why) {
    Write-Host "GAGAL: $why. Mengembalikan launcher bawaan..."
    Tv "pm enable --user 0 $stock" | Out-Null
    Tv "cmd package set-home-activity --user 0 $stock/.MainActivity" | Out-Null
    Tv "pm uninstall $me" | Out-Null
    Tv 'input keyevent KEYCODE_HOME' | Out-Null
    throw "Dibatalkan, TV kembali ke launcher bawaan. ($why)"
}

& $adb connect $dev | Out-Null
$state = & $adb -s $dev get-state 2>$null
if ($state -ne 'device') {
    throw "TV di $TvHost belum terhubung (status: '$state'). Kalau di TV muncul 'Allow USB debugging?', centang 'Always allow' lalu OK, kemudian jalankan skrip ini lagi."
}

# Backup otomatis sekali, sebelum ada yang diubah.
if (-not (Get-ChildItem $PSScriptRoot -Directory -Filter 'backup-sony-*' -ErrorAction SilentlyContinue)) {
    Write-Host '0/6 Backup kondisi TV (sekali saja)...'
    & "$PSScriptRoot\backup-sony.ps1" -TvHost $TvHost
}

# Memasang APK saat screensaver tampil membuat TV langsung standby; bangunkan dulu.
Tv 'input keyevent KEYCODE_WAKEUP' | Out-Null
Start-Sleep 2

Write-Host "1/6 Memasang APK ($(Split-Path $Apk -Leaf))..."
& $adb -s $dev install -r $Apk
if ($LASTEXITCODE -ne 0) { throw 'Pemasangan APK gagal. Tidak ada yang diubah.' }

Write-Host '2/6 Lokasi jadwal sholat...'
if ($Kota -or -not [double]::IsNaN($Lat)) {
    if (-not $Kota -or [double]::IsNaN($Lat) -or [double]::IsNaN($Lng)) { throw 'Isi -Kota, -Lat dan -Lng bersamaan. Contoh: -Kota Jakarta -Lat -6.2088 -Lng 106.8456' }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $json = '{"prayer_city": "' + ($Kota -replace '"', '') + '", "prayer_lat": ' + $Lat.ToString($inv) + ', "prayer_lng": ' + $Lng.ToString($inv) + '}'
    $tmp = Join-Path $env:TEMP 'glass-tv-config.json'
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding $false))
    Tv "mkdir -p /sdcard/Android/data/$me/files" | Out-Null
    & $adb -s $dev push $tmp "/sdcard/Android/data/$me/files/config.json" | Out-Null
    Remove-Item $tmp
    Write-Host "   $Kota ($Lat, $Lng)"
} else {
    Write-Host '   Malang (bawaan). Pakai -Kota -Lat -Lng untuk kota lain.'
}

Write-Host '3/6 Menjalankan Glass TV untuk diuji...'
Tv "am start -n $me/.MainActivity" | Out-Null
if (-not (Healthy)) { Undo 'Glass TV tidak tampil atau terus restart' }

Write-Host '4/6 Menjadikan Glass TV sebagai Home (launcher bawaan dimatikan, tidak dihapus)...'
Tv "cmd package set-home-activity --user 0 $me/.MainActivity" | Out-Null
Tv "pm disable-user --user 0 $stock" | Out-Null
Tv 'input keyevent KEYCODE_HOME' | Out-Null
$homeAct = "$(Tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME' | Select-Object -Last 1)".Trim()
if ($homeAct -notlike "$me/*" -or -not (Healthy)) { Undo "Home mengarah ke '$homeAct'" }

Write-Host '5/6 Screensaver jadwal sholat (muncul setelah 5 menit, batas tercepat di TV Sony)...'
Tv "settings put secure screensaver_components $me/.ClockDream" | Out-Null
Tv 'settings put secure screensaver_enabled 1' | Out-Null
Tv 'settings put system screen_off_timeout 300000' | Out-Null

Write-Host '6/6 Izin pengingat & adzan: tampil di atas aplikasi lain, dan alarm tidak ditunda hemat daya...'
Tv "appops set $me SYSTEM_ALERT_WINDOW allow" | Out-Null
Tv "dumpsys deviceidle whitelist +$me" | Out-Null
# Membuka Home sekali lagi agar jadwal adzan berikutnya langsung dihitung.
Tv 'input keyevent KEYCODE_HOME' | Out-Null
Start-Sleep 2
$alarm = "$(Tv "dumpsys alarm | grep -A2 ADZAN_FIRE | grep -o 'when=20[^ ]* [^ ]*' | head -1")".Trim()
$vol = "$(Tv "dumpsys audio | grep -A6 'STREAM_MUSIC:' | grep -o '(speaker): [0-9]*' | head -1")".Trim()

Write-Host "Selesai. Home sekarang: $homeAct"
if ($alarm) { Write-Host "Pengingat/adzan berikutnya: $($alarm -replace '^when=', '')" }
else { Write-Host 'Perhatian: jadwal adzan belum terlihat. Tekan Home di remote sekali, lalu cek lagi.' }
if ($vol -match ': (\d+)' -and [int]$Matches[1] -lt 20) { Write-Host "Perhatian: volume speaker TV $($Matches[1]) dari 100. Adzan mengikuti volume TV, naikkan bila terlalu pelan." }
Write-Host 'Atur TV nyala/mati otomatis lewat Settings > Timers > On timer (lihat README).'
