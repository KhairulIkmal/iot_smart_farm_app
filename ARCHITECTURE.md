# IoT Smart Farm App - Architecture Guide

## Clean Architecture Overview

This app follows a **clean, centralized styling architecture** with three main layers:

### 1. Core Theme Layer (`lib/core/theme.dart`)
**Purpose**: Define all global colors, text styles, and default widget themes

**What's here:**
- `AppColors` - All color constants (primary, background, status colors, etc.)
- `AppTextStyles` - Typography styles (headings, body text, labels)
- `AppTheme` - Global theme configuration for dark and light modes
  - Default button styles
  - Default input decoration (with `filled: false` for flexibility)
  - Card themes
  - Navigation themes
  - All Material widget themes

**When to update:**
- Adding new colors to the app
- Changing global font sizes or weights
- Modifying default widget appearances across the entire app

---

### 2. Reusable Widgets Layer (`lib/widgets/`)
**Purpose**: Pre-styled, reusable UI components that use the core theme

**Available Widgets:**

#### `CustomButton` ([custom_button.dart](lib/widgets/custom_button.dart))
Pre-styled buttons with loading states and multiple variants:
```dart
// Primary button (filled green)
CustomButton.primary(
  text: 'Save',
  onPressed: () {},
  isLoading: false,
)

// Secondary button (outlined)
CustomButton.secondary(
  text: 'Cancel',
  onPressed: () {},
)

// Danger button (filled red)
CustomButton.danger(
  text: 'Delete',
  onPressed: () {},
)

// Ghost button (text only)
CustomButton.ghost(
  text: 'Skip',
  onPressed: () {},
)
```

#### `CustomTextField` ([custom_text_field.dart](lib/widgets/custom_text_field.dart))
Pre-styled text inputs with dark green theme:
```dart
// Standard field
CustomTextField(
  controller: controller,
  label: 'Full Name',
  icon: Icons.person_outline,
  enabled: true,
)

// Phone field
CustomTextField.phone(
  controller: phoneController,
  label: 'Phone Number',
)

// Email field
CustomTextField.email(
  controller: emailController,
  label: 'Email Address',
)

// Password field with visibility toggle
CustomTextField.password(
  controller: passwordController,
  label: 'Password',
)

// Multiline text area
CustomTextField.multiline(
  controller: notesController,
  label: 'Notes',
  maxLines: 4,
)
```

#### `CustomTile` ([custom_tile.dart](lib/widgets/custom_tile.dart))
Pre-styled list/menu items:
```dart
// Menu item
CustomTile.menu(
  icon: Icons.settings,
  iconColor: AppColors.primary,
  title: 'Settings',
  onTap: () {},
)

// Toggle item
CustomTile.toggle(
  icon: Icons.notifications,
  iconColor: AppColors.info,
  title: 'Notifications',
  value: true,
  onChanged: (value) {},
)

// Info item (non-interactive)
CustomTile.info(
  icon: Icons.info,
  iconColor: AppColors.primary,
  title: 'App Version',
  value: '1.0.0',
)
```

#### `LoadingIndicator` ([loading_indicator.dart](lib/widgets/loading_indicator.dart))
Pre-styled loading states:
```dart
// Circular loading
LoadingIndicator.circular(
  message: 'Loading...',
)

// Full screen overlay
LoadingIndicator.overlay(
  message: 'Saving changes...',
)

// Inline loading (for buttons)
LoadingIndicator.inline()

// Skeleton loaders
SkeletonLoader.card()
SkeletonLoader.text()
SkeletonLoader.avatar()
```

**When to update:**
- Need a new reusable component (create new widget file)
- Modify behavior/styling of existing widgets
- Add new variants to existing widgets

---

### 3. Feature Screens Layer (`lib/features/`)
**Purpose**: Screen-specific UI that composes the reusable widgets

**What screens should do:**
- Import widgets: `import '../../../widgets/index.dart';`
- Use custom widgets instead of manual styling
- Focus on business logic, not styling
- Only add custom styling for truly unique screen-specific needs

**Example - Profile Screen (BEFORE):**
```dart
// ❌ Old way - Manual styling in every screen
Widget _buildTextField({...}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
    ),
    child: TextFormField(
      decoration: InputDecoration(
        filled: false,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        // ... 20+ lines of styling code
      ),
    ),
  );
}
```

**Example - Profile Screen (AFTER):**
```dart
// ✅ New way - Clean, uses custom widgets
CustomTextField(
  controller: _nameController,
  label: 'Full Name',
  icon: Icons.person_outline,
  enabled: _isEditing,
)
```

