# Panduan Penyetelan GitHub Actions (CI/CD) untuk BlueTalk Frontend

Karena repository ini membutuhkan `keystore.jks` untuk membuat *release build* di Android, tetapi kita **tidak boleh** menyimpan file JKS secara publik (atau bahkan di-commit ke dalam repo private sekalipun demi keamanan), kita akan memanfaatkan fitur **GitHub Secrets**.

Berikut adalah langkah-langkah *setup* pertama kali dari nol:

## 1. Persiapkan Keystore & Konversikan ke Base64 (Di Komputermu)

Komputer virtual dari GitHub Actions butuh membaca file `keystore.jks` untuk proses kompilasi. Jadi, kita akan mengubah file tersebut menjadi format *text* (Base64), lalu GitHub Actions akan otomatis mengubah teks itu kembali menjadi `.jks` secara otomatis saat proses build berjalan.

Buka terminal Linux-mu, masuk ke direktori tempat `keystore.jks` kamu berada, dan jalankan perintah ini:

```bash
base64 -w 0 namakeystoremu.jks > keystore_base64.txt
```

*(Catatan: Buka file `keystore_base64.txt` ini dengan text editor, lalu **copy semua teks** yang ada di dalamnya. Teks ini sangat panjang, pastikan semuanya tersalin).*

## 2. Pasang Secrets di Repositori GitHub

Buka halaman repository `bluetalk_frontend` (atau repository utamamu) di website GitHub, lalu masuk ke:
👉 **Settings** -> **Secrets and variables** -> **Actions** -> klik tombol **New repository secret**.

Tambahkan 4 *Secret* berikut secara terpisah (nama *secret* HARUS huruf besar semua sesuai tulisan di bawah):

- **Name:** `KEYSTORE_BASE64`
  **Secret:** *(Paste teks panjang dari file `keystore_base64.txt` pada Langkah 1 di sini)*

- **Name:** `KEY_PASSWORD`
  **Secret:** *(Ketik password dari 'key' kamu)*

- **Name:** `STORE_PASSWORD`
  **Secret:** *(Ketik password dari 'keystore' kamu)*

- **Name:** `KEY_ALIAS`
  **Secret:** *(Ketik alias yang kamu gunakan saat membuat keystore)*

*(Setelah selesai menyalin dan men-save secrets di GitHub, kamu bisa menghapus file `keystore_base64.txt` dari komputermu karena sudah tidak diperlukan lagi).*

## 3. Konfirmasi File `build.gradle` (Android)

Agar Flutter otomatis tahu ada keystore yang disiapkan GitHub, pastikan file `android/app/build.gradle` kamu sudah di-setup agar membaca `key.properties`. Secara *default*, ini biasanya sudah terkonfigurasi. 

Script GitHub Action akan otomatis membuat file `key.properties` di dalam servernya yang berisi password-password kamu dan me-referensikan ke file `upload-keystore.jks` yang ter-decode.

## 4. Commit & Push

Setelah memastikan semuanya aman, lakukan *commit* pada direktori `.github` yang berisi file workflow.

```bash
git add .github/workflows/flutter_build.yml
git commit -m "feat: setup github action for android, linux, and windows"
git push origin main
```

## 5. Pantau Proses Build & Download Hasilnya

Segera setelah kamu melakukan `push`, buka halaman repositori GitHub kamu dan klik tab **Actions**. 
Kamu akan melihat ada "Flutter Multi-Platform Build" yang sedang berjalan secara **paralel**:

1. **Windows** (memakai virtual machine `windows-latest`)
2. **Linux** (memakai virtual machine `ubuntu-latest`)
3. **Android** (memakai virtual machine `ubuntu-latest`)

Tunggu sampai indikatornya berwarna hijau ✅. 

Setelah selesai, klik pada nama *workflow run* tersebut. Scroll ke paling bawah, dan di bagian **Artifacts**, kamu bisa men-download hasil jadinya:

- **`Android-Release-APK`**: Akan berisi file zip dengan `.apk` yang sudah terpisah (*split-per-abi*, contohnya `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`, dll). Ini membuat ukuran per file APK jauh lebih kecil.
- **`Linux-Release`**: Folder zip berisi bundle executable/desktop untuk Linux.
- **`Windows-Release`**: Folder zip berisi bundle `.exe` dan DLL untuk Windows.
