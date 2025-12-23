import 'package:flutter/material.dart';

/// App-wide string constants
class AppStrings {
  // App Info
  static const String appName = 'IoT Smart Farm';
  static const String appTagline = 'Smart Farming Solutions';
  static const String appVersion = '1.0.0';

  // Authentication
  static const String login = 'Login';
  static const String register = 'Register';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String fullName = 'Full Name';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';
  static const String signInWithGoogle = 'Sign in with Google';
  static const String signUpWithGoogle = 'Sign up with Google';
  static const String orContinueWith = 'Or continue with';
  static const String logout = 'Logout';
  static const String logoutConfirmation = 'Are you sure you want to logout?';

  // Navigation
  static const String home = 'Home';
  static const String sensors = 'Sensors';
  static const String water = 'Water';
  static const String aiAssist = 'AI Assist';
  static const String more = 'More';

  // Dashboard
  static const String activeField = 'Active Field';
  static const String overview = 'Overview';
  static const String online = 'ONLINE';
  static const String offline = 'OFFLINE';
  static const String today = 'Today';

  // Sensors
  static const String soilMoisture = 'Soil Moisture';
  static const String phLevel = 'pH Level';
  static const String temperature = 'Temperature';
  static const String humidity = 'Humidity';
  static const String waterTankLevel = 'Water Tank Level';
  static const String lightIntensity = 'Light Intensity';
  static const String rainfall = 'Rainfall';

  // Sensor Status
  static const String normal = 'Normal';
  static const String optimal = 'Optimal';
  static const String warning = 'Warning';
  static const String critical = 'Critical';
  static const String highWarning = 'High Warning';
  static const String lowWarning = 'Low Warning';
  static const String criticalLow = 'CRITICAL LOW';
  static const String criticalHigh = 'CRITICAL HIGH';

  // Weather
  static const String weather = 'Weather';
  static const String sunny = 'Sunny';
  static const String cloudy = 'Cloudy';
  static const String rainy = 'Rainy';
  static const String partlyCloudy = 'Partly Cloudy';
  static const String precipitation = 'Precip';
  static const String windSpeed = 'Wind';

  // Irrigation
  static const String irrigation = 'Irrigation';
  static const String irrigationControl = 'Irrigation Control';
  static const String manualControl = 'Manual Control';
  static const String autoMode = 'Auto Mode';
  static const String scheduleIrrigation = 'Schedule Irrigation';
  static const String waterNow = 'Water Now';
  static const String stopWatering = 'Stop Watering';
  static const String duration = 'Duration';
  static const String startTime = 'Start Time';
  static const String endTime = 'End Time';

  // Crop Management
  static const String crops = 'Crops';
  static const String myCrops = 'My Crops';
  static const String addCrop = 'Add Crop';
  static const String cropType = 'Crop Type';
  static const String plantingDate = 'Planting Date';
  static const String harvestDate = 'Harvest Date';
  static const String claimDevice = 'Claim Device';
  static const String unclaimDevice = 'Unclaim Device';
  static const String deviceId = 'Device ID';
  static const String enterDeviceId = 'Enter Device ID';

  // Device
  static const String devices = 'Devices';
  static const String myDevices = 'My Devices';
  static const String deviceStatus = 'Device Status';
  static const String connected = 'Connected';
  static const String disconnected = 'Disconnected';
  static const String lastSeen = 'Last Seen';

  // Profile & Settings
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String settings = 'Settings';
  static const String farmLocation = 'Farm Location';
  static const String setLocation = 'Set Location';
  static const String farmDetails = 'Farm Details';
  static const String notifications = 'Notifications';
  static const String language = 'Language';
  static const String alertTone = 'Alert Tone';
  static const String changePassword = 'Change Password';
  static const String currentPassword = 'Current Password';
  static const String newPassword = 'New Password';
  static const String privacyPolicy = 'Privacy Policy';
  static const String termsOfService = 'Terms of Service';
  static const String aboutUs = 'About Us';
  static const String helpSupport = 'Help & Support';

  // AI Chatbot
  static const String aiChatbot = 'AI Farm Assistant';
  static const String askAnything = 'Ask me anything about farming...';
  static const String typeMessage = 'Type a message...';
  static const String send = 'Send';

  // Common Actions
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String update = 'Update';
  static const String confirm = 'Confirm';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String ok = 'OK';
  static const String done = 'Done';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String skip = 'Skip';
  static const String retry = 'Retry';
  static const String refresh = 'Refresh';
  static const String loading = 'Loading...';
  static const String pleaseWait = 'Please wait...';

