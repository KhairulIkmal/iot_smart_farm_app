/// ------------------------------------------------------------
/// VALIDATORS
///
/// Pure validation logic only.
/// No Firebase, no UI, no BuildContext.
///
/// Usage:
/// ```dart
/// if (!Validators.isValidEmail(email)) {
///   // show error
/// }
/// ```
/// ------------------------------------------------------------
class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  /// Check if email is valid format
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;

    // RFC 5322 compliant email regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );

    return emailRegex.hasMatch(email.trim());
  }

  /// Get email validation error message
  static String? getEmailError(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  /// Check if password meets minimum requirements
  /// - At least 8 characters
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one number
  static bool isValidPassword(String? password) {
    if (password == null || password.isEmpty) return false;

    return password.length >= 8 &&
        hasUpperCase(password) &&
        hasLowerCase(password) &&
        hasDigit(password);
  }

  /// Check if password has minimum length
  static bool hasMinLength(String? password, [int minLength = 8]) {
    return password != null && password.length >= minLength;
  }

  /// Check if password contains uppercase letter
  static bool hasUpperCase(String? password) {
    return password != null && RegExp(r'[A-Z]').hasMatch(password);
  }

  /// Check if password contains lowercase letter
  static bool hasLowerCase(String? password) {
    return password != null && RegExp(r'[a-z]').hasMatch(password);
  }

  /// Check if password contains digit
  static bool hasDigit(String? password) {
    return password != null && RegExp(r'[0-9]').hasMatch(password);
  }

  /// Check if password contains special character
  static bool hasSpecialChar(String? password) {
    return password != null &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  /// Get password validation error message
  static String? getPasswordError(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!hasUpperCase(password)) {
      return 'Password must contain an uppercase letter';
    }
    if (!hasLowerCase(password)) {
      return 'Password must contain a lowercase letter';
    }
    if (!hasDigit(password)) {
      return 'Password must contain a number';
    }
    return null;
  }

  /// Get list of password requirement checks
  static List<PasswordRequirement> getPasswordRequirements(String? password) {
    return [
      PasswordRequirement(
        text: 'At least 8 characters',
        isMet: hasMinLength(password),
      ),
      PasswordRequirement(
        text: 'One uppercase letter',
        isMet: hasUpperCase(password),
      ),
      PasswordRequirement(
        text: 'One lowercase letter',
        isMet: hasLowerCase(password),
      ),
      PasswordRequirement(text: 'One number', isMet: hasDigit(password)),
    ];
  }

  // ============================================================
  // CONFIRM PASSWORD VALIDATION
  // ============================================================

  /// Check if passwords match
  static bool passwordsMatch(String? password, String? confirmPassword) {
    if (password == null || confirmPassword == null) return false;
    return password == confirmPassword;
  }

  /// Get confirm password error message
  static String? getConfirmPasswordError(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (!passwordsMatch(password, confirmPassword)) {
      return 'Passwords do not match';
    }
    return null;
  }

  // ============================================================
  // GENERAL TEXT VALIDATION
  // ============================================================

  /// Check if value is not empty
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Check if value has minimum length
  static bool hasMinimumLength(String? value, int minLength) {
    return value != null && value.trim().length >= minLength;
  }

  /// Check if value has maximum length
  static bool hasMaximumLength(String? value, int maxLength) {
    return value == null || value.trim().length <= maxLength;
  }

  /// Check if value is within length range
  static bool isWithinLengthRange(String? value, int min, int max) {
    return hasMinimumLength(value, min) && hasMaximumLength(value, max);
  }

  /// Get required field error
  static String? getRequiredError(String? value, String fieldName) {
    if (!isNotEmpty(value)) {
      return '$fieldName is required';
    }
    return null;
  }

  // ============================================================
  // NAME VALIDATION
  // ============================================================

  /// Check if name is valid (letters, spaces, hyphens, apostrophes)
  static bool isValidName(String? name) {
    if (name == null || name.trim().isEmpty) return false;

    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    return nameRegex.hasMatch(name.trim()) && name.trim().length >= 2;
  }

  /// Get name validation error
  static String? getNameError(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Name is required';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!isValidName(name)) {
      return 'Name can only contain letters';
    }
    return null;
  }

  // ============================================================
  // PHONE VALIDATION
  // ============================================================

  /// Check if phone number is valid
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;

    // Remove spaces, dashes, and parentheses
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Allow + at start for international
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
    return phoneRegex.hasMatch(cleaned);
  }

  /// Get phone validation error
  static String? getPhoneError(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }
    if (!isValidPhone(phone)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // ============================================================
  // CROP / FARM VALIDATION
  // ============================================================

  /// Check if crop name is valid
  static bool isValidCropName(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    return name.trim().length >= 2 && name.trim().length <= 50;
  }

  /// Get crop name error
  static String? getCropNameError(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Crop name is required';
    }
    if (name.trim().length < 2) {
      return 'Crop name must be at least 2 characters';
    }
    if (name.trim().length > 50) {
      return 'Crop name must be less than 50 characters';
    }
    return null;
  }

  /// Check if field name is valid
  static bool isValidFieldName(String? name) {
    if (name == null || name.trim().isEmpty) return true; // Optional
    return name.trim().length <= 50;
  }

  // ============================================================
  // NUMERIC / THRESHOLD VALIDATION
  // ============================================================

  /// Check if value is a valid number
  static bool isValidNumber(String? value) {
    if (value == null || value.isEmpty) return false;
    return double.tryParse(value) != null;
  }

  /// Check if threshold is valid (within range)
  static bool isValidThreshold(
    double? value, {
    double min = 0,
    double max = 100,
  }) {
    if (value == null) return false;
    return value >= min && value <= max;
  }

  /// Check if percentage is valid (0-100)
  static bool isValidPercentage(double? value) {
    return isValidThreshold(value, min: 0, max: 100);
  }

  /// Check if pH is valid (0-14)
  static bool isValidPH(double? value) {
    return isValidThreshold(value, min: 0, max: 14);
  }

  /// Check if temperature is valid (-50 to 100)
  static bool isValidTemperature(double? value) {
    return isValidThreshold(value, min: -50, max: 100);
  }

  /// Get threshold error
  static String? getThresholdError(
    double? value,
    String fieldName, {
    double min = 0,
    double max = 100,
  }) {
    if (value == null) {
      return '$fieldName is required';
    }
    if (value < min) {
      return '$fieldName must be at least $min';
    }
    if (value > max) {
      return '$fieldName must be at most $max';
    }
    return null;
  }

  // ============================================================
  // DEVICE ID VALIDATION
  // ============================================================

  /// Check if device ID is valid format
  static bool isValidDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return false;

    // Device ID format: alphanumeric with underscores, 6-20 chars
    final deviceIdRegex = RegExp(r'^[a-zA-Z0-9_]{6,20}$');
    return deviceIdRegex.hasMatch(deviceId);
  }

  /// Get device ID error
  static String? getDeviceIdError(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      return 'Device ID is required';
    }
    if (!isValidDeviceId(deviceId)) {
      return 'Invalid device ID format';
    }
    return null;
  }

  // ============================================================
  // COORDINATES VALIDATION
  // ============================================================

  /// Check if latitude is valid (-90 to 90)
  static bool isValidLatitude(double? lat) {
    return lat != null && lat >= -90 && lat <= 90;
  }

  /// Check if longitude is valid (-180 to 180)
  static bool isValidLongitude(double? lng) {
    return lng != null && lng >= -180 && lng <= 180;
  }

  /// Check if coordinates are valid
  static bool isValidCoordinates(double? lat, double? lng) {
    return isValidLatitude(lat) && isValidLongitude(lng);
  }
}

/// Password requirement model
class PasswordRequirement {
  final String text;
  final bool isMet;

  const PasswordRequirement({required this.text, required this.isMet});
}
