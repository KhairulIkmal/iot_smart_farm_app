import 'package:flutter/material.dart';

/// Provides translated strings throughout the app.
///
/// Usage in build():
///   final l10n = AppLocalizations.of(context);
///   Text(l10n.t('Welcome Back'))
///
/// English text is used as the key; falls back to English if no translation.
class AppLocalizations {
  final String languageCode;
  const AppLocalizations(this.languageCode);

  /// Look up a translation. Returns [key] unchanged for English or unknown keys.
  String t(String key) {
    if (languageCode == 'en') return key;
    return _ms[key] ?? key;
  }

  static AppLocalizations of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AppLocalizationsScope>();
    return scope?.localizations ?? const AppLocalizations('en');
  }

  // ---------------------------------------------------------------------------
  // Malay (ms) translations
  // ---------------------------------------------------------------------------
  static const Map<String, String> _ms = {
    // ── App general ────────────────────────────────────────────────────────
    'IoT Smart Farm': 'IoT Smart Farm',
    'Smart Farming Solutions': 'Penyelesaian Pertanian Pintar',

    // ── Splash / Auth wrapper ──────────────────────────────────────────────
    'Authentication Error': 'Ralat Pengesahan',
    'Please restart the application': 'Sila mulakan semula aplikasi',

    // ── Login screen ───────────────────────────────────────────────────────
    'Welcome Back': 'Selamat Kembali',
    'Monitor your crops and control irrigation from\nanywhere.':
        'Pantau tanaman dan kawal pengairan dari mana-mana.',
    'Email address': 'Alamat E-mel',
    'farmer@example.com': 'petani@contoh.com',
    'Password': 'Kata Laluan',
    'Forgot password?': 'Lupa kata laluan?',
    'Sign in': 'Log Masuk',
    'Or continue with': 'Atau teruskan dengan',
    'Sign in with Google': 'Log Masuk dengan Google',
    "Don't have an account? ": 'Tiada akaun? ',
    'Create an account': 'Cipta akaun',
    'Please enter your email address first':
        'Sila masukkan alamat e-mel anda terlebih dahulu',

    // ── Register screen ────────────────────────────────────────────────────
    'Create Account': 'Cipta Akaun',
    'Start monitoring your farm with smart\nIoT solutions today.':
        'Mulai pantau ladang anda dengan penyelesaian IoT pintar hari ini.',
    'Full Name': 'Nama Penuh',
    'Confirm Password': 'Sahkan Kata Laluan',
    'Enter your full name': 'Masukkan nama penuh anda',
    'Name must be at least 2 characters':
        'Nama mesti sekurang-kurangnya 2 aksara',
    'Create a strong password': 'Cipta kata laluan yang kuat',
    'Re-enter your password': 'Masukkan semula kata laluan anda',
    'I agree to the Terms & Conditions and Privacy Policy':
        'Saya bersetuju dengan Syarat & Keadaan dan Dasar Privasi',
    'Please accept the Terms & Conditions':
        'Sila terima Syarat & Keadaan',
    'Or sign up with': 'Atau daftar dengan',
    'Sign up with Google': 'Daftar dengan Google',
    'Already have an account? ': 'Sudah mempunyai akaun? ',

    // ── Validation / error strings (AppStrings) ────────────────────────────
    'This field is required': 'Medan ini diperlukan',
    'Please enter a valid email address': 'Sila masukkan alamat e-mel yang sah',
    'Password must be at least 6 characters':
        'Kata laluan mestilah sekurang-kurangnya 6 aksara',
    'Passwords do not match': 'Kata laluan tidak sepadan',
    'Something went wrong. Please try again.':
        'Sesuatu telah berlaku. Sila cuba lagi.',
    'Password reset email sent': 'E-mel tetapan semula kata laluan telah dihantar',

    // ── Bottom navigation ──────────────────────────────────────────────────
    'Home': 'Utama',
    'Sensors': 'Penderia',
    'Control': 'Kawalan',
    'AI Assist': 'Bantuan AI',
    'Settings': 'Tetapan',

    // ── Dashboard ──────────────────────────────────────────────────────────
    'ACTIVE FIELD': 'PADANG AKTIF',
    'Select Field': 'Pilih Padang',
    'Overview': 'Ringkasan',
    'ONLINE': 'DALAM TALIAN',
    'OFFLINE': 'LUAR TALIAN',
    'Weather Unavailable': 'Cuaca Tidak Tersedia',
    'Set farm location in settings': 'Tetapkan lokasi ladang dalam tetapan',
    'Next hour:': 'Jam berikutnya:',
    'SOIL MOISTURE': 'KELEMBAPAN TANAH',
    'PH LEVEL': 'TAHAP PH',
    'TEMPERATURE': 'SUHU',
    'HUMIDITY': 'KELEMBAPAN',
    'Water Tank Level': 'Tahap Tangki Air',
    'SENSOR ERROR': 'RALAT PENDERIA',
    'CRITICAL LOW': 'KRITIKAL RENDAH',
    'No Device Selected': 'Tiada Peranti Dipilih',
    'Select a field to view sensor data':
        'Pilih padang untuk melihat data penderia',
    'Low': 'Rendah',
    'High': 'Tinggi',
    'Normal': 'Normal',
    'Acidic': 'Berasid',
    'Alkaline': 'Alkali',
    'Optimal': 'Optimum',
    'Good': 'Baik',

    // ── Sensors screen ─────────────────────────────────────────────────────
    'Real-time monitoring': 'Pemantauan masa nyata',
    'MONITORING': 'MEMANTAU',
    'Soil Moisture': 'Kelembapan Tanah',
    'Last 6 Hours': '6 Jam Terakhir',
    '6h ago': '6j lalu',
    'Now': 'Sekarang',
    'Details': 'Butiran',
    'Updated just now': 'Baru sahaja dikemas kini',
    'Air Conditions': 'Keadaan Udara',
    'Temperature': 'Suhu',
    'Humidity': 'Kelembapan',
    'History': 'Sejarah',
    'Main Tank': 'Tangki Utama',
    'Capacity: 5000L': 'Kapasiti: 5000L',
    'Sensor Error': 'Ralat Penderia',
    'Low Level': 'Tahap Rendah',
    'Requires Refill': 'Perlu Diisi Semula',
    'Level OK': 'Tahap Baik',
    'Alerts': 'Amaran',
    'Usage Trend': 'Aliran Penggunaan',
    'Soil pH': 'pH Tanah',
    'Zone A': 'Zon A',
    'Analyze': 'Analisis',
    'No Device Connected': 'Tiada Peranti Bersambung',
    'Claim a device to view sensor data':
        'Tuntut peranti untuk melihat data penderia',

    // ── Irrigation screen ──────────────────────────────────────────────────
    'Irrigation Control': 'Kawalan Pengairan',
    'CONTROLLING': 'MENGAWAL',
    'Manual': 'Manual',
    'Auto': 'Automatik',
    'System Status': 'Status Sistem',
    'System Ready': 'Sistem Sedia',
    'Device Offline': 'Peranti Luar Talian',
    'Pump Running': 'Pam Berjalan',
    'STOP': 'BERHENTI',
    'START': 'MULA',
    'Last Active': 'Terakhir Aktif',
    'Tank Level': 'Tahap Tangki',
    'Automation Rules': 'Peraturan Automasi',
    'Configure thresholds for auto-irrigation':
        'Konfigurasi ambang untuk pengairan automatik',
    'Target Range': 'Julat Sasaran',
    'Current': 'Semasa',
    'Min Threshold': 'Ambang Minimum',
    'Max Threshold': 'Ambang Maksimum',
    'pH Level': 'Tahap PH',
    'Acidity Tolerance': 'Toleransi Keasidan',
    'MIN PH': 'MIN PH',
    'MAX PH': 'MAX PH',
    'Apply to Auto-Irrigation': 'Gunakan untuk Pengairan Automatik',
    'Turn Off Auto-Irrigation': 'Matikan Pengairan Automatik',
    'Auto-irrigation turned off': 'Pengairan automatik dimatikan',
    'Failed to turn off auto mode': 'Gagal mematikan mod automatik',
    'Claim a device to control irrigation':
        'Tuntut peranti untuk mengawal pengairan',

    // ── Crop list screen ───────────────────────────────────────────────────
    'Crop Management': 'Pengurusan Tanaman',
    'ACTIVE': 'AKTIF',
    'DEVICES': 'PERANTI',
    'Available Devices': 'Peranti Tersedia',
    'New Found': 'Dijumpai Baru',
    'No Devices Available': 'Tiada Peranti Tersedia',
    'All ESP32 devices are currently assigned':
        'Semua peranti ESP32 sedang ditugaskan',
    'My Crops': 'Tanaman Saya',
    'View All': 'Lihat Semua',
    'No Crops Yet': 'Tiada Tanaman Lagi',
    'Assign an ESP32 device above to start monitoring your first crop':
        'Tugaskan peranti ESP32 di atas untuk mula memantau tanaman pertama anda',
    'Assign': 'Tugaskan',
    'Online': 'Dalam Talian',
    'Weak Signal': 'Isyarat Lemah',
    'No Signal': 'Tiada Isyarat',

    // ── Crop detail screen ─────────────────────────────────────────────────
    'Age': 'Umur',
    'Device': 'Peranti',
    'Sensor Readings': 'Bacaan Penderia',
    'Water Tank': 'Tangki Air',
    'Notes': 'Nota',
    'Open Monitoring': 'Buka Pemantauan',
    'Edit': 'Edit',
    'Delete': 'Padam',
    'Device Online': 'Peranti Dalam Talian',
    'Last seen:': 'Terakhir dilihat:',

    // ── Edit crop screen ───────────────────────────────────────────────────
    'Edit Crop Details': 'Edit Butiran Tanaman',
    'Crop Photo (Optional)': 'Foto Tanaman (Pilihan)',
    'Tap to add a photo': 'Ketik untuk menambah foto',
    'Camera or Gallery': 'Kamera atau Galeri',
    'Update your crop information below':
        'Kemaskini maklumat tanaman anda di bawah',
    'Crop Type': 'Jenis Tanaman',
    'Field Name': 'Nama Padang',
    'e.g., Field A, North Plot, etc.': 'cth., Padang A, Plot Utara, dsb.',
    'Notes (Optional)': 'Nota (Pilihan)',
    'Add any notes about this crop...': 'Tambah nota tentang tanaman ini...',
    'Update Crop': 'Kemas kini Tanaman',
    'Choose Photo Source': 'Pilih Sumber Foto',
    'Take a Photo': 'Ambil Foto',
    'Use your camera': 'Gunakan kamera anda',
    'Choose from Gallery': 'Pilih daripada Galeri',
    'Pick from your photos': 'Pilih daripada foto anda',
    'Remove photo': 'Buang foto',
    'Uploading...': 'Memuat naik...',
    'Change': 'Ubah',
    'Crop updated successfully': 'Tanaman berjaya dikemas kini',
    'Failed to update crop': 'Gagal mengemas kini tanaman',

    // ── Claim device screen ────────────────────────────────────────────────
    'Assign Device': 'Tugaskan Peranti',
    'Select the crop you will grow with this device':
        'Pilih tanaman yang akan anda tanam dengan peranti ini',
    'Field Details (Optional)': 'Butiran Padang (Pilihan)',
    'e.g., Greenhouse A, Field 1': 'cth., Rumah Hijau A, Padang 1',
    'Optional notes about this crop': 'Nota pilihan tentang tanaman ini',
    'What happens after assigning?': 'Apa yang berlaku selepas tugasan?',
    '• Device will be linked to your account':
        '• Peranti akan dipautkan ke akaun anda',
    '• You can assign multiple devices for different crops':
        '• Anda boleh tugaskan berbilang peranti untuk tanaman berbeza',
    '• AI will provide crop-specific recommendations':
        '• AI akan memberi cadangan khusus tanaman',
    '• Switch between crops in the dashboard':
        '• Tukar antara tanaman dalam papan pemuka',
    'This device is already assigned. Assigning will reassign it.':
        'Peranti ini sudah ditugaskan. Tugasan akan menugaskannya semula.',
    'Device already assigned to another farm':
        'Peranti sudah ditugaskan ke ladang lain',
    'ESP32 Controller': 'Pengawal ESP32',

    // ── More / Settings screen ─────────────────────────────────────────────
    'Farm Management': 'Pengurusan Ladang',
    'Farm Location': 'Lokasi Ladang',
    'Set location for weather': 'Tetapkan lokasi untuk cuaca',
    'Farm Details': 'Butiran Ladang',
    'Manage farm information': 'Urus maklumat ladang',
    'Manage farm information ': 'Urus maklumat tanaman',
    'Notifications': 'Pemberitahuan',
    'Alerts and updates': 'Amaran dan kemas kini',
    'Language': 'Bahasa',
    'English': 'Inggeris',
    'Alert Tones': 'Nada Amaran',
    'Sound settings': 'Tetapan bunyi',
    'Change Password': 'Tukar Kata Laluan',
    'Update your password': 'Kemaskini kata laluan anda',
    'About': 'Tentang',
    'App Version': 'Versi Apl',
    'Terms of Service': 'Syarat Perkhidmatan',
    'Privacy Policy': 'Dasar Privasi',
    'Log Out': 'Log Keluar',

    // ── Profile screen ─────────────────────────────────────────────────────
    'Profile': 'Profil',
    'Email': 'E-mel',
    'Phone Number': 'Nombor Telefon',
    'Farm Name': 'Nama Ladang',
    'Save Changes': 'Simpan Perubahan',
    'Cancel': 'Batal',
    'Profile photo updated': 'Foto profil dikemas kini',
    'Profile photo removed': 'Foto profil dialih keluar',
    'Take Photo': 'Ambil Foto',
    'Remove Photo': 'Buang Foto',

    // ── Notifications screen ───────────────────────────────────────────────
    'Clear all': 'Kosongkan semua',
    'All': 'Semua',
    'Critical': 'Kritikal',
    'Devices': 'Peranti',
    'Water': 'Air',
    'Crops': 'Tanaman',
    'Weather': 'Cuaca',
    'System': 'Sistem',
    'Archived': 'Diarkibkan',
    'No notifications': 'Tiada pemberitahuan',
    'Check Archive tab for past alerts':
        'Semak tab Arkib untuk amaran lalu',
    'No archived notifications': 'Tiada pemberitahuan yang diarkibkan',
    'Swipe left on a notification to archive it':
        'Leret kiri pada pemberitahuan untuk mengarkibkannya',
    'Moved back to inbox': 'Dipindahkan kembali ke peti masuk',
    'Notification archived': 'Pemberitahuan diarkibkan',
    'UNDO': 'BUAT SEMULA',
    'Archive': 'Arkib',
    'Unarchive': 'Nyaharkib',
    'Swipe left to archive': 'Leret kiri untuk arkib',

    // ── Alert tone screen ──────────────────────────────────────────────────
    'General': 'Am',
    'Sound': 'Bunyi',
    'Play sound for alerts': 'Mainkan bunyi untuk amaran',
    'Vibration': 'Getaran',
    'Vibrate on alerts': 'Getaran pada amaran',
    'Volume': 'Kelantangan',
    'Alert Volume': 'Kelantangan Amaran',
    'Alert Tone': 'Nada Amaran',
    'Default': 'Lalai',
    'Alert': 'Amaran',
    'Chime': 'Bunyi Loceng',
    'Bell': 'Loceng',
    'Water Drop': 'Titisan Air',
    'None (Silent)': 'Tiada (Senyap)',

    // ── Change password screen ─────────────────────────────────────────────
    'Choose a strong password that you don\'t use elsewhere':
        'Pilih kata laluan yang kuat yang anda tidak gunakan di tempat lain',
    'Current Password': 'Kata Laluan Semasa',
    'New Password': 'Kata Laluan Baru',
    'Confirm New Password': 'Sahkan Kata Laluan Baru',
    'Password Requirements': 'Keperluan Kata Laluan',
    'At least 8 characters': 'Sekurang-kurangnya 8 aksara',
    'One uppercase letter': 'Satu huruf besar',
    'One lowercase letter': 'Satu huruf kecil',
    'One number': 'Satu nombor',
    'Incorrect current password': 'Kata laluan semasa tidak betul',
    'Password too weak': 'Kata laluan terlalu lemah',
    'Please log in again to change your password':
        'Sila log masuk semula untuk menukar kata laluan',

    // ── Farm details screen ────────────────────────────────────────────────
    'Farm Information': 'Maklumat Ladang',
    'Farm Size (acres)': 'Saiz Ladang (ekar)',
    'Active Crops': 'Tanaman Aktif',
    'No active crops': 'Tiada tanaman aktif',
    'Connected Devices': 'Peranti Bersambung',
    'No devices connected': 'Tiada peranti bersambung',

    // ── Farm location screen ───────────────────────────────────────────────
    'Setup Location': 'Tetapan Lokasi',
    'Search farm address or city...': 'Cari alamat ladang atau bandar...',
    'Fetching location...': 'Mendapatkan lokasi...',
    'DRAG TO ADJUST': 'SERET UNTUK LARAS',
    'Confirm Location': 'Sahkan Lokasi',

    // ── AI chatbot screen ──────────────────────────────────────────────────
    'AI Assistant': 'Pembantu AI',
    'Smart Crop Recommendations': 'Cadangan Tanaman Pintar',
    'Ask AI': 'Tanya AI',
    'Select Crop': 'Pilih Tanaman',
    'Vegetable Type': 'Jenis Sayuran',
    'Get Recommendations': 'Dapatkan Cadangan',
    'Optimal Settings': 'Tetapan Optimum',
    'Moisture Range': 'Julat Kelembapan',
    'Ideal pH': 'pH Ideal',
    'Best Time': 'Masa Terbaik',
    'Frequency': 'Kekerapan',
    'Have questions about your crop?': 'Ada soalan tentang tanaman anda?',
    'Chat with your AI farm advisor': 'Berbual dengan penasihat ladang AI anda',
    'AI Farm Advisor': 'Penasihat Ladang AI',
    'Analyzing your farm...': 'Menganalisis ladang anda...',
    'Suggested': 'Dicadangkan',
    'Settings applied! Redirecting to irrigation...':
        'Tetapan digunakan! Mengubah hala ke pengairan...',
    'Failed to apply settings': 'Gagal menggunakan tetapan',
    'No crop selected': 'Tiada tanaman dipilih',

    // ── Sensor analytics / graph screen ───────────────────────────────────
    'Sensor Analytics': 'Analitik Penderia',
    '24 Hours': '24 Jam',
    '7 Days': '7 Hari',
    'Water Level': 'Tahap Air',
    'TREND ANALYSIS': 'ANALISIS ALIRAN',
    'Cold': 'Sejuk',
    'Hot': 'Panas',
    'Ideal': 'Ideal',
    'Dry': 'Kering',
    'Humid': 'Lembap',
    'Neutral': 'Neutral',
    'Full': 'Penuh',
    'Moisture dropping fast': 'Kelembapan jatuh dengan cepat',
    'Low moisture detected': 'Kelembapan rendah dikesan',
    'Moisture levels stable': 'Tahap kelembapan stabil',
    'High temperature alert': 'Amaran suhu tinggi',
    'Low temperature warning': 'Amaran suhu rendah',
    'Temperature optimal': 'Suhu optimum',
    'High humidity detected': 'Kelembapan tinggi dikesan',
    'Low humidity alert': 'Amaran kelembapan rendah',
    'Humidity levels normal': 'Tahap kelembapan normal',
    'Soil too acidic': 'Tanah terlalu berasid',
    'Soil too alkaline': 'Tanah terlalu alkali',
    'pH level optimal': 'Tahap pH optimum',
    'Rapid water depletion': 'Pengehabisan air dengan cepat',
    'Critical water level': 'Tahap air kritikal',
    'Low water level': 'Tahap air rendah',
    'Water supply adequate': 'Bekalan air mencukupi',
    'No data available': 'Tiada data tersedia',
    'Failed to load sensor data': 'Gagal memuatkan data penderia',
    'Retry': 'Cuba Semula',
    'Daily Usage': 'Penggunaan Harian',

    // ── Appearance ────────────────────────────────────────────────────────
    'Appearance': 'Penampilan',
    'Dark Mode': 'Mod Gelap',
    'On': 'Hidup',
    'Off': 'Mati',

    // ── Language screen ────────────────────────────────────────────────────
    'Language changed to English': 'Bahasa ditukar kepada Inggeris',
    'Language changed to Malay': 'Bahasa ditukar kepada Melayu',

    // ── Logout dialog ──────────────────────────────────────────────────────
    'Log out': 'Log Keluar',
    'Are you sure you want to log out?':
        'Adakah anda pasti ingin log keluar?',
    'Are you sure you want to log out of your account?':
        'Adakah anda pasti ingin log keluar daripada akaun anda?',
    'Are you sure you want to logout?': 'Adakah anda pasti ingin log keluar?',
  };
}

// ---------------------------------------------------------------------------
// InheritedWidget scope
// ---------------------------------------------------------------------------

class _AppLocalizationsScope extends InheritedWidget {
  final AppLocalizations localizations;

  const _AppLocalizationsScope({
    required this.localizations,
    required super.child,
  });

  @override
  bool updateShouldNotify(_AppLocalizationsScope old) =>
      localizations.languageCode != old.localizations.languageCode;
}

/// Wrap this above [MaterialApp] (or above the route tree) to provide
/// [AppLocalizations] to all descendants.
class AppLocalizationsProvider extends StatelessWidget {
  final String languageCode;
  final Widget child;

  const AppLocalizationsProvider({
    super.key,
    required this.languageCode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _AppLocalizationsScope(
      localizations: AppLocalizations(languageCode),
      child: child,
    );
  }
}
