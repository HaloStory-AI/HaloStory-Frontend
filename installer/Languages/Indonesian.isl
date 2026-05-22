; Inno Setup Language File: Indonesian
; Translated by R8KStudio

[LangOptions]
LanguageName=Indonesian
LanguageID=$0421
Version=6.0+

[Messages]
; Welcome page
WelcomeLabel1=Selamat datang di Wizard Pemasangan [name]
WelcomeLabel2=Wizard ini akan memasang [name/ver] ke komputer Anda.%n%nDisarankan untuk menutup program lain sebelum melanjutkan.
WelcomeLabel3=Selamat datang di Wizard Pemasangan [name]%n%nWizard ini akan memasang [name/ver] ke komputer Anda.
; Finish page
FinishedHeadingLabel=Pemasangan [name] Selesai
FinishedLabel=Ikon program telah dibuat di menu Start.%n%nKlik Selesai untuk keluar dari wizard pemasangan.
FinishedLabelNoIcons=Pemasangan [name] telah selesai.%n%nKlik Selesai untuk keluar dari wizard pemasangan.
; Click Finish
ClickFinish=Klik Selesai untuk keluar dari wizard pemasangan.
; Uninstall
ConfirmUninstall=Apakah Anda yakin ingin menghapus [name] dan semua komponennya?
UninstalledAll=[name] telah berhasil dihapus dari komputer Anda.
UninstallStatusLabel=Mencopot pemasangan [name] dari komputer Anda...
UninstallStatusLabelHeading=Mencopot pemasangan...

; Button captions
BtnBrowse=Browse...
BtnInstall=&Pasang
BtnOK=&OK
BtnCancel=&Batal
BtnYes=&Ya
BtnNo=&Tidak
BtnFinish=&Selesai
BtnNext=&Lanjut >
BtnBack=< &Kembali
BtnNewFolder=Buat Folder Baru

; Installer messages
SelectDirLabel3=Wizard akan memasang [name] ke folder berikut.
SelectDirBrowseLabel=Untuk memasang ke folder yang berbeda, klik Browse dan pilih folder lain.
SelectDirLabel=Folder Tujuan
SelectDirLabel2=Pilih folder untuk memasang [name].
DiskSpaceMBLabel=Ruang kosong di folder tujuan: [size]
DiskSpaceAvailableLabel=Tersedia:
DiskSpaceNeededLabel=Diperlukan:
DiskSpaceSelectDirLabel=Folder terpilih:

; Group/Start Menu
SelectStartMenuFolderLabel3=Pilih folder di menu Start tempat wizard akan membuat pintasan program.
SelectStartMenuFolderBrowseLabel=Untuk memilih folder lain, klik Browse.
SelectStartMenuFolderLabel=Pilih Folder Menu Start
SelectStartMenuFolderLabel2=Pilih folder untuk pintasan program.
SelectStartMenuFolderNewFolderHint=Ketik nama folder baru jika ingin membuat folder baru.
SelectStartMenuFolderEnterNewWarning=Ada kemungkinan folder yang Anda masukkan belum ada. Jika Anda ingin folder tersebut dibuat, pastikan folder dimulai dengan huruf atau nomor yang valid. Periksa bahwa nama folder tidak mengandung salah satu dari karakter berikut:%n%n[errorChars]
SelectStartMenuFolderEnterRoot=Anda tidak dapat memilih akar (root) dari menu Start. Pilih subfolder atau ketik nama baru untuk membuat folder baru.

; Ready page
ReadyLabel1=Wizard siap memulai pemasangan [name].
ReadyLabel2a=Klik Pasang untuk melanjutkan, atau klik Kembali jika ingin meninjau atau mengubah pengaturan.
ReadyLabel2b=Klik Pasang untuk melanjutkan pemasangan.
ReadyLabel3=[name] akan dipasang ke folder berikut.
ReadyLikeInstall=dan juga:
ReadyComponentList=Komponen yang akan dipasang
ReadyTaskList=Tugas tambahan:
ReadyMemoDir=Folder Tujuan:
ReadyMemoGroup=Folder Menu Start:
ReadyMemoTask=Tugas tambahan:

; Installing page
InstallingLabel=Memasang [name] ke komputer Anda...
InstallingLabel2=Harap tunggu sementara wizard memasang [name].
SetupAppRunningLabel=Harap tutup [name] sebelum melanjutkan.
SetupAppRunningLabel2=Tidak dapat melanjutkan pemasangan karena [name] sedang berjalan.

