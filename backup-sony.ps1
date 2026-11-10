# Cadangkan kondisi TV Sony BRAVIA (Android TV 9) sebelum mengganti launcher. Hanya MEMBACA, tidak mengubah apa pun di TV.
# Hasil: folder backup-sony-<tanggal> berisi daftar aplikasi, pengaturan, info perangkat, launcher aktif,
# salinan APK launcher bawaan, dan skrip restore-sony.ps1.
# Pakai:  powershell -ExecutionPolicy Bypass -File backup-sony.ps1 -TvHost 192.168.1.5
param([string]$TvHost = '192.168.1.5', [string]$OutDir = '')
$ErrorActionPreference = 'Stop'

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$dev = "$($TvHost):5555"
function Tv([string]$cmd) { & $adb -s $dev shell $cmd }

& $adb connect $dev | Out-Null
$state = & $adb -s $dev get-state 2>$null
if ($state -ne 'device') {
    throw "TV belum terhubung (status: '$state'). Kalau di TV muncul 'Allow USB debugging?', centang 'Always allow' lalu OK, kemudian jalankan skrip ini lagi."
}

if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot ("backup-sony-" + (Get-Date -Format 'yyyyMMdd-HHmm')) }
New-Item -ItemType Directory -Force $OutDir, "$OutDir\apk" | Out-Null
function Save([string]$name, [string]$cmd) { Tv $cmd | Out-File -Encoding utf8 (Join-Path $OutDir $name) }

Save 'getprop.txt' 'getprop'
Save 'packages-all.txt' 'pm list packages -f'
Save 'packages-disabled.txt' 'pm list packages -d'
Save 'packages-user-installed.txt' 'pm list packages -3'
foreach ($ns in 'system', 'secure', 'global') { Save "settings-$ns.txt" "settings list $ns" }
Save 'home-launcher.txt' 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
Save 'home-candidates.txt' 'cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
Save 'meminfo.txt' 'head -3 /proc/meminfo'
# Nilai yang diubah pasang-sony.ps1, disimpan terpisah agar restore-sony.ps1 bisa mengembalikannya.
Save 'screen_off_timeout.txt' 'settings get system screen_off_timeout'
Save 'screensaver_components.txt' 'settings get secure screensaver_components'

$homeAct = "$(Get-Content "$OutDir\home-launcher.txt" | Select-Object -Last 1)".Trim()
$stockPkg = $homeAct.Split('/')[0]
if ($stockPkg -and $stockPkg -ne 'android') {
    foreach ($p in (Tv "pm path $stockPkg")) {
        $remote = "$p".Trim() -replace '^package:', ''
        if ($remote) { & $adb -s $dev pull $remote (Join-Path "$OutDir\apk" ("$stockPkg-" + (Split-Path $remote -Leaf))) | Out-Null }
    }
}
$restore = Join-Path $PSScriptRoot 'restore-sony.ps1'
if (Test-Path $restore) { Copy-Item $restore $OutDir }

$model = (Tv 'getprop ro.product.model').Trim(); $android = (Tv 'getprop ro.build.version.release').Trim()
Write-Host "Backup selesai: $OutDir"
Write-Host "Perangkat: $model, Android $android. Launcher aktif: $homeAct"
Get-ChildItem $OutDir -Recurse -File | Where-Object { $_.Length -eq 0 } | ForEach-Object { Write-Host "PERINGATAN: file kosong $($_.Name)" }