  // Error Messages
  static const String errorOccurred = 'An error occurred';
  static const String networkError =
      'Network error. Please check your connection.';
  static const String sessionExpired = 'Session expired. Please login again.';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPassword =
      'Password must be at least 6 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String fieldRequired = 'This field is required';
  static const String somethingWentWrong =
      'Something went wrong. Please try again.';
  static const String noDataAvailable = 'No data available';
  static const String noInternetConnection = 'No internet connection';

  // Success Messages
  static const String success = 'Success';
  static const String savedSuccessfully = 'Saved successfully';
  static const String updatedSuccessfully = 'Updated successfully';
  static const String deletedSuccessfully = 'Deleted successfully';
  static const String passwordResetEmailSent = 'Password reset email sent';
  static const String profileUpdated = 'Profile updated successfully';

  // Units
  static const String celsius = '°C';
  static const String fahrenheit = '°F';
  static const String percent = '%';
  static const String kmPerHour = 'km/h';
  static const String liters = 'L';
  static const String millimeters = 'mm';
  static const String lux = 'lux';
}

/// App-wide padding and spacing constants
class AppPadding {
  // Base spacing unit (4.0)
  static const double unit = 4.0;

  // Standard padding values
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Screen padding
  static const double screenHorizontal = 16.0;
  static const double screenVertical = 16.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
  );

  // Card padding
  static const double cardPadding = 16.0;
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);

  // List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  // Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 14.0,
  );

  // Input field padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 16.0,
  );

  // Dialog padding
  static const EdgeInsets dialogPadding = EdgeInsets.all(24.0);

  // Bottom sheet padding
  static const EdgeInsets bottomSheetPadding = EdgeInsets.fromLTRB(
    16,
    16,
    16,
    32,
  );
}

/// App-wide spacing for gaps between widgets
class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double xxxxl = 48.0;

  // SizedBox helpers
  static const SizedBox verticalXxs = SizedBox(height: xxs);
  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalSm = SizedBox(height: sm);
  static const SizedBox verticalMd = SizedBox(height: md);
  static const SizedBox verticalLg = SizedBox(height: lg);
  static const SizedBox verticalXl = SizedBox(height: xl);
  static const SizedBox verticalXxl = SizedBox(height: xxl);
  static const SizedBox verticalXxxl = SizedBox(height: xxxl);

  static const SizedBox horizontalXxs = SizedBox(width: xxs);
  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalSm = SizedBox(width: sm);
  static const SizedBox horizontalMd = SizedBox(width: md);
  static const SizedBox horizontalLg = SizedBox(width: lg);
  static const SizedBox horizontalXl = SizedBox(width: xl);
  static const SizedBox horizontalXxl = SizedBox(width: xxl);
}

/// App-wide border radius constants
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 9999.0;

  // BorderRadius helpers
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(md),
  );
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chipRadius = BorderRadius.all(
    Radius.circular(full),
  );
  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(xl),
  );
}

/// App-wide icon constants
class AppIcons {
  // Navigation
  static const IconData home = Icons.dashboard_outlined;
  static const IconData homeActive = Icons.dashboard;
  static const IconData sensors = Icons.show_chart;
  static const IconData sensorsActive = Icons.show_chart;
  static const IconData water = Icons.water_drop_outlined;
  static const IconData waterActive = Icons.water_drop;
  static const IconData aiAssist = Icons.smart_toy_outlined;
  static const IconData aiAssistActive = Icons.smart_toy;
  static const IconData more = Icons.menu;
  static const IconData moreActive = Icons.menu;

  // Sensors
  static const IconData soilMoisture = Icons.water_drop;
  static const IconData phLevel = Icons.science;
  static const IconData temperature = Icons.thermostat;
  static const IconData humidity = Icons.cloud;
  static const IconData waterTank = Icons.water;
  static const IconData lightIntensity = Icons.wb_sunny;
  static const IconData rainfall = Icons.grain;

  // Weather
  static const IconData sunny = Icons.wb_sunny;
  static const IconData cloudy = Icons.cloud;
  static const IconData rainy = Icons.water_drop;
  static const IconData partlyCloudy = Icons.cloud_queue;
  static const IconData wind = Icons.air;
  static const IconData precipitation = Icons.water_drop;

  // Status
  static const IconData checkCircle = Icons.check_circle;
  static const IconData warning = Icons.warning;
  static const IconData error = Icons.error;
  static const IconData info = Icons.info;
  static const IconData online = Icons.circle;
  static const IconData offline = Icons.circle_outlined;

  // Actions
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit;
  static const IconData delete = Icons.delete;
  static const IconData save = Icons.save;
  static const IconData refresh = Icons.refresh;
  static const IconData settings = Icons.settings;
  static const IconData search = Icons.search;
  static const IconData filter = Icons.filter_list;
  static const IconData sort = Icons.sort;
  static const IconData share = Icons.share;
  static const IconData download = Icons.download;
  static const IconData upload = Icons.upload;