; Error messages
ErrorReadingDrive=Kesalahan saat membaca drive [drive].
ErrorGettingFileVersion=Kesalahan saat mendapatkan versi file: [filename]
ErrorReadingVersionInfo=Kesalahan saat membaca informasi versi dari file: [filename]
ErrorInvalidDrive=Drive yang dimasukkan tidak valid.
ErrorFileAssocFailed=Gagal membuat asosiasi file.
ErrorExecutingFile=Kesalahan saat menjalankan file: [filename]
ErrorReadingRegistry=Kesalahan saat membaca registry.
ErrorWritingRegistry=Kesalahan saat menulis ke registry.
ErrorRegisteringServer=Kesalahan saat mendaftarkan server: [filename]
ErrorRegisteringTypeLib=Kesalahan saat mendaftarkan tipe library: [filename]
ErrorDeletingRegValue=Kesalahan saat menghapus nilai registry.

; Disk space
DiskSpaceWarning=Program ini membutuhkan [need] ruang kosong pada drive [drive] tetapi hanya [have] yang tersedia. Disarankan untuk mengosongkan ruang pada drive tersebut.%n%nApakah Anda ingin melanjutkan?
DiskSpaceWarningTitle=Ruang Disk Tidak Mencukupi

; Miscellaneous
SetupAborted=Pemasangan dibatalkan.%n%nProses pemasangan belum selesai. Untuk memasang lagi di lain waktu, silakan jalankan program ini lagi.
SetupCancelled=Pemasangan dibatalkan.
AboutSetupLabel=[name] {version}%n%n[Halaman web: [url]]
AboutSetupTitle=Tentang [name]
AboutSetupMenuItem=&Tentang Pemasangan ini...
ExitSetupTitle=Keluar
ExitSetupMessage=Apakah Anda yakin ingin keluar dari wizard pemasangan?
ExitSetupMessage2=Wizard pemasangan belum selesai. Jika Anda keluar sekarang, program tidak akan dipasang.%n%nAnda dapat menjalankan wizard ini lagi di lain waktu untuk menyelesaikan pemasangan.%n%nApakah Anda yakin ingin keluar?

; File in Use
FileInUseTitle=File Sedang Digunakan
FileInUseLabel=File berikut sedang digunakan oleh proses lain:%n%n[filename]%n%nHarap tutup aplikasi lain dan klik Coba Lagi.
FileInUseLabel2=File berikut sedang digunakan oleh proses lain:%n%n[filename]%n%nHarap tutup aplikasi lain dan klik Coba Lagi, atau klik Lewati untuk melewati file ini.
FileInUse3Label=File berikut sedang digunakan oleh proses lain:%n%n[filename]%n%nHarap pilih tindakan yang diinginkan:
FileInUse3ButtonTryAgain=&Coba Lagi
FileInUse3ButtonKillProcess=&Tutup Proses
FileInUse3ButtonIgnore=&Abaikan
FileInUse3ButtonKillProcessFailed=Tidak dapat menutup proses secara otomatis. Harap tutup aplikasi yang menggunakan file tersebut secara manual, lalu klik Coba Lagi.

; Password
PasswordLabel1=Program ini dilindungi kata sandi.
PasswordLabel2=Silakan masukkan kata sandi untuk melanjutkan.

; Status messages
StatusInstallDeleteFile=Menghapus file...
StatusInstallCreateFolder=Membuat folder...
StatusInstallCreateShortcut=Membuat pintasan...
StatusInstallCreateFolderForFile=Membuat folder untuk file...
StatusInstallExtractFile=Memasang file...
StatusInstallInstallProgress=Progress Pemasangan
StatusInstallRollBack=Mengembalikan perubahan...
StatusInstallRegistering=Mendaftarkan...
StatusInstallSavingUninstall=Menyimpan data pencopotan...
StatusInstallRunningApp=Menjalankan aplikasi...
StatusInstallPreparing=Menghitung ruang yang diperlukan...

; Shutdown
ShutdownBlockedByApp=Program lain menolak izin mematikan atau me-restart.
ShutdownBlockedBySetup=Pemasangan menolak izin mematikan atau me-restart.

