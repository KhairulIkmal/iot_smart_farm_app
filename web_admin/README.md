# Smart Farm Admin Web Panel

A simple, lightweight admin dashboard for managing the Smart Farm IoT system.

## Features

- **Dashboard Overview** - View system statistics and recent activity
- **User Management** - View and manage all registered farmers
- **Crops Management** - Monitor all crops and their status
- **Device Management** - Track connected ESP32 devices
- **Notifications** - View and manage system notifications
- **Reports & Analytics** - Generate reports for crops and farmers

## Setup Instructions

### 1. Create Admin User in Firebase

You need to create an admin user account in Firebase Authentication:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **iot-smartfarm-system**
3. Go to **Authentication** → **Users**
4. Click **Add User**
5. Create admin account:
   - Email: `admin@smartfarm.com` (or any email with "admin")
   - Password: Create a strong password
6. Click **Add User**

### 2. (Optional) Add Admin Role in Firestore

For better security, you can add an admin role field:

1. Go to **Firestore Database**
2. Find the user document for your admin
3. Add a field:
   - Field: `role`
   - Type: `string`
   - Value: `admin`

### 3. Run the Admin Panel

#### Option A: Using Live Server (Recommended)

1. Install [Live Server](https://marketplace.visualstudio.com/items?itemName=ritwickdey.LiveServer) extension in VS Code
2. Right-click on `index.html`
3. Select **Open with Live Server**
4. Admin panel will open at `http://127.0.0.1:5500/web_admin/`

#### Option B: Using Python HTTP Server

```bash
# Navigate to web_admin directory
cd web_admin

# Python 3
python -m http.server 8000

# Open browser to http://localhost:8000
```

#### Option C: Direct File Access

Simply open `index.html` in your web browser (Note: Some features may not work due to CORS)

### 4. Login

1. Enter admin credentials:
   - Email: `admin@smartfarm.com`
   - Password: (the password you created)
2. Click **Sign In**

## File Structure

```
web_admin/
├── index.html          # Main HTML structure
├── styles.css          # Styling and layout
├── firebase-config.js  # Firebase configuration
├── app.js              # Main application logic
└── README.md          # This file
```

## Admin Features

### Dashboard Overview Page ✅
- **Statistics Cards**:
  - Total users with +12% growth indicator
  - Total farms with +5% growth indicator
  - Active crops with +8% growth indicator
  - Active notifications counter
- **Reporting & Analytics Section**:
  - Farm and Crop filter dropdowns
  - Soil Moisture and Temperature chart visualization
- **System Announcements**:
  - Compose and publish announcements
  - Email notification option
- **Recent Activity Tables**:
  - Latest 3 registered users with avatars and status badges
  - Latest 4 farms with sensor status indicators
- **Refresh Data Button**: Manual data reload

### User Management Page ✅
- **View All Users**: Complete list with pagination
- **Search Functionality**: Search by name, email, or farm name
- **Status Filtering**: Filter by Active, Pending, or Inactive status
- **User Information Displayed**:
  - User avatar with initials
  - Full name and user ID
  - Email address
  - Farm name (if set)
  - Account status with color-coded badges
  - Join date
- **User Actions**:
  - 👁️ View detailed user information in modal
  - ✏️ Edit user (Coming soon)
  - 🗑️ Delete user with confirmation and cascade delete
- **User Details Modal**:
  - Full name, email, farm name
  - Phone number, role, status
  - User ID and creation timestamp

### Farm Management Page ✅
- **View All Farms**: Complete list of registered farms
- **Search Functionality**: Search by farm name or location
- **Real-time Sensor Status**:
  - Live data from Firebase RTDB
  - Online/Offline device counts
  - Color-coded status indicators (green for online, yellow for warnings)
  - Last update timestamp check (5-minute threshold)
- **Farm Information Displayed**:
  - Farm name and owner
  - Owner email address
  - Physical location/address
  - Sensor status with device counts
- **Farm Actions**:
  - 👁️ View farm details
  - 📍 View location on OpenStreetMap (if location is set)

### Notifications Page ✅
- **View All Notifications**: Last 50 system notifications
- **Notification Information**:
  - Type badge (Alert, Warning, Info) with color coding
  - Notification title
  - Full message content
  - Target user ID or "All users"
  - Timestamp
- **Sorted by Date**: Most recent first

### Analytics & Reporting Page 🔄
- Under development
- Planned features:
  - Interactive charts and graphs
  - Crop performance analytics
  - Weather correlation analysis
  - Export reports as PDF/CSV

### Settings Page 🔄
- Under development
- Planned features:
  - Admin account management
  - System configuration
  - Email notification settings
  - Database backup/restore

## Security Notes

⚠️ **Important Security Considerations:**

1. **Admin Authentication**: Only users with "admin" in their email or with `role: "admin"` in Firestore can access the dashboard
2. **Firebase Rules**: Make sure your Firestore security rules restrict write access
3. **HTTPS**: Always use HTTPS in production (Firebase Hosting provides this)
4. **Password**: Use a strong password for admin accounts

## Deployment

### Deploy to Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Hosting in web_admin directory
cd web_admin
firebase init hosting

# Deploy
firebase deploy --only hosting
```

Your admin panel will be available at: `https://iot-smartfarm-system.web.app`

## Browser Support

- Chrome (Recommended)
- Firefox
- Safari
- Edge

## Troubleshooting

### Login fails with "Access denied"
- Ensure your email contains "admin" OR
- Add `role: "admin"` field to your user document in Firestore

### Dashboard shows "0" for all stats
- Check Firebase console for data
- Ensure Firestore collections exist: `users`, `crops`, `devices`, `notifications`
- Check browser console for errors (F12)

### Firebase errors
- Verify `firebase-config.js` has correct credentials
- Check Firebase console → Settings → Your apps → Web app config

## Need Help?

- Check browser console (F12) for error messages
- Verify Firebase configuration
- Ensure admin user is created in Firebase Authentication
- Check Firestore security rules

## Technical Details

### Architecture
- **Frontend**: Pure HTML5, CSS (Tailwind CSS), Vanilla JavaScript
- **Database**:
  - Firebase Firestore (user data, crops, farm details)
  - Firebase Realtime Database (sensor data, device status)
- **Authentication**: Firebase Authentication with role-based access
- **Icons**: Material Symbols (Google Material Icons)
- **Hosting**: Can be deployed to Firebase Hosting, Netlify, or any static host

### Data Flow
1. **Dashboard Overview**:
   - Loads total counts from Firestore collections
   - Fetches recent users ordered by `createdAt`
   - Fetches farms from users with `farm_name` field
   - Displays mock sensor status (to be replaced with real RTDB data)

2. **User Management**:
   - Fetches all users from Firestore `users` collection
   - Filters and searches in real-time using JavaScript
   - Delete operation cascades to `crops` collection
   - Modal displays complete user profile

3. **Farm Management**:
   - Fetches users with `farm_name` field
   - Loads farm location from `users/{userId}/farm/location` subcollection
   - Queries `crops` collection to find assigned devices
   - Checks real-time device status from RTDB `sensors/{deviceId}` path
   - Determines online/offline based on 5-minute timestamp threshold

4. **Notifications**:
   - Fetches from Firestore `notifications` collection
   - Ordered by `createdAt` descending
   - Limited to last 50 notifications

### Key Functions

#### app.js Functions:
- `checkAdminRole(user)` - Validates admin access
- `loadDashboardData()` - Loads all dashboard statistics
- `loadAllUsers()` - Fetches and displays all users
- `renderUsersTable(users)` - Renders user table with actions
- `viewUserDetails(userId)` - Shows user details modal
- `deleteUser(userId, userName)` - Deletes user with cascade
- `loadAllFarms()` - Fetches farms with real-time sensor status
- `renderFarmsTable(farms)` - Renders farm table with sensor data
- `loadAllNotifications()` - Fetches and displays notifications

### Firebase Collections Structure

**users/**
```
{
  uid: string,
  name: string,
  email: string,
  farm_name: string,
  status: 'active' | 'pending' | 'inactive',
  role: 'farmer' | 'admin',
  createdAt: Timestamp,
  phoneNumber?: string
}
```

**users/{userId}/farm/location**
```
{
  latitude: number,
  longitude: number,
  address: string,
  updatedAt: Timestamp
}
```

**users/{userId}/farm/details**
```
{
  name: string,
  size: number,
  updatedAt: Timestamp
}
```

**crops/**
```
{
  farmer_id: string,
  device_id: string,
  crop_type: string,
  status: 'active' | 'harvested' | 'failed',
  planted_at: Timestamp
}
```

**notifications/**
```
{
  type: 'alert' | 'warning' | 'info',
  title: string,
  message: string,
  farmer_id?: string,
  createdAt: Timestamp
}
```

**RTDB: sensors/{deviceId}**
```
{
  temperature: number,
  humidity: number,
  soilMoisture: number,
  ph: number,
  waterLevel: number,
  timestamp: number
}
```

## Performance Considerations

- **Real-time Updates**: Farm sensor status queries RTDB for each device (may be slow with many farms)
- **Optimization Needed**: Consider caching device status or using batch queries
- **Pagination**: User and farm tables should implement pagination for large datasets
- **Search**: Client-side search is fast for small datasets, consider server-side for 1000+ records

## Future Enhancements

1. **Real-time Dashboard Updates**: Use Firestore onSnapshot listeners
2. **Advanced Analytics**: Add Chart.js or similar library for data visualization
3. **Export Functionality**: Generate PDF/CSV reports
4. **Bulk Operations**: Select multiple users/farms for batch actions
5. **Activity Logs**: Track admin actions for audit trail
6. **Email Notifications**: Send emails to users directly from admin panel
7. **Device Management**: Add dedicated page for ESP32 device configuration
8. **User Roles**: Implement granular permissions (super admin, moderator, viewer)

## License

This admin panel is part of the Smart Farm IoT project.