  // Navigation Actions
  static const IconData back = Icons.arrow_back;
  static const IconData forward = Icons.arrow_forward;
  static const IconData close = Icons.close;
  static const IconData menu = Icons.menu;
  static const IconData moreVert = Icons.more_vert;
  static const IconData moreHoriz = Icons.more_horiz;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData expandMore = Icons.expand_more;
  static const IconData expandLess = Icons.expand_less;

  // Profile & Settings
  static const IconData profile = Icons.person;
  static const IconData profileOutlined = Icons.person_outline;
  static const IconData logout = Icons.logout;
  static const IconData login = Icons.login;
  static const IconData notification = Icons.notifications;
  static const IconData notificationOutlined = Icons.notifications_outlined;
  static const IconData language = Icons.language;
  static const IconData location = Icons.location_on;
  static const IconData locationOutlined = Icons.location_on_outlined;
  static const IconData lock = Icons.lock;
  static const IconData lockOutlined = Icons.lock_outline;
  static const IconData help = Icons.help;
  static const IconData helpOutlined = Icons.help_outline;
  static const IconData privacy = Icons.privacy_tip;
  static const IconData terms = Icons.description;
  static const IconData about = Icons.info;
  static const IconData alertTone = Icons.volume_up;

  // Devices & Farm
  static const IconData device = Icons.devices;
  static const IconData esp32 = Icons.memory;
  static const IconData crop = Icons.eco;
  static const IconData farm = Icons.agriculture;
  static const IconData plant = Icons.local_florist;
  static const IconData calendar = Icons.calendar_today;
  static const IconData schedule = Icons.schedule;
  static const IconData timer = Icons.timer;

  // Communication
  static const IconData email = Icons.email;
  static const IconData emailOutlined = Icons.email_outlined;
  static const IconData phone = Icons.phone;
  static const IconData chat = Icons.chat;
  static const IconData chatOutlined = Icons.chat_bubble_outline;
  static const IconData send = Icons.send;

  // Auth
  static const IconData google = Icons.g_mobiledata;
  static const IconData visibility = Icons.visibility;
  static const IconData visibilityOff = Icons.visibility_off;
}

/// App-wide duration constants for animations
class AppDurations {
  static const Duration instant = Duration.zero;
  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 700);

  // Specific animations
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration snackbar = Duration(seconds: 3);
  static const Duration splash = Duration(seconds: 2);
  static const Duration debounce = Duration(milliseconds: 500);
  static const Duration throttle = Duration(milliseconds: 1000);
}

/// App-wide size constants
class AppSizes {
  // Icon sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double iconXxl = 64.0;

  // Avatar sizes
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 96.0;

  // Button heights
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 48.0;
  static const double buttonHeightLg = 56.0;

  // Input heights
  static const double inputHeight = 56.0;

  // Card sizes
  static const double sensorCardHeight = 140.0;
  static const double weatherCardHeight = 120.0;

  // Bottom navigation
  static const double bottomNavHeight = 80.0;

  // App bar
  static const double appBarHeight = 56.0;

  // Max widths
  static const double maxContentWidth = 600.0;
  static const double maxCardWidth = 400.0;
}

/// Firebase collection names
class FirebaseCollections {
  static const String users = 'users';
  static const String crops = 'crops';
  static const String devices = 'devices';
  static const String irrigationRules = 'irrigation_rules';
  static const String sensorErrors = 'sensor_errors';
}

/// Firebase Realtime Database paths
class FirebasePaths {
  static const String sensorData = 'sensor_data';
  static const String sensorHistory = 'sensor_history';
  static const String deviceStatus = 'device_status';
}

/// Sensor thresholds for status determination
class SensorThresholds {
  // Soil Moisture (%)
  static const double soilMoistureLow = 30.0;
  static const double soilMoistureHigh = 80.0;
  static const double soilMoistureCriticalLow = 20.0;
  static const double soilMoistureCriticalHigh = 90.0;

  // pH Level
  static const double phLevelLow = 5.5;
  static const double phLevelHigh = 7.5;
  static const double phLevelOptimalLow = 6.0;
  static const double phLevelOptimalHigh = 7.0;

  // Temperature (°C)
  static const double temperatureLow = 15.0;
  static const double temperatureHigh = 30.0;
  static const double temperatureCriticalLow = 10.0;
  static const double temperatureCriticalHigh = 35.0;

  // Humidity (%)
  static const double humidityLow = 30.0;
  static const double humidityHigh = 70.0;
  static const double humidityCriticalLow = 20.0;
  static const double humidityCriticalHigh = 85.0;

  // Water Tank (%)
  static const double waterTankLow = 25.0;
  static const double waterTankCriticalLow = 15.0;
}