**Benefits:**
- Profile screen went from ~403 lines to ~320 lines
- All styling is centralized in `CustomTextField`
- Consistent look across all screens automatically
- Easy to update styling globally

---

## File Organization

```
lib/
├── core/
│   └── theme.dart              # Global colors, text styles, theme config
├── widgets/
│   ├── index.dart              # Export all widgets (import this!)
│   ├── custom_button.dart      # Reusable buttons
│   ├── custom_text_field.dart  # Reusable text inputs
│   ├── custom_tile.dart        # Reusable list items
│   └── loading_indicator.dart  # Reusable loading states
└── features/
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── dashboard/
    │   └── dashboard_screen.dart
    ├── sensors/
    │   └── sensors_screen.dart
    └── more/
        └── profile/
            └── profile_screen.dart  # Uses CustomTextField, CustomButton
```

---

## How to Add Styling

### ✅ DO - Add Global Colors
```dart
// In lib/core/theme.dart
class AppColors {
  static const Color newColor = Color(0xFF123456);
}
```

### ✅ DO - Create Reusable Widgets
```dart
// In lib/widgets/custom_card.dart
class CustomCard extends StatelessWidget {
  // ... pre-styled card using AppColors
}

// In lib/widgets/index.dart
export 'custom_card.dart';
```

### ✅ DO - Use Custom Widgets in Screens
```dart
// In feature screens
import '../../widgets/index.dart';

CustomButton.primary(text: 'Submit', onPressed: () {})
```

### ❌ DON'T - Add Manual Styling in Screens
```dart
// ❌ Avoid this
Container(
  decoration: BoxDecoration(
    color: Color(0xFF1C2E1F),  // Hardcoded color
    borderRadius: BorderRadius.circular(16),
  ),
  child: TextFormField(...),
)
```

### ❌ DON'T - Duplicate Styling Code
```dart
// ❌ If you find yourself copying styling code between screens,
// create a reusable widget instead!
```

---

## Theme Customization Examples

### Example 1: Change Primary Color App-Wide
```dart
// In lib/core/theme.dart
class AppColors {
  static const Color primary = Color(0xFF13EC37); // Change this one line
  // All buttons, borders, icons update automatically!
}
```

### Example 2: Add New Button Variant
```dart
// In lib/widgets/custom_button.dart
enum CustomButtonStyle { primary, secondary, danger, ghost, success }

factory CustomButton.success({...}) {
  return CustomButton(
    style: CustomButtonStyle.success,
    customColor: AppColors.success,
    ...
  );
}
```

### Example 3: Create Screen-Specific Widget
```dart
// If a widget is ONLY used on one screen and won't be reused:
// lib/features/dashboard/widgets/sensor_gauge.dart
class SensorGauge extends StatelessWidget {
  // Custom gauge widget specific to dashboard
  // Still uses AppColors from theme
}
```

---

## Best Practices

1. **One Source of Truth**: All colors in `AppColors`, all reusable styles in `lib/widgets/`
2. **Composition over Duplication**: Use custom widgets, don't copy-paste styling code
3. **Import Once**: Use `import 'widgets/index.dart'` to get all widgets
4. **Theme First**: Check if theme.dart has what you need before adding custom styles
5. **Widget Second**: Check if a custom widget exists before building custom UI
6. **Custom Last**: Only add custom styling when truly unique to that screen

---

## Migration Checklist

When updating old screens to use this architecture:

- [ ] Import `widgets/index.dart`
- [ ] Replace manual text fields with `CustomTextField`
- [ ] Replace manual buttons with `CustomButton`
- [ ] Replace manual list items with `CustomTile`
- [ ] Replace manual loading states with `LoadingIndicator`
- [ ] Remove duplicate styling code
- [ ] Verify colors come from `AppColors`
- [ ] Test that theme still looks correct

---

## Summary

Your app now has a **clean, centralized architecture**:

1. **`lib/core/theme.dart`** - Single source of truth for all colors and default styles
2. **`lib/widgets/`** - Reusable, pre-styled components (buttons, fields, tiles, loaders)
3. **`lib/features/`** - Screens that compose widgets, focused on logic not styling

This makes it easy to:
- Update styling globally (change one file)
- Build screens faster (use pre-styled widgets)
- Maintain consistency (all screens use same components)
- Reduce code duplication (no copy-paste styling)

**You already had this architecture started** - I just completed it by adding `CustomTextField` to match your existing `CustomButton`, `CustomTile`, and `LoadingIndicator` widgets!
