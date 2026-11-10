# Glass TV untuk Sony BRAVIA 4K GB — Jadwal Sholat, Jam Flip & Adzan

Ganti Home Google TV bawaan Sony BRAVIA (Android TV 9) dengan launcher kaca yang ringan. TV jadi papan jadwal sholat: screensaver jam flip besar yang terbaca dari jauh, hitung mundur ke waktu sholat berikutnya, nada pengumuman 5 menit sebelum adzan, lalu suara adzan. Tanpa root, sekitar 45–60 menit, dan bisa dikembalikan seperti semula dengan satu skrip.

Repo ini kelanjutan dari [Mibox-Glass-TV](https://github.com/pututjr/Mibox-Glass-TV), disesuaikan dan diuji pada **Sony BRAVIA 4K GB** (`BRAVIA_ATV2_PA`, Android 9, chipset MediaTek).

| Screensaver | Pengingat 5 menit sebelum adzan |
| --- | --- |
| ![Screensaver](docs/screensaver.png) | ![Pengingat](docs/pengingat.png) |

## Fitur

- **Screensaver jadwal sholat**:
  - Kota, hari + pasaran Jawa (mis. *Selasa Legi*), dan tanggal Hijriyah.
  - Jam flip besar `HH:MM:SS` yang angkanya membalik tiap detik.
  - Kotak hitung mundur *MENUJU ASHAR 00:41:27*, dan lima kartu waktu sholat dengan waktu berikutnya disorot emas.
  - Latar biru malam dengan siluet masjid, digambar sebagai vektor tanpa file gambar. Isi layar bergeser sedikit tiap menit agar tidak burn-in.
- **Jadwal sholat** dihitung di TV tanpa internet, dengan kriteria Kemenag: Subuh 20°, Isya 18°, Ashar Syafi'i, ihtiyat +2 menit.
- **Pengingat 5 menit sebelum adzan**:
  - Nada pengumuman ala stasiun disusul suara *"waktu sholat tiba"*.
  - Pil *"5 menit lagi Dzuhur · 11:16"* berkedip selama 30 detik di atas aplikasi apa pun (YouTube, Netflix, siaran TV, HDMI) dan juga di screensaver.
- **Adzan** untuk Dzuhur, Ashar, Maghrib dan Isya. Subuh sengaja dilewati karena TV kantor belum menyala saat Subuh. Video yang sedang diputar dijeda, dan panel *"Waktu Dzuhur"* tampil. Tekan **OK** atau **Back** untuk menghentikan adzan.
- **TV menyala 06:30 dan mati 19:30** memakai *On timer* bawaan Sony (lihat Langkah 7).
- **Aman:** TV dicadangkan dulu. Launcher bawaan hanya dimatikan, tidak dihapus.

## Isi repo

| File | Fungsi |
| --- | --- |
| `glass-tv-sony.patch` | Modifikasi untuk [Glass TV](https://github.com/cocombee/glass-tv) versi `ce164b6`: semua perubahan dari Mibox-Glass-TV, ditambah screensaver baru, penanggalan, pengingat, adzan, dan dock untuk Sony |
| `backup-sony.ps1` | Mencadangkan kondisi TV (hanya membaca, tidak mengubah apa pun) |
| `pasang-sony.ps1` | Memasang Glass TV sebagai Home, screensaver, dan izin adzan, dengan pengaman otomatis bila gagal |
| `restore-sony.ps1` | Mengembalikan TV ke kondisi saat backup |

**File adzan tidak disertakan.** Rekaman adzan biasanya berhak cipta, jadi siapkan sendiri file MP3 adzan yang boleh Anda pakai (Langkah 3). Nada pengumuman di patch dibuat sendiri (disintesis), dan suara *"waktu sholat tiba"* adalah rekaman pemilik repo. Keduanya boleh dipakai ulang.

## Bahan

Semua bahan gratis. Unduhannya sekitar 650 MB.

| Bahan | Keterangan | Sumber |
| --- | --- | --- |
| Sony BRAVIA Android TV | Android 8 ke atas, satu jaringan dengan PC | — |
| PC Windows 10/11 | Ruang kosong ± 3 GB | — |
| Git (dengan Git Bash) | Untuk mengambil kode | [git-scm.com](https://git-scm.com/download/win) |
| JDK 17, Android SDK, adb | Dipasang lewat perintah di Langkah 2. JDK 21/25 bawaan Android Studio **tidak** bisa dipakai, karena Gradle 8.9 butuh JDK 17 | [adoptium.net](https://adoptium.net/), [developer.android.com](https://developer.android.com/tools/releases/platform-tools) |
| File MP3 adzan | Milik sendiri atau berlisensi bebas | — |
| ffmpeg (opsional) | Untuk memotong bagian hening di awal MP3 | [ffmpeg.org](https://ffmpeg.org/download.html) |

## Langkah 1 — Siapkan TV

1. Buka **Settings → Device Preferences → About**.
2. Arahkan ke **Build**, lalu tekan OK di remote 7 kali sampai muncul *"You are now a developer"*.
3. Buka **Device Preferences → Developer options**, lalu nyalakan **USB debugging**. Kalau ada **Network debugging**, nyalakan juga.
4. Catat IP TV di **Settings → Network & Internet**. Contoh: `192.168.1.5`.

Ganti `192.168.1.5` dengan IP TV Anda di setiap perintah di bawah.

## Langkah 2 — Pasang alat di PC

Semua alat dipasang ke folder pengguna, jadi tidak perlu hak admin. Kalau Android SDK sudah ada di `%LOCALAPPDATA%\Android\Sdk`, cukup pasang JDK 17 saja. Platform 34 dan build-tools 34 akan diunduh otomatis saat build pertama.

**a.** Buka **PowerShell**, lalu tempel:

```powershell
$ProgressPreference='SilentlyContinue'; $dl="$env:TEMP\androiddl"; $sdk="$env:LOCALAPPDATA\Android\Sdk"
New-Item -ItemType Directory -Force $dl,$sdk,"$sdk\cmdline-tools" | Out-Null
Invoke-WebRequest "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse" -OutFile "$dl\jdk17.zip"
Invoke-WebRequest "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile "$dl\pt.zip"
Invoke-WebRequest "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile "$dl\clt.zip"
Expand-Archive "$dl\jdk17.zip" "$env:LOCALAPPDATA\jdk-tmp" -Force
Move-Item (Get-ChildItem "$env:LOCALAPPDATA\jdk-tmp" -Directory)[0].FullName "$env:LOCALAPPDATA\jdk17"
Expand-Archive "$dl\pt.zip" $sdk -Force
Expand-Archive "$dl\clt.zip" "$sdk\clt-tmp" -Force
Move-Item "$sdk\clt-tmp\cmdline-tools" "$sdk\cmdline-tools\latest"
```

**b.** Buka **Git Bash**, lalu tempel. Perintah `yes` menyetujui lisensi Android SDK dari Google.

```bash
export JAVA_HOME="$LOCALAPPDATA/jdk17"; SDK="$LOCALAPPDATA/Android/Sdk"
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="$SDK" --licenses
"$SDK/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="$SDK" "platforms;android-34" "build-tools;34.0.0"
```

## Langkah 3 — Ambil repo ini dan Glass TV, terapkan patch, tambahkan adzan

Di Git Bash:

```bash
cd /d && git clone https://github.com/pututjr/Sony-BRAVIA-4K-GB.git sony-glass-tv && cd sony-glass-tv
git clone -c core.longpaths=true https://github.com/cocombee/glass-tv.git
cd glass-tv && git checkout -q ce164b6 && git apply ../glass-tv-sony.patch && echo "patch OK"
```

**Tambahkan file adzan.** Salin MP3 adzan ke `glass-tv/launcher/app/src/main/res/raw/adzan.mp3`. Nama file harus persis `adzan.mp3`. Kalau ada hening di awal, potong dengan ffmpeg (contoh: buang 5 detik pertama, jadikan mono 96 kbps):

```bash
ffmpeg -ss 5 -i "/c/Users/NAMA/Music/adzan.mp3" -ac 1 -b:a 96k launcher/app/src/main/res/raw/adzan.mp3
```

Tanpa file ini, build tetap berhasil. Saat waktu adzan, panelnya tetap tampil, hanya tanpa suara.

**Ganti kota (default Malang)** di `glass-tv/launcher/app/src/main/res/values/config.xml`. Koordinatnya bisa diambil dari Google Maps (klik kanan pada kota).

```xml
<string name="prayer_city" translatable="false">Malang</string>
<string name="prayer_lat" translatable="false">-7.9666</string>
<string name="prayer_lng" translatable="false">112.6326</string>
<!-- Geser tanggal Hijriyah bila beda dengan kalender Kemenag, misalnya -1 atau 1. -->
<integer name="hijri_offset_days">0</integer>
```

Contoh: Jakarta `-6.2088`, `106.8456`; Surabaya `-7.2575`, `112.7521`; Bandung `-6.9175`, `107.6191`. Aplikasi di dock diatur lewat `dock_apps` di file yang sama. Defaultnya YouTube, Netflix, Prime Video, dan aplikasi TV Sony (`com.sony.dtv.tvx`).

## Langkah 4 — Backup TV

Di PowerShell:

```powershell
cd D:\sony-glass-tv
powershell -ExecutionPolicy Bypass -File backup-sony.ps1 -TvHost 192.168.1.5
```

Pada percobaan pertama, TV menampilkan **Allow USB debugging?** Centang **Always allow from this computer**, tekan OK, lalu jalankan perintahnya sekali lagi. Hasilnya folder `backup-sony-<tanggal>`, yang juga berisi `restore-sony.ps1`.

## Langkah 5 — Build APK

Build pertama memakan 3–5 menit. Di Git Bash:

```bash
cd /d/sony-glass-tv/glass-tv/launcher
printf 'sdk.dir=%s\n' "$(cygpath -m "$LOCALAPPDATA/Android/Sdk")" > local.properties
export JAVA_HOME="$LOCALAPPDATA/jdk17"
./gradlew.bat testReleaseUnitTest assembleRelease -q --console=plain
ls -la app/build/outputs/apk/release/app-release.apk
```

**Cek:** `app-release.apk` ada. Ukurannya sekitar 370 KB tanpa adzan, atau ditambah ukuran MP3 adzan Anda.

## Langkah 6 — Pasang sebagai Home

Di PowerShell:

```powershell
cd D:\sony-glass-tv
powershell -ExecutionPolicy Bypass -File pasang-sony.ps1 -TvHost 192.168.1.5
```

Skrip ini:

1. Membangunkan TV dan memasang APK.
2. Membuka Glass TV dan mengecek bahwa ia jalan normal.
3. Menjadikan Glass TV sebagai Home. Launcher bawaan dimatikan, tidak dihapus.
4. Memasang screensaver jadwal sholat dengan waktu tunggu 5 menit.
5. Memberi izin *tampil di atas aplikasi lain* untuk pengingat adzan, dan mengecualikan Glass TV dari hemat daya agar alarmnya tepat waktu.

Kalau ada langkah yang gagal, launcher bawaan otomatis dikembalikan.

**Cek:** keluar `Selesai. Home sekarang: com.gathin.tvhome/.MainActivity` dan `Pengingat/adzan berikutnya: ...`.

## Langkah 7 — TV nyala dan mati otomatis (On timer Sony)

Aplikasi biasa tidak bisa menyalakan TV dari standby, jadi pakai timer bawaan Sony. Di remote, buka **Settings → Timers → On timer**:

| Pilihan | Isi |
| --- | --- |
| On timer | Nyala |
| Day | Every Mon-Fri (atau Every day) |
| Time | 06:30 |
| Duration | 13 h (TV mati pukul 19:30) |
| Volume setup | Volume saat TV menyala. Volume ini juga menentukan keras-pelannya adzan |

## Catatan khusus Sony

- **Screensaver paling cepat 5 menit.** Nilai di bawah itu diabaikan oleh TV Sony.
- **Jangan memasang ulang APK saat screensaver sedang tampil.** TV akan langsung standby. `pasang-sony.ps1` sudah membangunkan TV lebih dulu.
- **Volume adzan mengikuti volume TV.** Kalau volume speaker sangat kecil (misalnya 5 dari 100), adzan hampir tidak terdengar.
- Pengingat dan adzan hanya berjalan saat TV menyala, termasuk saat screensaver tampil.
- Tanggal Hijriyah memakai kalender Umm al-Qura, jadi bisa selisih sehari dengan kalender Kemenag. Atur `hijri_offset_days` di `config.xml`. Pasaran dan tanggal Hijriyah berganti pukul 00:00.

## Kembali ke semula

```powershell
cd D:\sony-glass-tv\backup-sony-<tanggal>
powershell -ExecutionPolicy Bypass -File restore-sony.ps1 -TvHost 192.168.1.5
```

Skrip ini:

- Menghapus Glass TV, termasuk alarm adzannya.
- Menyalakan lagi aplikasi yang dimatikan.
- Memulihkan launcher, screensaver, dan waktu tunggu screensaver seperti saat backup.

*On timer* Sony tidak diubah, jadi atur sendiri lewat menu bila perlu. Factory reset juga tetap bisa dipakai, karena tidak ada aplikasi sistem yang dihapus.

## Masalah umum

| Gejala | Solusi |
| --- | --- |
| `unauthorized` / `failed to authenticate` | Centang **Always allow** di TV, tekan OK, lalu ulangi perintah |
| `connection refused` / `offline` | TV sedang standby atau IP berubah. Nyalakan TV, cek USB debugging dan IP |
| Build gagal dengan pesan versi Java | Pastikan `JAVA_HOME` mengarah ke JDK 17, bukan JDK bawaan Android Studio |
| `classes.dex ... being used by another process` | Antivirus sedang memindai file build. Tunggu beberapa detik lalu build lagi |
| `git apply` gagal | Pastikan sudah `git checkout ce164b6` |
| Pengingat tidak muncul di atas aplikasi lain | Jalankan `adb shell appops set com.gathin.tvhome SYSTEM_ALERT_WINDOW allow` |
| Adzan tanpa suara | `res/raw/adzan.mp3` belum ada saat build, atau volume TV 0 |
| TV hitam setelah pasang ulang APK | TV masuk standby karena screensaver dihentikan paksa. Nyalakan dengan remote |

## Kredit dan lisensi

- Launcher: [Glass TV](https://github.com/cocombee/glass-tv) oleh cocombee, berdasarkan [Clean Your TV](https://github.com/Gathin23/cleanyourtv) oleh Gathin. Keduanya berlisensi MIT.
- Font Outfit berlisensi SIL OFL. Rumus posisi matahari mengikuti [PrayTimes.org](http://praytimes.org/), dengan parameter kriteria Kemenag RI.
- Tanggal Hijriyah memakai `android.icu.util.IslamicCalendar` (Umm al-Qura) bawaan Android. Pasaran Jawa memakai patokan 17 Agustus 1945 = Jumat Legi.
- Patch, skrip, nada pengumuman, dan suara "waktu sholat tiba" di repo ini berlisensi MIT, lihat [LICENSE](LICENSE).