; Restart
RestartMessage=Anda harus me-restart komputer agar dapat menggunakan program ini. Apakah Anda ingin me-restart sekarang?
RestartMessage2=Anda harus me-restart komputer agar dapat menyelesaikan pencopotan pemasangan. Apakah Anda ingin me-restart sekarang?
RestartTitle=Restart Diperlukan

; Select components
SelectComponentsDesc=Deskripsi
SelectComponentsLabel=Harap pilih komponen yang ingin dipasang.
SelectComponentsLabel2=Centang komponen yang ingin dipasang, kosongkan yang tidak ingin dipasang.

; Tasks
SelectTasksLabel=Tugas Tambahan
SelectTasksLabel2=Pilih tugas tambahan yang ingin dilakukan oleh wizard.
SelectTasksDesc=Centang tugas tambahan yang ingin dilakukan.

; Uninstall
UninstallProgramLabel=Mencopot pemasangan [name] dari komputer Anda.
UninstallProgramLabel2=Klik Copot untuk memulai pencopotan pemasangan.
UninstallProgramLabel3=Centang komponen yang ingin dicopot:
UninstallProgramLabel4=Klik Copot untuk mencopot pemasangan [name] dari komputer Anda.

; Run
RunListLabel2=Centang program yang ingin dijalankan:
RunListLabel3=Jalankan program setelah selesai:
RunListLabel4=Jalankan program berikut setelah wizard selesai:

; License
LicenseLabel=Harap tinjau persyaratan lisensi sebelum melanjutkan.
LicenseLabel3=Harap tinjau persyaratan lisensi sebelum melanjutkan. Jika Anda menerima semua persyaratan, centang kotak di bawah ini.
LicenseAccepted=I &Saya menerima persyaratan dalam Perjanjian Lisensi
LicenseNotAccepted=Saya &tidak menerima persyaratan dalam Perjanjian Lisensi

; Info
InfoBeforeLabel=Harap baca informasi penting berikut sebelum melanjutkan.
InfoBeforeClickLabel=Setelah selesai membaca, klik Lanjut untuk melanjutkan.
InfoAfterLabel=Harap baca informasi penting berikut setelah pemasangan selesai.
InfoAfterClickLabel=Setelah selesai membaca, klik Lanjut untuk melanjutkan.

; New Directory
NewDirectory=Folder Baru
NewDirectoryName=Masukkan nama folder baru:
NewDirectoryAlreadyExists=Folder '[name]' sudah ada. Pilih folder lain atau ketik nama yang berbeda.

; Select directory
SelectDirectoryTitle=Pilih Folder
SelectDirectoryLabel=Pilih folder:

; Components sizes
ComponentsDiskSpaceLabel=[komponen] file akan dipasang dengan total [ukuran] ruang yang diperlukan.
ComponentsDiskSpaceLabel2=Ruang yang diperlukan untuk komponen yang dipasang:
AdditionalSizeMsg=[ukuran] tambahan

; Uninstall display
UninstallDisplayName=[name]
UninstallDisplayVersion=[version]
UninstallDisplayPublisher=[publisher]

; Shorcuts / Icons
ShortcutManagerEntry= &Pintasan
ShortcutManagerFolder=Buat &pintasan di folder Menu Start
ShortcutDesktopEntry=Buat pintasan &desktop
ShortcutDesktopFolder=Buat pintasan di &desktop

; Task names
TaskDesktopIcon=&Buat pintasan desktop
TaskQuicklaunchIcon=&Buat pintasan Quick Launch
TaskStartupEntry=Buat pintasan di folder &Startup

; Archived file
OverwriteExistingFile=Tindih file yang sudah ada?
OverwriteExistingFileReadOnly=Tindih file read-only yang sudah ada?
OverwriteExistingFileSystem=Tindih file sistem yang sudah ada?
OverwriteExistingFileSystemReadOnly=Tindih file sistem read-only yang sudah ada?

[CustomMessages]
NameAndVersion=%1 %2
AdditionalIcons=Additional icons:
CreateDesktopIcon=&Create a desktop shortcut
CreateQuickLaunchIcon=Create a &Quick Launch shortcut
ProgramOnTheWeb=%1 on the Web
UninstallProgram=Uninstall %1
LaunchProgram=Launch %1
AssocFileAssociation=&Associate %1 with %2 file type
AssocFileAssociationExt=&Associate %1 with %2 files
AutoStartProgramGroupDescription=Startup:
AutoStartProgram=Automatically start %1
AddPath=Buat PATH environment variable
