// App State
let currentUser = null;
let allUsers = [];

// DOM Elements
const loginScreen = document.getElementById('login-screen');
const dashboardScreen = document.getElementById('dashboard-screen');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const loginBtn = document.getElementById('login-btn');
const loginText = document.getElementById('login-text');
const loginSpinner = document.getElementById('login-spinner');
const logoutBtn = document.getElementById('logout-btn');

// Check authentication state on load
auth.onAuthStateChanged((user) => {
    if (user) {
        checkAdminRole(user);
    } else {
        showLoginScreen();
    }
});

// Login Form Submit
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    const email = document.getElementById('admin-email').value;
    const password = document.getElementById('admin-password').value;

    loginBtn.disabled = true;
    loginText.classList.add('hidden');
    loginSpinner.classList.remove('hidden');
    loginError.classList.add('hidden');

    try {
        const userCredential = await auth.signInWithEmailAndPassword(email, password);
        await checkAdminRole(userCredential.user);
    } catch (error) {
        console.error('Login error:', error);
        showLoginError(getErrorMessage(error.code));
        loginBtn.disabled = false;
        loginText.classList.remove('hidden');
        loginSpinner.classList.add('hidden');
    }
});

// Check if user has admin role
async function checkAdminRole(user) {
    try {
        const userDoc = await db.collection('users')
            .where('uid', '==', user.uid)
            .limit(1)
            .get();

        if (!userDoc.empty) {
            const userData = userDoc.docs[0].data();
            if (userData.role === 'admin' || user.email.includes('admin')) {
                currentUser = user;
                showDashboard();
                loadDashboardData();
            } else {
                await auth.signOut();
                showLoginError('Access denied. Admin privileges required.');
            }
        } else {
            if (user.email.includes('admin')) {
                currentUser = user;
                showDashboard();
                loadDashboardData();
            } else {
                await auth.signOut();
                showLoginError('Access denied. Admin privileges required.');
            }
        }
    } catch (error) {
        console.error('Role check error:', error);
        await auth.signOut();
        showLoginError('Error checking admin privileges');
    }
}

// Logout
logoutBtn.addEventListener('click', async () => {
    try {
        await auth.signOut();
        showLoginScreen();
    } catch (error) {
        console.error('Logout error:', error);
    }
});

// Show/Hide Screens
function showLoginScreen() {
    loginScreen.classList.remove('hidden');
    dashboardScreen.classList.add('hidden');
    loginForm.reset();
}

function showDashboard() {
    loginScreen.classList.add('hidden');
    dashboardScreen.classList.remove('hidden');

    if (currentUser) {
        const adminName = currentUser.displayName || currentUser.email.split('@')[0];
        document.getElementById('admin-name-text').textContent = adminName;
    }
}

function showLoginError(message) {
    loginError.textContent = message;
    loginError.classList.remove('hidden');
}

function getErrorMessage(code) {
    switch (code) {
        case 'auth/invalid-email': return 'Invalid email address';
        case 'auth/user-not-found': return 'No account found with this email';
        case 'auth/wrong-password': return 'Incorrect password';
        case 'auth/too-many-requests': return 'Too many attempts. Please try again later';
        case 'auth/invalid-credential': return 'Invalid email or password';
        default: return 'Login failed. Please try again';
    }
}

// Navigation
const navItems = document.querySelectorAll('.nav-item');
navItems.forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const page = item.getAttribute('data-page');
        navigateToPage(page);
    });
});

function navigateToPage(pageName) {
    navItems.forEach(item => {
        const itemPage = item.getAttribute('data-page');
        if (itemPage === pageName) {
            item.classList.remove('text-[#9db9a6]', 'hover:bg-[#1c271f]');
            item.classList.add('bg-[#28392e]');
            item.querySelector('p').classList.add('text-white');
            item.querySelector('.material-symbols-outlined').classList.add('text-primary');
        } else {
            item.classList.add('text-[#9db9a6]', 'hover:bg-[#1c271f]');
            item.classList.remove('bg-[#28392e]');
            item.querySelector('p').classList.remove('text-white');
            item.querySelector('.material-symbols-outlined').classList.remove('text-primary');
        }
    });

    document.querySelectorAll('[id^="page-"]').forEach(page => {
        page.classList.add('hidden');
    });

    const selectedPage = document.getElementById(`page-${pageName}`);
    if (selectedPage) {
        selectedPage.classList.remove('hidden');
    }

    const titles = {
        'overview': 'Dashboard Overview',
        'users': 'User Management',
        'farms': 'Farm Management',
        'analytics': 'Reporting & Analytics',
        'notifications': 'Notifications',
        'settings': 'Settings'
    };
    document.getElementById('page-title').textContent = titles[pageName] || 'Dashboard';

    // Load page-specific data
    if (pageName === 'users') {
        loadAllUsers();
    } else if (pageName === 'farms') {
        loadAllFarms();
    } else if (pageName === 'notifications') {
        loadAllNotifications();
    } else if (pageName === 'analytics') {
        loadAnalyticsPage();
    } else if (pageName === 'settings') {
        loadSettingsPage();
    }
}

// Dashboard chart instance
let dashboardChart = null;
let dashboardSelectedFarm = null;
let dashboardSelectedCrop = null;

// Load Dashboard Data
async function loadDashboardData() {
    try {
        await Promise.all([
            loadTotalUsers(),
            loadTotalFarms(),
            loadTotalCrops(),
            loadRecentUsers(),
            loadRecentFarms(),
            loadDashboardChart(),
            loadDashboardAnnouncements()
        ]);
    } catch (error) {
        console.error('Error loading dashboard data:', error);
    }
}

// Load Total Users
async function loadTotalUsers() {
    try {
        const snapshot = await db.collection('users').get();
        document.getElementById('total-users').textContent = snapshot.size;
    } catch (error) {
        console.error('Error loading total users:', error);
        document.getElementById('total-users').textContent = '0';
    }
}

// Load Total Farms
async function loadTotalFarms() {
    try {
        const snapshot = await db.collection('users').get();
        const farms = new Set();
        snapshot.forEach(doc => {
            const data = doc.data();
            if (data.farm_name) farms.add(data.farm_name);
        });
        document.getElementById('total-farms').textContent = farms.size;
    } catch (error) {
        console.error('Error loading total farms:', error);
        document.getElementById('total-farms').textContent = '0';
    }
}

// Load Total Crops
async function loadTotalCrops() {
    try {
        const snapshot = await db.collection('crops')
            .where('status', '==', 'active')
            .get();
        document.getElementById('total-crops').textContent = snapshot.size;
    } catch (error) {
        console.error('Error loading total crops:', error);
        document.getElementById('total-crops').textContent = '0';
    }
}

// Load Recent Users
async function loadRecentUsers() {
    try {
        const snapshot = await db.collection('users').get();

        // Convert to array and sort by created_at in JavaScript
        const users = [];
        snapshot.forEach(doc => {
            users.push({ id: doc.id, ...doc.data() });
        });

        // Sort by created_at (newest first)
        users.sort((a, b) => {
            const timeA = a.created_at ? a.created_at.toMillis() : (a.createdAt ? a.createdAt.toMillis() : 0);
            const timeB = b.created_at ? b.created_at.toMillis() : (b.createdAt ? b.createdAt.toMillis() : 0);
            return timeB - timeA;
        });

        // Take only the 3 most recent users
        const recentUsers = users.slice(0, 3);

        const tbody = document.getElementById('recent-users-tbody');
        tbody.innerHTML = '';

        if (recentUsers.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="p-4 text-center text-[#9db9a6]">No users found</td></tr>';
            return;
        }

        recentUsers.forEach(user => {
            const statusClass = user.status === 'pending' ? 'bg-yellow-500/10 text-yellow-500' :
                               user.status === 'inactive' ? 'bg-red-500/10 text-red-500' :
                               'bg-green-500/10 text-green-500';
            const statusText = user.status === 'pending' ? 'Pending' :
                             user.status === 'inactive' ? 'Inactive' : 'Active';

            // Profile photo or avatar with initial
            const avatarHTML = user.photoURL
                ? `<img src="${user.photoURL}" alt="Profile" class="w-8 h-8 rounded-full object-cover">`
                : `<div class="w-8 h-8 rounded-full bg-[#28392e] flex items-center justify-center text-white font-semibold">
                    ${(user.name || user.displayName || 'U')[0].toUpperCase()}
                   </div>`;

            const row = `
                <tr class="hover:bg-[#223026] transition-colors">
                    <td class="p-4">
                        <div class="flex items-center gap-3">
                            ${avatarHTML}
                            <span class="text-white font-medium">${user.name || user.displayName || 'N/A'}</span>
                        </div>
                    </td>
                    <td class="p-4 text-[#9db9a6]">${user.email || 'N/A'}</td>
                    <td class="p-4">
                        <span class="px-2 py-1 rounded text-xs font-medium ${statusClass}">${statusText}</span>
                    </td>
                    <td class="p-4 text-right">
                        <button class="text-[#9db9a6] hover:text-white transition-colors">
                            <span class="material-symbols-outlined text-[20px]">more_vert</span>
                        </button>
                    </td>
                </tr>
            `;
            tbody.innerHTML += row;
        });
    } catch (error) {
        console.error('Error loading recent users:', error);
        document.getElementById('recent-users-tbody').innerHTML =
            '<tr><td colspan="4" class="p-4 text-center text-[#9db9a6]">Error loading users</td></tr>';
    }
}

// Load Recent Farms
async function loadRecentFarms() {
    try {
        const snapshot = await db.collection('users')
            .limit(4)
            .get();

        const tbody = document.getElementById('recent-farms-tbody');
        tbody.innerHTML = '';

        if (snapshot.empty) {
            tbody.innerHTML = '<tr><td colspan="4" class="p-4 text-center text-[#9db9a6]">No farms found</td></tr>';
            return;
        }

        snapshot.forEach(doc => {
            const user = doc.data();
            if (user.farm_name) {
                // Mock sensor status
                const sensorStatus = Math.random() > 0.5;
                const statusColor = sensorStatus ? 'bg-green-500' : 'bg-yellow-500 animate-pulse';
                const statusText = sensorStatus ? 'Online (12)' : 'Warning (2)';
                const statusTextColor = sensorStatus ? 'text-white' : 'text-white';

                const row = `
                    <tr class="hover:bg-[#223026] transition-colors">
                        <td class="p-4">
                            <div class="flex flex-col">
                                <span class="text-white font-medium">${user.farm_name}</span>
                                <span class="text-xs text-[#9db9a6]">Owner: ${user.name || 'Unknown'}</span>
                            </div>
                        </td>
                        <td class="p-4 text-[#9db9a6]">-</td>
                        <td class="p-4">
                            <div class="flex items-center gap-1">
                                <span class="w-2 h-2 rounded-full ${statusColor}"></span>
                                <span class="text-xs ${statusTextColor}">${statusText}</span>
                            </div>
                        </td>
                        <td class="p-4 text-right">
                            <button class="text-[#9db9a6] hover:text-white transition-colors">
                                <span class="material-symbols-outlined text-[20px]">edit</span>
                            </button>
                        </td>
                    </tr>
                `;
                tbody.innerHTML += row;
            }
        });
    } catch (error) {
        console.error('Error loading recent farms:', error);
        document.getElementById('recent-farms-tbody').innerHTML =
            '<tr><td colspan="4" class="p-4 text-center text-[#9db9a6]">Error loading farms</td></tr>';
    }
}

// Load Dashboard Chart
async function loadDashboardChart() {
    try {
        // Load farms for filter
        const farmsSnapshot = await db.collection('users').get();
        const farmSelect = document.getElementById('dashboard-farm-filter');

        if (farmSelect) {
            farmSelect.innerHTML = '<option value="">All Farms</option>';
            farmsSnapshot.forEach(doc => {
                const userData = doc.data();
                if (userData.farm_name) {
                    const option = document.createElement('option');
                    option.value = doc.id;
                    option.textContent = userData.farm_name;
                    farmSelect.appendChild(option);
                }
            });

            farmSelect.addEventListener('change', async (e) => {
                dashboardSelectedFarm = e.target.value || null;
                await loadDashboardCrops(dashboardSelectedFarm);
                await updateDashboardChart();
            });
        }

        // Load crops for filter
        const cropSelect = document.getElementById('dashboard-crop-filter');
        if (cropSelect) {
            cropSelect.addEventListener('change', async () => {
                dashboardSelectedCrop = cropSelect.value || null;
                await updateDashboardChart();
            });
        }

        // Initialize chart
        await updateDashboardChart();

    } catch (error) {
        console.error('Error loading dashboard chart:', error);
    }
}

// Load crops for dashboard filter
async function loadDashboardCrops(farmId) {
    try {
        const cropSelect = document.getElementById('dashboard-crop-filter');
        if (!cropSelect) return;

        cropSelect.innerHTML = '<option value="">All Crops</option>';

        if (!farmId) return;

        const userDoc = await db.collection('users').doc(farmId).get();
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const authUid = userData.uid || farmId;

        let cropsSnapshot = await db.collection('crops')
            .where('farmer_id', '==', authUid)
            .get();

        if (cropsSnapshot.empty) {
            cropsSnapshot = await db.collection('crops')
                .where('farmer_id', '==', farmId)
                .get();
        }

        cropsSnapshot.forEach(doc => {
            const cropData = doc.data();
            const option = document.createElement('option');
            option.value = doc.id;
            option.textContent = `${cropData.crop_type || 'Unknown'} (${cropData.device_id || 'N/A'})`;
            cropSelect.appendChild(option);
        });

    } catch (error) {
        console.error('Error loading dashboard crops:', error);
    }
}

// Update dashboard chart with real data
async function updateDashboardChart() {
    try {
        const canvas = document.getElementById('dashboard-chart');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');

        // Destroy existing chart
        if (dashboardChart) {
            dashboardChart.destroy();
        }

        // Get device IDs based on filters
        let deviceIds = [];

        if (dashboardSelectedCrop) {
            const cropDoc = await db.collection('crops').doc(dashboardSelectedCrop).get();
            if (cropDoc.exists && cropDoc.data().device_id) {
                deviceIds.push(cropDoc.data().device_id);
            }
        } else if (dashboardSelectedFarm) {
            const userDoc = await db.collection('users').doc(dashboardSelectedFarm).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                const authUid = userData.uid || dashboardSelectedFarm;

                let cropsSnapshot = await db.collection('crops')
                    .where('farmer_id', '==', authUid)
                    .get();

                if (cropsSnapshot.empty) {
                    cropsSnapshot = await db.collection('crops')
                        .where('farmer_id', '==', dashboardSelectedFarm)
                        .get();
                }

                cropsSnapshot.forEach(doc => {
                    const cropData = doc.data();
                    if (cropData.device_id) deviceIds.push(cropData.device_id);
                });
            }
        } else {
            // Get all devices
            const cropsSnapshot = await db.collection('crops').get();
            cropsSnapshot.forEach(doc => {
                const cropData = doc.data();
                if (cropData.device_id) deviceIds.push(cropData.device_id);
            });
        }

        deviceIds = [...new Set(deviceIds)];

        // Load sensor data for last 7 days
        const now = Date.now();
        const sevenDaysAgo = now - (7 * 24 * 60 * 60 * 1000);
        const startTimestamp = Math.floor(sevenDaysAgo / 1000);

        const chartData = {
            soilMoisture: [],
            temperature: []
        };

        for (const deviceId of deviceIds.slice(0, 5)) { // Limit to 5 devices for performance
            try {
                const soilSnapshot = await rtdb.ref(`sensors/${deviceId}/history/soil`)
                    .orderByKey()
                    .startAt(startTimestamp.toString())
                    .limitToLast(50)
                    .once('value');

                const tempSnapshot = await rtdb.ref(`sensors/${deviceId}/history/temp`)
                    .orderByKey()
                    .startAt(startTimestamp.toString())
                    .limitToLast(50)
                    .once('value');

                if (soilSnapshot.exists()) {
                    const soilData = soilSnapshot.val();
                    Object.entries(soilData).forEach(([timestamp, value]) => {
                        chartData.soilMoisture.push({
                            x: parseInt(timestamp) * 1000,
                            y: value
                        });
                    });
                }

                if (tempSnapshot.exists()) {
                    const tempData = tempSnapshot.val();
                    Object.entries(tempData).forEach(([timestamp, value]) => {
                        chartData.temperature.push({
                            x: parseInt(timestamp) * 1000,
                            y: value
                        });
                    });
                }
            } catch (error) {
                console.error(`Error loading device ${deviceId}:`, error);
            }
        }

        // Sort by timestamp
        chartData.soilMoisture.sort((a, b) => a.x - b.x);
        chartData.temperature.sort((a, b) => a.x - b.x);

        // Create chart
        dashboardChart = new Chart(ctx, {
            type: 'line',
            data: {
                datasets: [
                    {
                        label: 'Soil Moisture (%)',
                        data: chartData.soilMoisture,
                        borderColor: '#4ade80',
                        backgroundColor: 'rgba(74, 222, 128, 0.1)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true,
                        pointRadius: 0,
                        pointHoverRadius: 4
                    },
                    {
                        label: 'Temperature (°C)',
                        data: chartData.temperature,
                        borderColor: '#fb923c',
                        backgroundColor: 'rgba(251, 146, 60, 0.1)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true,
                        pointRadius: 0,
                        pointHoverRadius: 4
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                    intersect: false,
                    mode: 'index'
                },
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: '#1c271f',
                        borderColor: '#28392e',
                        borderWidth: 1,
                        titleColor: '#9db9a6',
                        bodyColor: '#ffffff',
                        padding: 12,
                        displayColors: true,
                        callbacks: {
                            title: function(context) {
                                const date = new Date(context[0].parsed.x);
                                return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'day',
                            displayFormats: {
                                day: 'MMM d'
                            }
                        },
                        grid: {
                            color: '#28392e',
                            drawBorder: false
                        },
                        ticks: {
                            color: '#9db9a6',
                            font: {
                                size: 11
                            }
                        }
                    },
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: '#28392e',
                            drawBorder: false
                        },
                        ticks: {
                            color: '#9db9a6',
                            font: {
                                size: 11
                            }
                        }
                    }
                }
            }
        });

    } catch (error) {
        console.error('Error updating dashboard chart:', error);
    }
}

// Load Dashboard Announcements
async function loadDashboardAnnouncements() {
    try {
        const container = document.getElementById('dashboard-announcements');
        if (!container) return;

        // Try to get notifications ordered by createdAt
        // Note: This may require a composite index in Firestore
        let snapshot;
        try {
            snapshot = await db.collection('notifications')
                .orderBy('createdAt', 'desc')
                .limit(10)
                .get();
        } catch (indexError) {
            console.log('Composite index not available, using simple query:', indexError);
            // Fallback to simple query without orderBy
            snapshot = await db.collection('notifications')
                .limit(10)
                .get();
        }

        if (snapshot.empty) {
            container.innerHTML = '<div class="p-6 text-center text-[#9db9a6] text-sm">No announcements yet</div>';
            return;
        }

        // Filter for admin notifications and sort manually
        let notifications = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            if (data.sentBy === 'admin') {
                notifications.push({ id: doc.id, ...data });
            }
        });

        // Sort by createdAt manually
        notifications.sort((a, b) => {
            const aTime = a.createdAt ? a.createdAt.toMillis() : 0;
            const bTime = b.createdAt ? b.createdAt.toMillis() : 0;
            return bTime - aTime;
        });

        // Take only first 5
        notifications = notifications.slice(0, 5);

        if (notifications.length === 0) {
            container.innerHTML = '<div class="p-6 text-center text-[#9db9a6] text-sm">No announcements yet</div>';
            return;
        }

        let html = '';
        notifications.forEach(notif => {
            const typeColors = {
                'alert': 'bg-red-500/10 text-red-500 border-red-500/20',
                'warning': 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
                'info': 'bg-blue-500/10 text-blue-500 border-blue-500/20',
                'success': 'bg-green-500/10 text-green-500 border-green-500/20'
            };
            const colorClass = typeColors[notif.type] || typeColors['info'];

            const createdDate = notif.createdAt ?
                new Date(notif.createdAt.toDate()).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                }) : 'N/A';

            // Truncate message to 2 lines max
            const maxLength = 80;
            const message = notif.message || '';
            const truncatedMessage = message.length > maxLength ? message.substring(0, maxLength) + '...' : message;

            html += `
                <div class="p-4 border-b border-[#28392e] last:border-b-0 hover:bg-[#223026] transition-colors">
                    <div class="flex items-start gap-3">
                        <span class="px-2 py-1 rounded text-xs font-medium ${colorClass} border capitalize">${notif.type || 'info'}</span>
                        <div class="flex-1 min-w-0">
                            <h4 class="text-white text-sm font-medium mb-1">${notif.title || 'Announcement'}</h4>
                            <p class="text-[#9db9a6] text-xs mb-2" style="display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;">${truncatedMessage}</p>
                            <p class="text-[#9db9a6] text-xs">${createdDate}</p>
                        </div>
                    </div>
                </div>
            `;
        });

        container.innerHTML = html;

    } catch (error) {
        console.error('Error loading dashboard announcements:', error);
        const container = document.getElementById('dashboard-announcements');
        if (container) {
            container.innerHTML = '<div class="p-6 text-center text-[#9db9a6] text-sm">No announcements sent yet. <br><small class="text-xs">Go to Notifications to send one.</small></div>';
        }
    }
}

// Refresh Data Button
document.getElementById('refresh-btn')?.addEventListener('click', () => {
    loadDashboardData();
});

// ========================================
// USER MANAGEMENT PAGE
// ========================================

// Load All Users (for Users page)
async function loadAllUsers() {
    try {
        const snapshot = await db.collection('users').get();

        allUsers = [];
        snapshot.forEach(doc => {
            allUsers.push({ id: doc.id, ...doc.data() });
        });

        // Sort by created_at in JavaScript (newest first)
        allUsers.sort((a, b) => {
            const timeA = a.created_at ? a.created_at.toMillis() : (a.createdAt ? a.createdAt.toMillis() : 0);
            const timeB = b.created_at ? b.created_at.toMillis() : (b.createdAt ? b.createdAt.toMillis() : 0);
            return timeB - timeA; // Descending order
        });

        renderUsersTable(allUsers);
    } catch (error) {
        console.error('Error loading all users:', error);
        document.getElementById('all-users-tbody').innerHTML =
            '<tr><td colspan="6" class="p-4 text-center text-[#9db9a6]">Error loading users</td></tr>';
    }
}

// Render Users Table
function renderUsersTable(users) {
    const tbody = document.getElementById('all-users-tbody');
    tbody.innerHTML = '';

    if (users.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="p-4 text-center text-[#9db9a6]">No users found</td></tr>';
        return;
    }

    users.forEach(user => {
        const statusClass = user.status === 'pending' ? 'bg-yellow-500/10 text-yellow-500' :
                           user.status === 'inactive' ? 'bg-red-500/10 text-red-500' :
                           'bg-green-500/10 text-green-500';
        const statusText = user.status === 'pending' ? 'Pending' :
                         user.status === 'inactive' ? 'Inactive' : 'Active';

        const createdDate = user.created_at ?
            new Date(user.created_at.toDate()).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            }) : (user.createdAt ?
                new Date(user.createdAt.toDate()).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric'
                }) : 'N/A');

        // Profile photo or avatar with initial
        const avatarHTML = user.photoURL
            ? `<img src="${user.photoURL}" alt="Profile" class="w-10 h-10 rounded-full object-cover">`
            : `<div class="w-10 h-10 rounded-full bg-[#28392e] flex items-center justify-center text-white font-semibold">
                ${(user.name || user.displayName || 'U')[0].toUpperCase()}
               </div>`;

        const row = `
            <tr class="hover:bg-[#223026] transition-colors">
                <td class="p-4">
                    <div class="flex items-center gap-3">
                        ${avatarHTML}
                        <div class="flex flex-col">
                            <span class="text-white font-medium">${user.name || user.displayName || 'N/A'}</span>
                            <span class="text-xs text-[#9db9a6]">${user.id}</span>
                        </div>
                    </div>
                </td>
                <td class="p-4 text-[#9db9a6]">${user.email || 'N/A'}</td>
                <td class="p-4 text-[#9db9a6]">${user.farm_name || 'Not set'}</td>
                <td class="p-4">
                    <span class="px-2 py-1 rounded text-xs font-medium ${statusClass}">${statusText}</span>
                </td>
                <td class="p-4 text-[#9db9a6]">${createdDate}</td>
                <td class="p-4 text-right">
                    <div class="flex items-center justify-end gap-2">
                        <button onclick="viewUserDetails('${user.id}')" class="text-[#9db9a6] hover:text-primary transition-colors" title="View Details">
                            <span class="material-symbols-outlined text-[20px]">visibility</span>
                        </button>
                        <button onclick="editUser('${user.id}')" class="text-[#9db9a6] hover:text-primary transition-colors" title="Edit User">
                            <span class="material-symbols-outlined text-[20px]">edit</span>
                        </button>
                        <button onclick="deleteUser('${user.id}', '${user.name || user.email}')" class="text-[#9db9a6] hover:text-red-500 transition-colors" title="Delete User">
                            <span class="material-symbols-outlined text-[20px]">delete</span>
                        </button>
                    </div>
                </td>
            </tr>
        `;
        tbody.innerHTML += row;
    });
}

// Search Users
document.getElementById('search-users')?.addEventListener('input', (e) => {
    const searchTerm = e.target.value.toLowerCase();
    const filteredUsers = allUsers.filter(user => {
        const name = (user.name || user.displayName || '').toLowerCase();
        const email = (user.email || '').toLowerCase();
        const farmName = (user.farm_name || '').toLowerCase();
        return name.includes(searchTerm) || email.includes(searchTerm) || farmName.includes(searchTerm);
    });
    renderUsersTable(filteredUsers);
});

// Filter Users by Status
document.getElementById('filter-user-status')?.addEventListener('change', (e) => {
    const status = e.target.value;
    const filteredUsers = status === 'all'
        ? allUsers
        : allUsers.filter(user => user.status === status);
    renderUsersTable(filteredUsers);
});

// View User Details
async function viewUserDetails(userId) {
    const user = allUsers.find(u => u.id === userId);
    if (!user) return;

    const modal = document.getElementById('user-details-modal');

    // Basic user info
    document.getElementById('modal-user-name').textContent = user.name || user.displayName || 'N/A';
    document.getElementById('modal-user-email').textContent = user.email || 'N/A';
    document.getElementById('modal-user-farm').textContent = user.farm_name || 'Not set';
    document.getElementById('modal-user-phone').textContent = user.phone || user.phoneNumber || 'Not set';
    document.getElementById('modal-user-role').textContent = user.role || 'farmer';
    document.getElementById('modal-user-status').textContent = user.status || 'active';
    document.getElementById('modal-user-id').textContent = userId;
    document.getElementById('modal-user-uid').textContent = user.uid || 'N/A';

    // Password - Firebase Auth doesn't expose passwords, so check if stored in Firestore
    const passwordElement = document.getElementById('modal-user-password');
    const togglePasswordBtn = document.getElementById('toggle-password-visibility');

    // Store password state
    let passwordVisible = false;
    let actualPassword = user.password || null;

    // Display password (masked by default)
    if (actualPassword) {
        passwordElement.textContent = '••••••••';
        passwordElement.dataset.password = actualPassword;

        // Remove any existing event listeners by cloning the button
        if (togglePasswordBtn) {
            const newToggleBtn = togglePasswordBtn.cloneNode(true);
            togglePasswordBtn.parentNode.replaceChild(newToggleBtn, togglePasswordBtn);

            // Add click event to toggle password visibility
            newToggleBtn.addEventListener('click', () => {
                passwordVisible = !passwordVisible;
                const pwdElement = document.getElementById('modal-user-password');
                const icon = newToggleBtn.querySelector('.material-symbols-outlined');

                if (passwordVisible) {
                    pwdElement.textContent = pwdElement.dataset.password;
                    icon.textContent = 'visibility_off';
                } else {
                    pwdElement.textContent = '••••••••';
                    icon.textContent = 'visibility';
                }
            });
        }
    } else {
        passwordElement.textContent = 'Not available';
        passwordElement.dataset.password = '';
        if (togglePasswordBtn) {
            togglePasswordBtn.style.display = 'none';
        }
    }

    // Photo URL
    if (user.photoURL) {
        document.getElementById('modal-user-photo').innerHTML = `<img src="${user.photoURL}" alt="Profile" class="w-20 h-20 rounded-full object-cover">`;
    } else {
        document.getElementById('modal-user-photo').innerHTML = `<div class="w-20 h-20 rounded-full bg-[#28392e] flex items-center justify-center text-white font-bold text-2xl">${(user.name || 'U')[0].toUpperCase()}</div>`;
    }

    // Timestamps - check both snake_case and camelCase field names
    const createdDate = user.created_at ?
        new Date(user.created_at.toDate()).toLocaleString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }) : (user.createdAt ?
            new Date(user.createdAt.toDate()).toLocaleString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }) : 'N/A');
    document.getElementById('modal-user-created').textContent = createdDate;

    const updatedDate = user.updated_at ?
        new Date(user.updated_at.toDate()).toLocaleString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }) : (user.updatedAt ?
            new Date(user.updatedAt.toDate()).toLocaleString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }) : 'N/A');
    document.getElementById('modal-user-updated').textContent = updatedDate;

    // Load farm details from subcollection
    try {
        const farmDetailsDoc = await db.collection('users')
            .doc(userId)
            .collection('farm')
            .doc('details')
            .get();

        if (farmDetailsDoc.exists) {
            const farmData = farmDetailsDoc.data();
            document.getElementById('modal-farm-size').textContent = farmData.size ? `${farmData.size} hectares` : 'Not set';
        } else {
            document.getElementById('modal-farm-size').textContent = 'Not set';
        }

        // Load farm location
        const farmLocationDoc = await db.collection('users')
            .doc(userId)
            .collection('farm')
            .doc('location')
            .get();

        if (farmLocationDoc.exists) {
            const locationData = farmLocationDoc.data();
            document.getElementById('modal-farm-location').textContent = locationData.address || 'Not set';
            document.getElementById('modal-farm-coordinates').textContent =
                locationData.latitude && locationData.longitude
                    ? `${locationData.latitude.toFixed(6)}, ${locationData.longitude.toFixed(6)}`
                    : 'Not set';
        } else {
            document.getElementById('modal-farm-location').textContent = 'Not set';
            document.getElementById('modal-farm-coordinates').textContent = 'Not set';
        }
    } catch (error) {
        console.error('Error loading farm details:', error);
        document.getElementById('modal-farm-size').textContent = 'Error loading';
        document.getElementById('modal-farm-location').textContent = 'Error loading';
        document.getElementById('modal-farm-coordinates').textContent = 'Error loading';
    }

    // Load user's crops - query by Firebase Auth UID, not custom user ID
    try {
        // Try querying by Firebase Auth UID first (user.uid), then fallback to custom userId
        let cropsSnapshot = await db.collection('crops')
            .where('farmer_id', '==', user.uid || userId)
            .get();

        // If no results and user.uid exists, also try with custom userId
        if (cropsSnapshot.empty && user.uid && user.uid !== userId) {
            cropsSnapshot = await db.collection('crops')
                .where('farmer_id', '==', userId)
                .get();
        }

        const cropsContainer = document.getElementById('modal-user-crops');
        if (cropsSnapshot.empty) {
            cropsContainer.innerHTML = '<p class="text-[#9db9a6] text-sm">No crops planted yet</p>';
        } else {
            let cropsHTML = '<div class="space-y-2">';
            cropsSnapshot.forEach(doc => {
                const crop = doc.data();
                const statusClass = crop.status === 'active' ? 'bg-green-500/10 text-green-500' :
                                  crop.status === 'harvested' ? 'bg-blue-500/10 text-blue-500' :
                                  'bg-red-500/10 text-red-500';

                cropsHTML += `
                    <div class="flex items-center justify-between p-2 bg-[#28392e] rounded">
                        <div>
                            <p class="text-white font-medium">${crop.crop_type || 'Unknown'}</p>
                            <p class="text-xs text-[#9db9a6]">Device: ${crop.device_id || 'N/A'}</p>
                        </div>
                        <span class="px-2 py-1 rounded text-xs font-medium ${statusClass}">${crop.status || 'active'}</span>
                    </div>
                `;
            });
            cropsHTML += '</div>';
            cropsContainer.innerHTML = cropsHTML;
        }
    } catch (error) {
        console.error('Error loading crops:', error);
        document.getElementById('modal-user-crops').innerHTML = '<p class="text-red-500 text-sm">Error loading crops</p>';
    }

    modal.classList.remove('hidden');
}

// Close User Details Modal
document.getElementById('close-user-modal')?.addEventListener('click', () => {
    document.getElementById('user-details-modal').classList.add('hidden');
});

document.getElementById('close-user-modal-btn')?.addEventListener('click', () => {
    document.getElementById('user-details-modal').classList.add('hidden');
});

// Edit User
function editUser(userId) {
    // For now, just show an alert. You can implement a full edit form later
    alert(`Edit user functionality for ${userId} - Coming soon!`);
}

// Delete User
async function deleteUser(userId, userName) {
    if (!confirm(`Are you sure you want to delete user "${userName}"?\n\nThis action cannot be undone and will:\n- Delete the user account\n- Delete all farm data\n- Delete all crops\n- Unassign all devices (set back to unassigned)`)) {
        return;
    }

    try {
        // Get user's Firebase Auth UID first
        const userDoc = await db.collection('users').doc(userId).get();
        const userData = userDoc.data();
        const authUid = userData?.uid || userId;

        // Step 1: Find and delete user's crops (try both custom userId and Firebase Auth UID)
        let cropsSnapshot = await db.collection('crops')
            .where('farmer_id', '==', authUid)
            .get();

        // If no crops found with Auth UID, try with custom userId
        if (cropsSnapshot.empty && authUid !== userId) {
            cropsSnapshot = await db.collection('crops')
                .where('farmer_id', '==', userId)
                .get();
        }

        const deletePromises = [];
        const deviceIds = new Set(); // Track devices to unassign

        // Collect device IDs and prepare crop deletion
        cropsSnapshot.forEach(doc => {
            const cropData = doc.data();
            if (cropData.device_id) {
                deviceIds.add(cropData.device_id);
            }
            deletePromises.push(doc.ref.delete());
        });

        // Step 2: Unassign all devices (set status back to 'unassigned')
        for (const deviceId of deviceIds) {
            deletePromises.push(
                db.collection('devices').doc(deviceId).update({
                    status: 'unassigned',
                    assigned_to: null,
                    assigned_at: null
                })
            );
        }

        // Step 3: Delete user's farm subcollections (location, details)
        try {
            const farmDetailsDoc = db.collection('users').doc(userId).collection('farm').doc('details');
            const farmLocationDoc = db.collection('users').doc(userId).collection('farm').doc('location');
            deletePromises.push(farmDetailsDoc.delete());
            deletePromises.push(farmLocationDoc.delete());
        } catch (e) {
            console.log('Farm subcollections may not exist, continuing...');
        }

        // Step 4: Delete user document
        deletePromises.push(db.collection('users').doc(userId).delete());

        // Execute all deletions and updates
        await Promise.all(deletePromises);

        alert(`User "${userName}" deleted successfully!\n\n- ${cropsSnapshot.size} crops deleted\n- ${deviceIds.size} devices unassigned`);
        loadAllUsers(); // Reload the table
    } catch (error) {
        console.error('Error deleting user:', error);
        alert('Failed to delete user. Please try again.');
    }
}

// ========================================
// FARM MANAGEMENT PAGE
// ========================================

// Load All Farms (for Farms page)
async function loadAllFarms() {
    try {
        const snapshot = await db.collection('users').get();
        const farms = [];

        for (const doc of snapshot.docs) {
            const userData = doc.data();
            if (userData.farm_name) {
                // Get farm location
                const locationDoc = await db.collection('users')
                    .doc(doc.id)
                    .collection('farm')
                    .doc('location')
                    .get();

                const location = locationDoc.exists ? locationDoc.data() : null;

                // Get crops to find device IDs
                // Try with both Auth UID and document ID
                const authUid = userData.uid || doc.id;
                let cropsSnapshot = await db.collection('crops')
                    .where('farmer_id', '==', authUid)
                    .get();

                // If no results with Auth UID, try with document ID
                if (cropsSnapshot.empty && authUid !== doc.id) {
                    cropsSnapshot = await db.collection('crops')
                        .where('farmer_id', '==', doc.id)
                        .get();
                }

                const deviceIds = new Set();
                cropsSnapshot.forEach(cropDoc => {
                    const cropData = cropDoc.data();
                    if (cropData.device_id) {
                        deviceIds.add(cropData.device_id);
                    }
                });

                // Get sensor status from RTDB for each device
                let onlineCount = 0;
                let warningCount = 0;

                for (const deviceId of deviceIds) {
                    try {
                        const deviceSnapshot = await rtdb.ref(`sensors/${deviceId}`).once('value');
                        const deviceData = deviceSnapshot.val();

                        if (deviceData) {
                            // Check if device is online (updated within last 5 minutes)
                            // Check live/lastSeen, live/timestamp, or root timestamp
                            const lastUpdate = (deviceData.live?.lastSeen) ||
                                             (deviceData.live?.timestamp) ||
                                             (deviceData.timestamp) || 0;
                            const now = Date.now();
                            const isOnline = (now - lastUpdate) < 300000; // 5 minutes

                            if (isOnline) {
                                onlineCount++;
                            } else {
                                warningCount++;
                            }
                        } else {
                            warningCount++;
                        }
                    } catch (error) {
                        console.error(`Error checking device ${deviceId}:`, error);
                        warningCount++;
                    }
                }

                const totalDevices = deviceIds.size;
                const sensorStatus = warningCount > 0 ? 'warning' : 'online';

                farms.push({
                    id: doc.id,
                    farmName: userData.farm_name,
                    ownerName: userData.name || userData.displayName || 'Unknown',
                    ownerEmail: userData.email || 'N/A',
                    location: location?.address || 'Not set',
                    latitude: location?.latitude,
                    longitude: location?.longitude,
                    sensorStatus: sensorStatus,
                    sensorCount: totalDevices,
                    onlineCount: onlineCount,
                    warningCount: warningCount
                });
            }
        }

        renderFarmsTable(farms);
    } catch (error) {
        console.error('Error loading all farms:', error);
        document.getElementById('all-farms-tbody').innerHTML =
            '<tr><td colspan="5" class="p-4 text-center text-[#9db9a6]">Error loading farms</td></tr>';
    }
}

// Render Farms Table
function renderFarmsTable(farms) {
    const tbody = document.getElementById('all-farms-tbody');
    tbody.innerHTML = '';

    if (farms.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="p-4 text-center text-[#9db9a6]">No farms found</td></tr>';
        return;
    }

    farms.forEach(farm => {
        let statusColor, statusText;

        if (farm.sensorCount === 0) {
            statusColor = 'bg-gray-500';
            statusText = 'No devices';
        } else if (farm.sensorStatus === 'warning') {
            statusColor = 'bg-yellow-500 animate-pulse';
            statusText = `${farm.onlineCount} online, ${farm.warningCount} offline`;
        } else {
            statusColor = 'bg-green-500';
            statusText = `All online (${farm.onlineCount})`;
        }

        const row = `
            <tr class="hover:bg-[#223026] transition-colors">
                <td class="p-4">
                    <div class="flex flex-col">
                        <span class="text-white font-medium">${farm.farmName}</span>
                        <span class="text-xs text-[#9db9a6]">Owner: ${farm.ownerName}</span>
                    </div>
                </td>
                <td class="p-4 text-[#9db9a6]">${farm.ownerEmail}</td>
                <td class="p-4 text-[#9db9a6]">${farm.location}</td>
                <td class="p-4">
                    <div class="flex items-center gap-1">
                        <span class="w-2 h-2 rounded-full ${statusColor}"></span>
                        <span class="text-xs text-white">${statusText}</span>
                    </div>
                </td>
                <td class="p-4 text-right">
                    <div class="flex items-center justify-end gap-2">
                        <button onclick="viewFarmDetails('${farm.id}')" class="text-[#9db9a6] hover:text-primary transition-colors" title="View Details">
                            <span class="material-symbols-outlined text-[20px]">visibility</span>
                        </button>
                        ${farm.latitude ? `<button onclick="viewFarmLocation(${farm.latitude}, ${farm.longitude})" class="text-[#9db9a6] hover:text-primary transition-colors" title="View on Map">
                            <span class="material-symbols-outlined text-[20px]">location_on</span>
                        </button>` : ''}
                    </div>
                </td>
            </tr>
        `;
        tbody.innerHTML += row;
    });
}

// Search Farms
document.getElementById('search-farms')?.addEventListener('input', () => {
    // Will be implemented when farms data is stored globally
    loadAllFarms();
});

// View Farm Details
async function viewFarmDetails(farmId) {
    try {
        const modal = document.getElementById('farm-details-modal');

        // Load user data
        const userDoc = await db.collection('users').doc(farmId).get();
        if (!userDoc.exists) {
            alert('Farm not found');
            return;
        }

        const userData = userDoc.data();

        // Basic farm info
        document.getElementById('modal-farm-name').textContent = userData.farm_name || 'N/A';
        document.getElementById('modal-farm-owner').textContent = userData.name || userData.displayName || 'Unknown';
        document.getElementById('modal-farm-email').textContent = userData.email || 'N/A';

        // Load farm size from subcollection
        const farmDetailsDoc = await db.collection('users')
            .doc(farmId)
            .collection('farm')
            .doc('details')
            .get();

        if (farmDetailsDoc.exists) {
            const farmData = farmDetailsDoc.data();
            document.getElementById('modal-farm-size-detail').textContent = farmData.size ? `${farmData.size} hectares` : 'Not set';
        } else {
            document.getElementById('modal-farm-size-detail').textContent = 'Not set';
        }

        // Load farm location
        const farmLocationDoc = await db.collection('users')
            .doc(farmId)
            .collection('farm')
            .doc('location')
            .get();

        if (farmLocationDoc.exists) {
            const locationData = farmLocationDoc.data();
            document.getElementById('modal-farm-address').textContent = locationData.address || 'Not set';
            document.getElementById('modal-farm-gps').textContent =
                locationData.latitude && locationData.longitude
                    ? `${locationData.latitude.toFixed(6)}, ${locationData.longitude.toFixed(6)}`
                    : 'Not set';
        } else {
            document.getElementById('modal-farm-address').textContent = 'Not set';
            document.getElementById('modal-farm-gps').textContent = 'Not set';
        }

        // Load crops and devices
        const cropsSnapshot = await db.collection('crops')
            .where('farmer_id', '==', userData.uid || farmId)
            .get();

        // Also try with custom userId if no results
        let crops = [];
        if (cropsSnapshot.empty && userData.uid && userData.uid !== farmId) {
            const altCropsSnapshot = await db.collection('crops')
                .where('farmer_id', '==', farmId)
                .get();
            altCropsSnapshot.forEach(doc => crops.push({ id: doc.id, ...doc.data() }));
        } else {
            cropsSnapshot.forEach(doc => crops.push({ id: doc.id, ...doc.data() }));
        }

        // Get unique device IDs
        const deviceIds = [...new Set(crops.map(crop => crop.device_id).filter(id => id))];

        // Load device status from RTDB
        const devicesData = [];
        let onlineCount = 0;
        let offlineCount = 0;

        for (const deviceId of deviceIds) {
            try {
                const deviceSnapshot = await rtdb.ref(`sensors/${deviceId}`).once('value');
                const sensorData = deviceSnapshot.val();

                if (sensorData) {
                    // Check live/lastSeen, live/timestamp, or root timestamp
                    const lastUpdate = (sensorData.live?.lastSeen) ||
                                     (sensorData.live?.timestamp) ||
                                     (sensorData.timestamp) || 0;
                    const now = Date.now();
                    const isOnline = (now - lastUpdate) < 300000; // 5 minutes
                    const timeDiff = now - lastUpdate;
                    const lastSeenMinutes = Math.floor(timeDiff / 60000);

                    if (isOnline) {
                        onlineCount++;
                    } else {
                        offlineCount++;
                    }

                    // Get live sensor data (prefer live subcollection, fallback to root)
                    const liveSensorData = sensorData.live || sensorData;

                    // Get sensor health status
                    const sensorHealth = sensorData.sensorHealth || {};

                    // Check for sensor errors (from sensor health or value ranges)
                    const hasErrors =
                        (sensorHealth.soil === 'error') ||
                        (sensorHealth.temp === 'error') ||
                        (sensorHealth.humidity === 'error') ||
                        (sensorHealth.ph === 'error') ||
                        (sensorHealth.waterLevel === 'error') ||
                        (liveSensorData.soil && (liveSensorData.soil < 20 || liveSensorData.soil > 80)) ||
                        (liveSensorData.temp && (liveSensorData.temp < 15 || liveSensorData.temp > 40)) ||
                        (liveSensorData.waterLevel && liveSensorData.waterLevel < 20);

                    devicesData.push({
                        id: deviceId,
                        isOnline,
                        hasErrors,
                        lastSeen: lastSeenMinutes,
                        sensorData: liveSensorData,
                        sensorHealth: sensorHealth
                    });
                } else {
                    offlineCount++;
                    devicesData.push({
                        id: deviceId,
                        isOnline: false,
                        hasErrors: false,
                        lastSeen: null,
                        sensorData: null
                    });
                }
            } catch (error) {
                console.error(`Error loading device ${deviceId}:`, error);
                offlineCount++;
                devicesData.push({
                    id: deviceId,
                    isOnline: false,
                    hasErrors: false,
                    lastSeen: null,
                    sensorData: null
                });
            }
        }

        // Update device status overview
        document.getElementById('modal-total-devices').textContent = deviceIds.length;
        document.getElementById('modal-online-devices').textContent = onlineCount;
        document.getElementById('modal-offline-devices').textContent = offlineCount;

        // Render device details
        const devicesContainer = document.getElementById('modal-devices-list');
        if (devicesData.length === 0) {
            devicesContainer.innerHTML = '<p class="text-[#9db9a6] text-sm p-4 bg-[#28392e] rounded-lg">No devices found</p>';
        } else {
            let devicesHTML = '';
            devicesData.forEach(device => {
                const statusColor = device.isOnline ? 'bg-green-500' : 'bg-red-500';
                const statusText = device.isOnline ? 'Online' : 'Offline';
                const errorBadge = device.hasErrors && device.isOnline
                    ? '<span class="px-2 py-1 rounded text-xs font-medium bg-yellow-500/10 text-yellow-500 ml-2">Sensor Alert</span>'
                    : '';

                const lastSeenText = device.isOnline
                    ? 'Active now'
                    : (device.lastSeen !== null ? `Last seen ${device.lastSeen} min ago` : 'Never connected');

                devicesHTML += `
                    <div class="p-4 bg-[#28392e] rounded-lg">
                        <div class="flex items-center justify-between mb-3">
                            <div class="flex items-center gap-3">
                                <span class="w-3 h-3 rounded-full ${statusColor}"></span>
                                <div>
                                    <p class="text-white font-medium">${device.id}</p>
                                    <p class="text-[#9db9a6] text-xs">${lastSeenText}</p>
                                </div>
                            </div>
                            <div class="flex items-center gap-2">
                                <span class="px-2 py-1 rounded text-xs font-medium ${device.isOnline ? 'bg-green-500/10 text-green-500' : 'bg-red-500/10 text-red-500'}">
                                    ${statusText}
                                </span>
                                ${errorBadge}
                            </div>
                        </div>
                        ${device.sensorData ? `
                            <div class="grid grid-cols-5 gap-2 pt-3 border-t border-[#1c271f]">
                                <div class="text-center">
                                    <div class="flex items-center justify-center gap-1 mb-1">
                                        <p class="text-[#9db9a6] text-xs">Soil %</p>
                                        ${device.sensorHealth?.soil === 'error' ? '<span class="material-symbols-outlined text-red-500 text-xs">error</span>' :
                                          device.sensorHealth?.soil === 'ok' ? '<span class="material-symbols-outlined text-green-500 text-xs">check_circle</span>' : ''}
                                    </div>
                                    <p class="text-white text-sm font-medium">${device.sensorData.soil?.toFixed?.(1) || device.sensorData.soil || 'N/A'}</p>
                                </div>
                                <div class="text-center">
                                    <div class="flex items-center justify-center gap-1 mb-1">
                                        <p class="text-[#9db9a6] text-xs">Temp °C</p>
                                        ${device.sensorHealth?.temp === 'error' ? '<span class="material-symbols-outlined text-red-500 text-xs">error</span>' :
                                          device.sensorHealth?.temp === 'ok' ? '<span class="material-symbols-outlined text-green-500 text-xs">check_circle</span>' : ''}
                                    </div>
                                    <p class="text-white text-sm font-medium">${device.sensorData.temp?.toFixed?.(1) || device.sensorData.temp || 'N/A'}</p>
                                </div>
                                <div class="text-center">
                                    <div class="flex items-center justify-center gap-1 mb-1">
                                        <p class="text-[#9db9a6] text-xs">Humidity %</p>
                                        ${device.sensorHealth?.humidity === 'error' ? '<span class="material-symbols-outlined text-red-500 text-xs">error</span>' :
                                          device.sensorHealth?.humidity === 'ok' ? '<span class="material-symbols-outlined text-green-500 text-xs">check_circle</span>' : ''}
                                    </div>
                                    <p class="text-white text-sm font-medium">${device.sensorData.humidity?.toFixed?.(1) || device.sensorData.humidity || 'N/A'}</p>
                                </div>
                                <div class="text-center">
                                    <div class="flex items-center justify-center gap-1 mb-1">
                                        <p class="text-[#9db9a6] text-xs">pH</p>
                                        ${device.sensorHealth?.ph === 'error' ? '<span class="material-symbols-outlined text-red-500 text-xs">error</span>' :
                                          device.sensorHealth?.ph === 'ok' ? '<span class="material-symbols-outlined text-green-500 text-xs">check_circle</span>' : ''}
                                    </div>
                                    <p class="text-white text-sm font-medium">${device.sensorData.ph?.toFixed?.(1) || device.sensorData.ph || 'N/A'}</p>
                                </div>
                                <div class="text-center">
                                    <div class="flex items-center justify-center gap-1 mb-1">
                                        <p class="text-[#9db9a6] text-xs">Water %</p>
                                        ${device.sensorHealth?.waterLevel === 'error' ? '<span class="material-symbols-outlined text-red-500 text-xs">error</span>' :
                                          device.sensorHealth?.waterLevel === 'ok' ? '<span class="material-symbols-outlined text-green-500 text-xs">check_circle</span>' : ''}
                                    </div>
                                    <p class="text-white text-sm font-medium">${device.sensorData.waterLevel?.toFixed?.(1) || device.sensorData.waterLevel || 'N/A'}</p>
                                </div>
                            </div>
                        ` : '<p class="text-[#9db9a6] text-xs pt-3 border-t border-[#1c271f]">No sensor data available</p>'}
                    </div>
                `;
            });
            devicesContainer.innerHTML = devicesHTML;
        }

        // Render crops with detailed information
        const cropsContainer = document.getElementById('modal-farm-crops');
        if (crops.length === 0) {
            cropsContainer.innerHTML = '<p class="text-[#9db9a6] text-sm">No crops planted yet</p>';
        } else {
            let cropsHTML = '<div class="space-y-3">';
            crops.forEach(crop => {
                const statusClass = crop.status === 'active' ? 'bg-green-500/10 text-green-500 border-green-500/20' :
                                  crop.status === 'harvested' ? 'bg-blue-500/10 text-blue-500 border-blue-500/20' :
                                  'bg-red-500/10 text-red-500 border-red-500/20';

                // Format created date
                let createdDate = 'N/A';
                if (crop.createdAt) {
                    try {
                        createdDate = new Date(crop.createdAt.toDate()).toLocaleDateString('en-US', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric'
                        });
                    } catch (e) {
                        createdDate = 'N/A';
                    }
                }

                cropsHTML += `
                    <div class="p-4 bg-[#1c271f] rounded-lg border border-[#28392e]">
                        <div class="flex items-start justify-between mb-3">
                            <div class="flex-1">
                                <div class="flex items-center gap-2 mb-1">
                                    <span class="material-symbols-outlined text-primary text-lg">eco</span>
                                    <h5 class="text-white font-semibold text-base">${crop.crop_type || 'Unknown Crop'}</h5>
                                </div>
                                ${crop.field_name ? `<p class="text-[#9db9a6] text-sm ml-7">Field: ${crop.field_name}</p>` : ''}
                            </div>
                            <span class="px-3 py-1 rounded-full text-xs font-semibold border ${statusClass}">${crop.status || 'active'}</span>
                        </div>

                        <div class="grid grid-cols-2 gap-3 ml-7">
                            <div>
                                <p class="text-[#9db9a6] text-xs mb-1">Device ID</p>
                                <p class="text-white text-sm font-mono">${crop.device_id || 'N/A'}</p>
                            </div>
                            <div>
                                <p class="text-[#9db9a6] text-xs mb-1">Planted Date</p>
                                <p class="text-white text-sm">${createdDate}</p>
                            </div>
                        </div>

                        ${crop.notes ? `
                            <div class="mt-3 pt-3 border-t border-[#28392e] ml-7">
                                <p class="text-[#9db9a6] text-xs mb-1">Notes</p>
                                <p class="text-white text-sm">${crop.notes}</p>
                            </div>
                        ` : ''}
                    </div>
                `;
            });
            cropsHTML += '</div>';
            cropsContainer.innerHTML = cropsHTML;
        }

        modal.classList.remove('hidden');
    } catch (error) {
        console.error('Error loading farm details:', error);
        alert('Failed to load farm details. Please try again.');
    }
}

// Close Farm Details Modal
document.getElementById('close-farm-modal')?.addEventListener('click', () => {
    document.getElementById('farm-details-modal').classList.add('hidden');
});

document.getElementById('close-farm-modal-btn')?.addEventListener('click', () => {
    document.getElementById('farm-details-modal').classList.add('hidden');
});

// View Farm Location
function viewFarmLocation(lat, lng) {
    window.open(`https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}&zoom=15`, '_blank');
}

// ========================================
// NOTIFICATIONS PAGE
// ========================================

// Load All Notifications
async function loadAllNotifications() {
    try {
        // Initialize notification form handlers
        initializeNotificationForm();

        const snapshot = await db.collection('notifications')
            .orderBy('createdAt', 'desc')
            .limit(50)
            .get();

        const tbody = document.getElementById('all-notifications-tbody');
        tbody.innerHTML = '';

        if (snapshot.empty) {
            tbody.innerHTML = '<tr><td colspan="5" class="p-4 text-center text-[#9db9a6]">No notifications found</td></tr>';
            return;
        }

        snapshot.forEach(doc => {
            const notif = doc.data();
            const typeClass = notif.type === 'alert' ? 'bg-red-500/10 text-red-500' :
                            notif.type === 'warning' ? 'bg-yellow-500/10 text-yellow-500' :
                            notif.type === 'success' ? 'bg-green-500/10 text-green-500' :
                            'bg-blue-500/10 text-blue-500';

            const createdDate = notif.createdAt ?
                new Date(notif.createdAt.toDate()).toLocaleString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                }) : 'N/A';

            const row = `
                <tr class="hover:bg-[#223026] transition-colors">
                    <td class="p-4">
                        <span class="px-2 py-1 rounded text-xs font-medium ${typeClass}">${notif.type || 'info'}</span>
                    </td>
                    <td class="p-4 text-white">${notif.title || 'N/A'}</td>
                    <td class="p-4 text-[#9db9a6] max-w-xs truncate">${notif.message || 'N/A'}</td>
                    <td class="p-4 text-[#9db9a6]">${notif.farmer_id || 'All users'}</td>
                    <td class="p-4 text-[#9db9a6]">${createdDate}</td>
                </tr>
            `;
            tbody.innerHTML += row;
        });
    } catch (error) {
        console.error('Error loading notifications:', error);
        document.getElementById('all-notifications-tbody').innerHTML =
            '<tr><td colspan="5" class="p-4 text-center text-[#9db9a6]">Error loading notifications</td></tr>';
    }
}

// Track if notification form has been initialized
let notificationFormInitialized = false;

// Initialize notification form and handlers
function initializeNotificationForm() {
    // Prevent duplicate initialization
    if (notificationFormInitialized) return;
    notificationFormInitialized = true;

    // Load users for specific user dropdown
    loadNotificationUsers();

    // Handle recipient type change
    const recipientType = document.getElementById('notif-recipient-type');
    const specificUserContainer = document.getElementById('specific-user-select-container');

    recipientType?.addEventListener('change', (e) => {
        if (e.target.value === 'specific') {
            specificUserContainer.classList.remove('hidden');
        } else {
            specificUserContainer.classList.add('hidden');
        }
    });

    // Message character counter
    const messageTextarea = document.getElementById('notif-message');
    const messageCounter = document.getElementById('message-counter');

    messageTextarea?.addEventListener('input', (e) => {
        messageCounter.textContent = e.target.value.length;
    });

    // Template buttons
    document.getElementById('template-maintenance')?.addEventListener('click', () => {
        setNotificationTemplate('warning',
            'Scheduled System Maintenance',
            'Our system will undergo scheduled maintenance on [DATE] from [START TIME] to [END TIME]. During this period, some features may be temporarily unavailable. We apologize for any inconvenience.'
        );
    });

    document.getElementById('template-downtime')?.addEventListener('click', () => {
        setNotificationTemplate('alert',
            'System Downtime Alert',
            'We are currently experiencing technical difficulties. Our team is working to resolve the issue as quickly as possible. We apologize for the inconvenience and appreciate your patience.'
        );
    });

    document.getElementById('template-update')?.addEventListener('click', () => {
        setNotificationTemplate('info',
            'System Update Available',
            'A new update has been released with exciting features and improvements. Update your app to enjoy the latest enhancements and bug fixes.'
        );
    });

    // Clear button
    document.getElementById('clear-notif-btn')?.addEventListener('click', () => {
        clearNotificationForm();
    });

    // Send button
    document.getElementById('send-notif-btn')?.addEventListener('click', async () => {
        await sendNotification();
    });
}

// Load users for notification dropdown
async function loadNotificationUsers() {
    try {
        const snapshot = await db.collection('users').get();
        const userSelect = document.getElementById('notif-specific-user');

        if (!userSelect) return;

        userSelect.innerHTML = '<option value="">Select a user</option>';

        snapshot.forEach(doc => {
            const userData = doc.data();
            const option = document.createElement('option');
            option.value = doc.id;
            option.textContent = `${userData.full_name || 'Unknown'} - ${userData.farm_name || 'No Farm'} (${userData.email || doc.id})`;
            userSelect.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading users for notifications:', error);
    }
}

// Set notification template
function setNotificationTemplate(type, title, message) {
    document.getElementById('notif-type').value = type;
    document.getElementById('notif-title').value = title;
    document.getElementById('notif-message').value = message;
    document.getElementById('message-counter').textContent = message.length;
}

// Clear notification form
function clearNotificationForm() {
    document.getElementById('notif-recipient-type').value = 'all';
    document.getElementById('specific-user-select-container').classList.add('hidden');
    document.getElementById('notif-specific-user').value = '';
    document.getElementById('notif-type').value = 'info';
    document.getElementById('notif-title').value = '';
    document.getElementById('notif-message').value = '';
    document.getElementById('message-counter').textContent = '0';
}

// Send notification
async function sendNotification() {
    try {
        const recipientType = document.getElementById('notif-recipient-type').value;
        const specificUserId = document.getElementById('notif-specific-user').value;
        const type = document.getElementById('notif-type').value;
        const title = document.getElementById('notif-title').value.trim();
        const message = document.getElementById('notif-message').value.trim();

        // Validation
        if (!title) {
            alert('Please enter a notification title');
            return;
        }

        if (!message) {
            alert('Please enter a notification message');
            return;
        }

        if (recipientType === 'specific' && !specificUserId) {
            alert('Please select a specific user');
            return;
        }

        // Disable send button
        const sendBtn = document.getElementById('send-notif-btn');
        const originalBtnHTML = sendBtn.innerHTML;
        sendBtn.disabled = true;
        sendBtn.innerHTML = '<span class="material-symbols-outlined text-[20px] animate-spin">progress_activity</span><span>Sending...</span>';

        // Prepare notification data
        const notificationData = {
            type: type,
            title: title,
            message: message,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            read: false,
            sentBy: 'admin'
        };

        if (recipientType === 'specific') {
            // Send to specific user
            // Get user's Auth UID (not the document ID)
            const userDoc = await db.collection('users').doc(specificUserId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();

                // Use Firebase Auth UID, not document ID
                notificationData.farmer_id = userData.uid || specificUserId;

                // Save to Firestore
                await db.collection('notifications').add(notificationData);

                // If user has FCM token, send push notification via Cloud Function
                if (userData.fcmToken) {
                    // Note: This requires a Cloud Function to send FCM notifications
                    console.log('FCM token found, notification saved to Firestore');
                }

                alert(`Notification sent to user successfully!`);
            } else {
                alert('User not found');
            }
        } else {
            // Send to all users
            const usersSnapshot = await db.collection('users').get();
            const batch = db.batch();

            usersSnapshot.forEach(userDoc => {
                const userData = userDoc.data();
                const notifRef = db.collection('notifications').doc();
                const userNotifData = {
                    ...notificationData,
                    // Use Firebase Auth UID, not document ID
                    farmer_id: userData.uid || userDoc.id
                };
                batch.set(notifRef, userNotifData);
            });

            await batch.commit();
            alert(`Notification sent to ${usersSnapshot.size} users successfully!`);
        }

        // Clear form
        clearNotificationForm();

        // Reload notifications table
        await loadAllNotifications();

        // Re-enable send button
        sendBtn.disabled = false;
        sendBtn.innerHTML = originalBtnHTML;

    } catch (error) {
        console.error('Error sending notification:', error);
        alert('Error sending notification: ' + error.message);

        // Re-enable send button
        const sendBtn = document.getElementById('send-notif-btn');
        sendBtn.disabled = false;
        sendBtn.innerHTML = '<span class="material-symbols-outlined text-[20px]">send</span><span>Send Notification</span>';
    }
}

// ========================================
// SETTINGS PAGE
// ========================================

// Settings configuration stored in localStorage
const SETTINGS_KEY = 'smartfarm_admin_settings';

// Default settings
const defaultSettings = {
    thresholds: {
        soilMin: 20,
        tempMax: 40,
        waterMin: 20,
        phMin: 5.5,
        phMax: 7.5
    },
    autoDeleteOldData: true,
    emailNotifications: true,
    deviceTimeout: 300000 // 5 minutes in milliseconds
};

// Load settings from localStorage
function loadSettings() {
    const saved = localStorage.getItem(SETTINGS_KEY);
    return saved ? JSON.parse(saved) : defaultSettings;
}

// Save settings to localStorage
function saveSettings(settings) {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
}

// Initialize settings page
async function loadSettingsPage() {
    try {
        // Load current settings
        const settings = loadSettings();

        // Update threshold displays
        document.getElementById('threshold-soil-min').textContent = settings.thresholds.soilMin;
        document.getElementById('threshold-temp-max').textContent = settings.thresholds.tempMax;
        document.getElementById('threshold-water-min').textContent = settings.thresholds.waterMin;
        document.getElementById('threshold-ph-range').textContent = `${settings.thresholds.phMin}-${settings.thresholds.phMax}`;

        // Update toggles
        document.getElementById('auto-delete-toggle').checked = settings.autoDeleteOldData;
        document.getElementById('email-notif-toggle').checked = settings.emailNotifications;

        // Update device timeout
        document.getElementById('device-timeout-select').value = settings.deviceTimeout;

        // Load admin profile
        await loadAdminProfile();

        // Load database statistics
        await loadDatabaseStats();

        // Initialize event listeners (only once)
        initializeSettingsHandlers();

    } catch (error) {
        console.error('Error loading settings page:', error);
    }
}

// Load admin profile information
async function loadAdminProfile() {
    try {
        const user = auth.currentUser;
        if (user) {
            document.getElementById('admin-email-display').textContent = user.email || 'admin@smartfarm.com';
            document.getElementById('admin-name-display').textContent = user.displayName || 'Admin User';

            // Get last login from metadata
            if (user.metadata && user.metadata.lastSignInTime) {
                const lastLogin = new Date(user.metadata.lastSignInTime);
                document.getElementById('admin-last-login').textContent = lastLogin.toLocaleString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });
            }
        }
    } catch (error) {
        console.error('Error loading admin profile:', error);
    }
}

// Load database statistics
async function loadDatabaseStats() {
    try {
        // Total users
        const usersSnapshot = await db.collection('users').get();
        document.getElementById('db-total-users').textContent = usersSnapshot.size;

        // Total notifications
        const notificationsSnapshot = await db.collection('notifications').get();
        document.getElementById('db-total-notifications').textContent = notificationsSnapshot.size;

        // Total unique devices
        const cropsSnapshot = await db.collection('crops').get();
        const deviceIds = new Set();
        cropsSnapshot.forEach(doc => {
            const data = doc.data();
            if (data.device_id) deviceIds.add(data.device_id);
        });
        document.getElementById('db-total-devices').textContent = deviceIds.size;

    } catch (error) {
        console.error('Error loading database stats:', error);
    }
}

// Track if settings handlers have been initialized
let settingsHandlersInitialized = false;

// Initialize settings event handlers
function initializeSettingsHandlers() {
    if (settingsHandlersInitialized) return;
    settingsHandlersInitialized = true;

    const settings = loadSettings();

    // Edit thresholds
    document.getElementById('edit-thresholds-btn')?.addEventListener('click', () => {
        editThresholds();
    });

    // Auto-delete toggle
    document.getElementById('auto-delete-toggle')?.addEventListener('change', (e) => {
        settings.autoDeleteOldData = e.target.checked;
        saveSettings(settings);
        alert(`Auto-delete old data ${e.target.checked ? 'enabled' : 'disabled'}`);
    });

    // Email notifications toggle
    document.getElementById('email-notif-toggle')?.addEventListener('change', (e) => {
        settings.emailNotifications = e.target.checked;
        saveSettings(settings);
        alert(`Email notifications ${e.target.checked ? 'enabled' : 'disabled'}`);
    });

    // Device timeout select
    document.getElementById('device-timeout-select')?.addEventListener('change', (e) => {
        settings.deviceTimeout = parseInt(e.target.value);
        saveSettings(settings);
        alert('Device timeout updated successfully');
    });

    // Export database
    document.getElementById('export-database-btn')?.addEventListener('click', async () => {
        await exportDatabaseBackup();
    });

    // Clear old notifications
    document.getElementById('clear-old-notifications-btn')?.addEventListener('click', async () => {
        await clearOldNotifications();
    });

    // Change password
    document.getElementById('change-password-btn')?.addEventListener('click', () => {
        changeAdminPassword();
    });

    // View login history
    document.getElementById('view-login-history-btn')?.addEventListener('click', () => {
        viewLoginHistory();
    });

    // Edit admin profile
    document.getElementById('edit-admin-profile-btn')?.addEventListener('click', () => {
        editAdminProfile();
    });
}

// Edit sensor thresholds
function editThresholds() {
    const settings = loadSettings();

    const soilMin = prompt('Enter minimum soil moisture (%):', settings.thresholds.soilMin);
    if (soilMin !== null && soilMin !== '') {
        settings.thresholds.soilMin = parseFloat(soilMin);
    }

    const tempMax = prompt('Enter maximum temperature (°C):', settings.thresholds.tempMax);
    if (tempMax !== null && tempMax !== '') {
        settings.thresholds.tempMax = parseFloat(tempMax);
    }

    const waterMin = prompt('Enter minimum water level (%):', settings.thresholds.waterMin);
    if (waterMin !== null && waterMin !== '') {
        settings.thresholds.waterMin = parseFloat(waterMin);
    }

    const phMin = prompt('Enter minimum pH level:', settings.thresholds.phMin);
    if (phMin !== null && phMin !== '') {
        settings.thresholds.phMin = parseFloat(phMin);
    }

    const phMax = prompt('Enter maximum pH level:', settings.thresholds.phMax);
    if (phMax !== null && phMax !== '') {
        settings.thresholds.phMax = parseFloat(phMax);
    }

    saveSettings(settings);

    // Update displays
    document.getElementById('threshold-soil-min').textContent = settings.thresholds.soilMin;
    document.getElementById('threshold-temp-max').textContent = settings.thresholds.tempMax;
    document.getElementById('threshold-water-min').textContent = settings.thresholds.waterMin;
    document.getElementById('threshold-ph-range').textContent = `${settings.thresholds.phMin}-${settings.thresholds.phMax}`;

    alert('Thresholds updated successfully!');
}

// Export database backup
async function exportDatabaseBackup() {
    try {
        if (!confirm('This will download a JSON backup of all users, farms, and crops. Continue?')) {
            return;
        }

        const btn = document.getElementById('export-database-btn');
        const originalHTML = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '<div class="flex items-center gap-3"><span class="material-symbols-outlined text-primary text-[24px] animate-spin">progress_activity</span><div><p class="text-white font-medium">Exporting...</p></div></div>';

        const backup = {
            exportDate: new Date().toISOString(),
            version: '1.0.0',
            users: [],
            crops: [],
            notifications: []
        };

        // Export users
        const usersSnapshot = await db.collection('users').get();
        usersSnapshot.forEach(doc => {
            backup.users.push({ id: doc.id, ...doc.data() });
        });

        // Export crops
        const cropsSnapshot = await db.collection('crops').get();
        cropsSnapshot.forEach(doc => {
            backup.crops.push({ id: doc.id, ...doc.data() });
        });

        // Export recent notifications (last 100)
        const notificationsSnapshot = await db.collection('notifications')
            .orderBy('createdAt', 'desc')
            .limit(100)
            .get();
        notificationsSnapshot.forEach(doc => {
            const data = doc.data();
            // Convert Firestore timestamp to ISO string
            if (data.createdAt) {
                data.createdAt = data.createdAt.toDate().toISOString();
            }
            backup.notifications.push({ id: doc.id, ...data });
        });

        // Create and download JSON file
        const json = JSON.stringify(backup, null, 2);
        const blob = new Blob([json], { type: 'application/json' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `smartfarm-backup-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);

        btn.disabled = false;
        btn.innerHTML = originalHTML;

        alert(`Database backup exported successfully!\nUsers: ${backup.users.length}\nCrops: ${backup.crops.length}\nNotifications: ${backup.notifications.length}`);

    } catch (error) {
        console.error('Error exporting database:', error);
        alert('Error exporting database: ' + error.message);
        document.getElementById('export-database-btn').disabled = false;
    }
}

// Clear old notifications
async function clearOldNotifications() {
    try {
        if (!confirm('This will permanently delete notifications older than 30 days. Continue?')) {
            return;
        }

        const btn = document.getElementById('clear-old-notifications-btn');
        const originalHTML = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '<div class="flex items-center gap-3"><span class="material-symbols-outlined text-yellow-500 text-[24px] animate-spin">progress_activity</span><div><p class="text-white font-medium">Clearing...</p></div></div>';

        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const snapshot = await db.collection('notifications')
            .where('createdAt', '<', thirtyDaysAgo)
            .get();

        const batch = db.batch();
        snapshot.forEach(doc => {
            batch.delete(doc.ref);
        });

        await batch.commit();

        btn.disabled = false;
        btn.innerHTML = originalHTML;

        alert(`Successfully deleted ${snapshot.size} old notifications`);

        // Reload database stats
        await loadDatabaseStats();

    } catch (error) {
        console.error('Error clearing notifications:', error);
        alert('Error clearing notifications: ' + error.message);
        document.getElementById('clear-old-notifications-btn').disabled = false;
    }
}

// Change admin password
function changeAdminPassword() {
    const user = auth.currentUser;
    if (!user) {
        alert('No user is currently signed in');
        return;
    }

    const newPassword = prompt('Enter new password (minimum 6 characters):');
    if (!newPassword) return;

    if (newPassword.length < 6) {
        alert('Password must be at least 6 characters long');
        return;
    }

    user.updatePassword(newPassword)
        .then(() => {
            alert('Password updated successfully!');
        })
        .catch((error) => {
            if (error.code === 'auth/requires-recent-login') {
                alert('For security reasons, please sign out and sign in again before changing your password.');
            } else {
                alert('Error updating password: ' + error.message);
            }
            console.error('Error updating password:', error);
        });
}

// View login history
function viewLoginHistory() {
    const user = auth.currentUser;
    if (!user || !user.metadata) {
        alert('No login history available');
        return;
    }

    const createdAt = user.metadata.creationTime ? new Date(user.metadata.creationTime).toLocaleString() : 'N/A';
    const lastSignIn = user.metadata.lastSignInTime ? new Date(user.metadata.lastSignInTime).toLocaleString() : 'N/A';

    alert(`Account Created: ${createdAt}\nLast Sign In: ${lastSignIn}`);
}

// Edit admin profile
function editAdminProfile() {
    const user = auth.currentUser;
    if (!user) {
        alert('No user is currently signed in');
        return;
    }

    const newName = prompt('Enter new display name:', user.displayName || 'Admin User');
    if (!newName) return;

    user.updateProfile({
        displayName: newName
    })
        .then(() => {
            document.getElementById('admin-name-display').textContent = newName;
            alert('Profile updated successfully!');
        })
        .catch((error) => {
            alert('Error updating profile: ' + error.message);
            console.error('Error updating profile:', error);
        });
}

// ========================================
// ANALYTICS PAGE
// ========================================

let analyticsCharts = {
    soilMoisture: null,
    temperature: null,
    waterLevel: null
};

let selectedTimeRange = '7d'; // Default to 7 days
let selectedFarmId = null;
let selectedCropId = null;

// Load Analytics Page
async function loadAnalyticsPage() {
    try {
        await loadAnalyticsFarms();
        await loadAnalyticsData();
        initializeTimeRangeButtons();
    } catch (error) {
        console.error('Error loading analytics page:', error);
    }
}

// Load farms for analytics filter
async function loadAnalyticsFarms() {
    try {
        const snapshot = await db.collection('users').get();
        const farmSelect = document.getElementById('analytics-farm-filter');

        farmSelect.innerHTML = '<option value="">All Farms</option>';

        snapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.farm_name) {
                const option = document.createElement('option');
                option.value = doc.id;
                option.textContent = userData.farm_name;
                farmSelect.appendChild(option);
            }
        });

        // Add event listener for farm selection
        farmSelect.addEventListener('change', async (e) => {
            selectedFarmId = e.target.value || null;
            await loadCropsForFarm(selectedFarmId);
            await loadAnalyticsData();
        });
    } catch (error) {
        console.error('Error loading analytics farms:', error);
    }
}

// Load crops for selected farm
async function loadCropsForFarm(farmId) {
    try {
        const cropSelect = document.getElementById('analytics-crop-filter');
        cropSelect.innerHTML = '<option value="">All Crops</option>';

        if (!farmId) return;

        // Get the user's Firebase Auth UID first
        const userDoc = await db.collection('users').doc(farmId).get();
        if (!userDoc.exists) {
            console.error('Farm user not found:', farmId);
            return;
        }

        const userData = userDoc.data();
        const authUid = userData.uid || farmId;

        // Query crops by Firebase Auth UID
        let cropsSnapshot = await db.collection('crops')
            .where('farmer_id', '==', authUid)
            .get();

        // If no results, try with custom user ID
        if (cropsSnapshot.empty) {
            cropsSnapshot = await db.collection('crops')
                .where('farmer_id', '==', farmId)
                .get();
        }

        if (cropsSnapshot.empty) {
            console.log('No crops found for farm:', farmId, 'or auth UID:', authUid);
        }

        cropsSnapshot.forEach(doc => {
            const cropData = doc.data();
            const option = document.createElement('option');
            option.value = doc.id;
            option.textContent = `${cropData.crop_type || 'Unknown'} (${cropData.device_id || 'N/A'})`;
            cropSelect.appendChild(option);
        });

        // Add event listener for crop selection (only once)
        const newCropSelect = cropSelect.cloneNode(true);
        cropSelect.parentNode.replaceChild(newCropSelect, cropSelect);

        newCropSelect.addEventListener('change', async (e) => {
            selectedCropId = e.target.value || null;
            await loadAnalyticsData();
        });
    } catch (error) {
        console.error('Error loading crops:', error);
    }
}

// Initialize time range buttons
function initializeTimeRangeButtons() {
    const buttons = {
        'time-24h': '24h',
        'time-7d': '7d',
        'time-30d': '30d',
        'time-all': 'all'
    };

    Object.entries(buttons).forEach(([buttonId, range]) => {
        const button = document.getElementById(buttonId);
        if (button) {
            button.addEventListener('click', async () => {
                // Update button states
                Object.keys(buttons).forEach(id => {
                    const btn = document.getElementById(id);
                    if (btn) {
                        if (id === buttonId) {
                            btn.classList.remove('bg-[#111813]', 'border', 'border-[#3b5443]');
                            btn.classList.add('bg-primary', 'font-medium');
                        } else {
                            btn.classList.remove('bg-primary', 'font-medium');
                            btn.classList.add('bg-[#111813]', 'border', 'border-[#3b5443]');
                        }
                    }
                });

                selectedTimeRange = range;
                await loadAnalyticsData();
            });
        }
    });
}

// Load Analytics Data
async function loadAnalyticsData() {
    try {
        // Get all device IDs to analyze
        let deviceIds = [];

        if (selectedCropId) {
            // Get specific crop's device
            const cropDoc = await db.collection('crops').doc(selectedCropId).get();
            if (cropDoc.exists) {
                const cropData = cropDoc.data();
                if (cropData.device_id) {
                    deviceIds.push(cropData.device_id);
                }
            }
        } else if (selectedFarmId) {
            // Get farmer's Firebase Auth UID
            const userDoc = await db.collection('users').doc(selectedFarmId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                const authUid = userData.uid || selectedFarmId;

                // Query crops by Firebase Auth UID
                let cropsSnapshot = await db.collection('crops')
                    .where('farmer_id', '==', authUid)
                    .get();

                // If no results, try with custom user ID
                if (cropsSnapshot.empty) {
                    cropsSnapshot = await db.collection('crops')
                        .where('farmer_id', '==', selectedFarmId)
                        .get();
                }

                cropsSnapshot.forEach(doc => {
                    const cropData = doc.data();
                    if (cropData.device_id) {
                        deviceIds.push(cropData.device_id);
                    }
                });
            }
        } else {
            // Get all devices from all farms
            const cropsSnapshot = await db.collection('crops').get();
            cropsSnapshot.forEach(doc => {
                const cropData = doc.data();
                if (cropData.device_id) {
                    deviceIds.push(cropData.device_id);
                }
            });
        }

        // Remove duplicates
        deviceIds = [...new Set(deviceIds)];

        if (deviceIds.length === 0) {
            updateAnalyticsUI([], []);
            return;
        }

        // Calculate time range
        const now = Date.now();
        let startTime = 0;
        switch (selectedTimeRange) {
            case '24h':
                startTime = now - (24 * 60 * 60 * 1000);
                break;
            case '7d':
                startTime = now - (7 * 24 * 60 * 60 * 1000);
                break;
            case '30d':
                startTime = now - (30 * 24 * 60 * 60 * 1000);
                break;
            default:
                startTime = 0; // All time
        }

        const startTimestamp = Math.floor(startTime / 1000);

        // Fetch historical sensor data for all devices
        const allHistoricalData = [];
        for (const deviceId of deviceIds) {
            try {
                // Load historical data for soil moisture
                const soilHistoryRef = rtdb.ref(`sensors/${deviceId}/history/soil`);
                const soilSnapshot = await soilHistoryRef
                    .orderByKey()
                    .startAt(startTimestamp.toString())
                    .once('value');

                // Load historical data for temperature
                const tempHistoryRef = rtdb.ref(`sensors/${deviceId}/history/temp`);
                const tempSnapshot = await tempHistoryRef
                    .orderByKey()
                    .startAt(startTimestamp.toString())
                    .once('value');

                // Load historical data for humidity
                const humidityHistoryRef = rtdb.ref(`sensors/${deviceId}/history/humidity`);
                const humiditySnapshot = await humidityHistoryRef
                    .orderByKey()
                    .startAt(startTimestamp.toString())
                    .once('value');

                // Load historical data for pH
                const phHistoryRef = rtdb.ref(`sensors/${deviceId}/history/ph`);
                const phSnapshot = await phHistoryRef
                    .orderByKey()
                    .startAt(startTimestamp.toString())
                    .once('value');

                // Load historical data for water level
                const waterHistoryRef = rtdb.ref(`sensors/${deviceId}/history/waterLevel`);
                const waterSnapshot = await waterHistoryRef
                    .orderByKey()
                    .startAt(startTimestamp.toString())
                    .once('value');

                // Combine all historical data by timestamp
                const combinedData = {};

                if (soilSnapshot.exists()) {
                    const soilData = soilSnapshot.val();
                    Object.keys(soilData).forEach(timestamp => {
                        if (!combinedData[timestamp]) {
                            combinedData[timestamp] = { timestamp: parseInt(timestamp) * 1000 };
                        }
                        combinedData[timestamp].soilMoisture = soilData[timestamp];
                    });
                }

                if (tempSnapshot.exists()) {
                    const tempData = tempSnapshot.val();
                    Object.keys(tempData).forEach(timestamp => {
                        if (!combinedData[timestamp]) {
                            combinedData[timestamp] = { timestamp: parseInt(timestamp) * 1000 };
                        }
                        combinedData[timestamp].temperature = tempData[timestamp];
                    });
                }

                if (humiditySnapshot.exists()) {
                    const humidityData = humiditySnapshot.val();
                    Object.keys(humidityData).forEach(timestamp => {
                        if (!combinedData[timestamp]) {
                            combinedData[timestamp] = { timestamp: parseInt(timestamp) * 1000 };
                        }
                        combinedData[timestamp].humidity = humidityData[timestamp];
                    });
                }

                if (phSnapshot.exists()) {
                    const phData = phSnapshot.val();
                    Object.keys(phData).forEach(timestamp => {
                        if (!combinedData[timestamp]) {
                            combinedData[timestamp] = { timestamp: parseInt(timestamp) * 1000 };
                        }
                        combinedData[timestamp].ph = phData[timestamp];
                    });
                }

                if (waterSnapshot.exists()) {
                    const waterData = waterSnapshot.val();
                    Object.keys(waterData).forEach(timestamp => {
                        if (!combinedData[timestamp]) {
                            combinedData[timestamp] = { timestamp: parseInt(timestamp) * 1000 };
                        }
                        combinedData[timestamp].waterLevel = waterData[timestamp];
                    });
                }

                // Convert to array
                Object.values(combinedData).forEach(dataPoint => {
                    allHistoricalData.push(dataPoint);
                });

            } catch (error) {
                console.error(`Error loading device ${deviceId}:`, error);
            }
        }

        // If no historical data, fall back to live data
        if (allHistoricalData.length === 0) {
            console.log('No historical data found, using live data');
            for (const deviceId of deviceIds) {
                try {
                    const deviceSnapshot = await rtdb.ref(`sensors/${deviceId}`).once('value');
                    const sensorData = deviceSnapshot.val();
                    if (sensorData) {
                        allHistoricalData.push(sensorData);
                    }
                } catch (error) {
                    console.error(`Error loading device ${deviceId}:`, error);
                }
            }
        }

        // Update UI with analytics
        updateAnalyticsUI(allHistoricalData, allHistoricalData);
    } catch (error) {
        console.error('Error loading analytics data:', error);
    }
}

// Update Analytics UI
function updateAnalyticsUI(filteredData, allData) {
    if (filteredData.length === 0) {
        document.getElementById('avg-soil-moisture').textContent = '--%';
        document.getElementById('avg-temperature').textContent = '--°C';
        document.getElementById('avg-ph').textContent = '--';
        document.getElementById('soil-moisture-change').textContent = '+0.0%';
        document.getElementById('temperature-change').textContent = '-0.0°C';
        document.getElementById('ph-status').textContent = 'No Data';

        // Clear charts
        if (analyticsCharts.soilMoisture) {
            analyticsCharts.soilMoisture.destroy();
            analyticsCharts.soilMoisture = null;
        }
        if (analyticsCharts.temperature) {
            analyticsCharts.temperature.destroy();
            analyticsCharts.temperature = null;
        }
        if (analyticsCharts.waterLevel) {
            analyticsCharts.waterLevel.destroy();
            analyticsCharts.waterLevel = null;
        }
        return;
    }

    // Calculate averages
    const avgSoilMoisture = filteredData.reduce((sum, d) => sum + (d.soilMoisture || 0), 0) / filteredData.length;
    const avgTemperature = filteredData.reduce((sum, d) => sum + (d.temperature || 0), 0) / filteredData.length;
    const avgPh = filteredData.reduce((sum, d) => sum + (d.ph || 0), 0) / filteredData.length;

    // Calculate changes (compare with previous period)
    const previousData = allData.filter(d => {
        const now = Date.now();
        let timeLimit = 0;
        switch (selectedTimeRange) {
            case '24h':
                timeLimit = now - (48 * 60 * 60 * 1000); // Previous 24h
                break;
            case '7d':
                timeLimit = now - (14 * 24 * 60 * 60 * 1000); // Previous 7d
                break;
            case '30d':
                timeLimit = now - (60 * 24 * 60 * 60 * 1000); // Previous 30d
                break;
            default:
                return false;
        }
        return d.timestamp && d.timestamp >= timeLimit && d.timestamp < (now - getTimeRangeMs());
    });

    let soilMoistureChange = 0;
    let temperatureChange = 0;

    if (previousData.length > 0) {
        const prevAvgSoil = previousData.reduce((sum, d) => sum + (d.soilMoisture || 0), 0) / previousData.length;
        const prevAvgTemp = previousData.reduce((sum, d) => sum + (d.temperature || 0), 0) / previousData.length;

        soilMoistureChange = ((avgSoilMoisture - prevAvgSoil) / prevAvgSoil) * 100;
        temperatureChange = avgTemperature - prevAvgTemp;
    }

    // Update statistics cards
    document.getElementById('avg-soil-moisture').textContent = `${avgSoilMoisture.toFixed(0)}%`;
    document.getElementById('avg-temperature').textContent = `${avgTemperature.toFixed(0)}°C`;
    document.getElementById('avg-ph').textContent = avgPh.toFixed(1);

    // Update changes
    const soilChangeEl = document.getElementById('soil-moisture-change');
    soilChangeEl.textContent = `${soilMoistureChange >= 0 ? '+' : ''}${soilMoistureChange.toFixed(1)}%`;
    soilChangeEl.className = soilMoistureChange >= 0 ? 'text-green-500 text-sm font-medium' : 'text-red-500 text-sm font-medium';

    const tempChangeEl = document.getElementById('temperature-change');
    tempChangeEl.textContent = `${temperatureChange >= 0 ? '+' : ''}${temperatureChange.toFixed(1)}°C`;
    tempChangeEl.className = temperatureChange >= 0 ? 'text-red-500 text-sm font-medium' : 'text-blue-500 text-sm font-medium';

    // Update pH status
    const phStatusEl = document.getElementById('ph-status');
    if (avgPh >= 6.0 && avgPh <= 7.5) {
        phStatusEl.textContent = 'Stable';
        phStatusEl.className = 'text-green-500 text-sm font-medium';
    } else if (avgPh >= 5.5 && avgPh <= 8.0) {
        phStatusEl.textContent = 'Fair';
        phStatusEl.className = 'text-yellow-500 text-sm font-medium';
    } else {
        phStatusEl.textContent = 'Warning';
        phStatusEl.className = 'text-red-500 text-sm font-medium';
    }

    // Generate chart data
    generateCharts(filteredData);
}

// Get time range in milliseconds
function getTimeRangeMs() {
    switch (selectedTimeRange) {
        case '24h': return 24 * 60 * 60 * 1000;
        case '7d': return 7 * 24 * 60 * 60 * 1000;
        case '30d': return 30 * 24 * 60 * 60 * 1000;
        default: return Infinity;
    }
}

// Generate Charts
function generateCharts(data) {
    console.log('Generating charts with data:', data);

    // Check if Chart.js is loaded
    if (typeof Chart === 'undefined') {
        console.error('Chart.js is not loaded!');
        return;
    }

    // Sort data by timestamp
    const sortedData = [...data].sort((a, b) => a.timestamp - b.timestamp);

    // Group data by hour for smoother charts
    const hourlyData = {};
    sortedData.forEach(d => {
        const hourKey = new Date(d.timestamp).toISOString().slice(0, 13); // Group by hour
        if (!hourlyData[hourKey]) {
            hourlyData[hourKey] = { soilMoisture: [], temperature: [], waterLevel: [] };
        }
        if (d.soilMoisture) hourlyData[hourKey].soilMoisture.push(d.soilMoisture);
        if (d.temperature) hourlyData[hourKey].temperature.push(d.temperature);
        if (d.waterLevel) hourlyData[hourKey].waterLevel.push(d.waterLevel);
    });

    // Calculate hourly averages
    const labels = [];
    const soilMoistureValues = [];
    const temperatureValues = [];
    const waterLevelValues = [];

    Object.keys(hourlyData).sort().forEach(hourKey => {
        const date = new Date(hourKey + ':00:00Z');
        labels.push(date);

        const avgSoil = hourlyData[hourKey].soilMoisture.length > 0
            ? hourlyData[hourKey].soilMoisture.reduce((a, b) => a + b, 0) / hourlyData[hourKey].soilMoisture.length
            : null;
        const avgTemp = hourlyData[hourKey].temperature.length > 0
            ? hourlyData[hourKey].temperature.reduce((a, b) => a + b, 0) / hourlyData[hourKey].temperature.length
            : null;
        const avgWater = hourlyData[hourKey].waterLevel.length > 0
            ? hourlyData[hourKey].waterLevel.reduce((a, b) => a + b, 0) / hourlyData[hourKey].waterLevel.length
            : null;

        soilMoistureValues.push(avgSoil);
        temperatureValues.push(avgTemp);
        waterLevelValues.push(avgWater);
    });

    console.log('Chart data prepared - Labels:', labels.length, 'Soil values:', soilMoistureValues.length);

    // Generate Soil Moisture Chart
    const soilMoistureCtx = document.getElementById('soil-moisture-chart');
    if (!soilMoistureCtx) {
        console.error('Soil moisture chart canvas not found!');
        return;
    }

    if (analyticsCharts.soilMoisture) {
        analyticsCharts.soilMoisture.destroy();
    }

    try {
        analyticsCharts.soilMoisture = new Chart(soilMoistureCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Soil Moisture (%)',
                    data: soilMoistureValues,
                    borderColor: '#4ade80',
                    backgroundColor: 'rgba(74, 222, 128, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3,
                    pointBackgroundColor: '#4ade80'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        backgroundColor: '#1c271f',
                        titleColor: '#fff',
                        bodyColor: '#9db9a6',
                        borderColor: '#28392e',
                        borderWidth: 1
                    }
                },
                scales: {
                    x: {
                        grid: {
                            color: '#28392e'
                        },
                        ticks: {
                            color: '#9db9a6'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            color: '#28392e'
                        },
                        ticks: {
                            color: '#9db9a6',
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                }
            }
        });
        console.log('Soil moisture chart created successfully');
    } catch (error) {
        console.error('Error creating soil moisture chart:', error);
    }

    // Generate Temperature Chart
    const temperatureCtx = document.getElementById('temperature-chart');
    if (!temperatureCtx) {
        console.error('Temperature chart canvas not found!');
        return;
    }

    if (analyticsCharts.temperature) {
        analyticsCharts.temperature.destroy();
    }

    try {
        analyticsCharts.temperature = new Chart(temperatureCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Temperature (°C)',
                    data: temperatureValues,
                    borderColor: '#fb923c',
                    backgroundColor: 'rgba(251, 146, 60, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3,
                    pointBackgroundColor: '#fb923c'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        backgroundColor: '#1c271f',
                        titleColor: '#fff',
                        bodyColor: '#9db9a6',
                        borderColor: '#28392e',
                        borderWidth: 1
                    }
                },
                scales: {
                    x: {
                        grid: {
                            color: '#28392e'
                        },
                        ticks: {
                            color: '#9db9a6'
                        }
                    },
                    y: {
                        grid: {
                            color: '#28392e'
                        },
                        ticks: {
                            color: '#9db9a6',
                            callback: function(value) {
                                return value + '°C';
                            }
                        }
                    }
                }
            }
        });
        console.log('Temperature chart created successfully');
    } catch (error) {
        console.error('Error creating temperature chart:', error);
    }

    // Generate Water Level Chart
    const waterLevelCtx = document.getElementById('water-level-chart');
    if (!waterLevelCtx) {
        console.error('Water level chart canvas not found!');
        return;
    }

    if (analyticsCharts.waterLevel) {
        analyticsCharts.waterLevel.destroy();
    }

    try {
        analyticsCharts.waterLevel = new Chart(waterLevelCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Water Level (%)',
                    data: waterLevelValues,
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3,
                    pointBackgroundColor: '#3b82f6',
                    spanGaps: true // This will connect the line across null values
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        backgroundColor: '#1c271f',
                        titleColor: '#fff',
                        bodyColor: '#9db9a6',
                        borderColor: '#28392e',
                        borderWidth: 1
                    }
                },
                scales: {
                    x: {
                        grid: {
                            color: '#28392e'
                        },
                        ticks: {
                            color: '#9db9a6'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            color: '#28392e'
                        },
                        ticks: {
                            color: '#9db9a6',
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                }
            }
        });
        console.log('Water level chart created successfully');
    } catch (error) {
        console.error('Error creating water level chart:', error);
    }
}

// Export Report
document.getElementById('export-report-btn')?.addEventListener('click', async () => {
    try {
        const btn = document.getElementById('export-report-btn');
        const originalHTML = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '<span class="material-symbols-outlined text-[20px]">hourglass_empty</span><span class="font-medium">Exporting...</span>';

        // Get current analytics data
        let deviceIds = [];

        if (selectedCropId) {
            const cropDoc = await db.collection('crops').doc(selectedCropId).get();
            if (cropDoc.exists) {
                const cropData = cropDoc.data();
                if (cropData.device_id) {
                    deviceIds.push(cropData.device_id);
                }
            }
        } else if (selectedFarmId) {
            const cropsSnapshot = await db.collection('crops')
                .where('farmer_id', '==', selectedFarmId)
                .get();

            cropsSnapshot.forEach(doc => {
                const cropData = doc.data();
                if (cropData.device_id) {
                    deviceIds.push(cropData.device_id);
                }
            });
        } else {
            const cropsSnapshot = await db.collection('crops').get();
            cropsSnapshot.forEach(doc => {
                const cropData = doc.data();
                if (cropData.device_id) {
                    deviceIds.push(cropData.device_id);
                }
            });
        }

        deviceIds = [...new Set(deviceIds)];

        if (deviceIds.length === 0) {
            alert('No device data found to export');
            btn.disabled = false;
            btn.innerHTML = originalHTML;
            return;
        }

        // Calculate time range (last 7 days) - Firebase RTDB stores timestamps in SECONDS
        const endTime = Math.floor(Date.now() / 1000);
        const startTime = endTime - (7 * 24 * 60 * 60);

        // Fetch historical sensor data
        const allSensorData = [];
        for (const deviceId of deviceIds) {
            try {
                // Fetch soil moisture history
                const soilSnapshot = await rtdb.ref(`sensors/${deviceId}/history/soil`)
                    .orderByKey()
                    .startAt(startTime.toString())
                    .endAt(endTime.toString())
                    .once('value');

                const soilData = soilSnapshot.val() || {};

                // Fetch temperature history
                const tempSnapshot = await rtdb.ref(`sensors/${deviceId}/history/temp`)
                    .orderByKey()
                    .startAt(startTime.toString())
                    .endAt(endTime.toString())
                    .once('value');

                const tempData = tempSnapshot.val() || {};

                // Fetch humidity history
                const humiditySnapshot = await rtdb.ref(`sensors/${deviceId}/history/humidity`)
                    .orderByKey()
                    .startAt(startTime.toString())
                    .endAt(endTime.toString())
                    .once('value');

                const humidityData = humiditySnapshot.val() || {};

                // Fetch pH history
                const phSnapshot = await rtdb.ref(`sensors/${deviceId}/history/ph`)
                    .orderByKey()
                    .startAt(startTime.toString())
                    .endAt(endTime.toString())
                    .once('value');

                const phData = phSnapshot.val() || {};

                // Fetch water level history
                const waterSnapshot = await rtdb.ref(`sensors/${deviceId}/history/waterLevel`)
                    .orderByKey()
                    .startAt(startTime.toString())
                    .endAt(endTime.toString())
                    .once('value');

                const waterData = waterSnapshot.val() || {};

                // Combine all timestamps
                const allTimestamps = new Set([
                    ...Object.keys(soilData),
                    ...Object.keys(tempData),
                    ...Object.keys(humidityData),
                    ...Object.keys(phData),
                    ...Object.keys(waterData)
                ]);

                // Create combined data rows
                allTimestamps.forEach(timestamp => {
                    allSensorData.push({
                        deviceId,
                        timestamp: parseInt(timestamp),
                        soilMoisture: soilData[timestamp] || null,
                        temperature: tempData[timestamp] || null,
                        humidity: humidityData[timestamp] || null,
                        ph: phData[timestamp] || null,
                        waterLevel: waterData[timestamp] || null
                    });
                });

            } catch (error) {
                console.error(`Error loading device ${deviceId}:`, error);
            }
        }

        if (allSensorData.length === 0) {
            alert('No historical data found for the selected period');
            btn.disabled = false;
            btn.innerHTML = originalHTML;
            return;
        }

        // Sort by timestamp
        allSensorData.sort((a, b) => a.timestamp - b.timestamp);

        // Generate CSV
        let csv = 'Device ID,Timestamp,Date/Time,Soil Moisture (%),Temperature (°C),Humidity (%),pH,Water Level (%)\n';

        allSensorData.forEach(data => {
            // Convert Unix timestamp (seconds) to milliseconds for Date object
            const date = new Date(data.timestamp * 1000).toISOString().replace('T', ' ').split('.')[0];
            csv += `${data.deviceId},${data.timestamp},${date},${data.soilMoisture !== null ? data.soilMoisture : 'N/A'},${data.temperature !== null ? data.temperature : 'N/A'},${data.humidity !== null ? data.humidity : 'N/A'},${data.ph !== null ? data.ph : 'N/A'},${data.waterLevel !== null ? data.waterLevel : 'N/A'}\n`;
        });

        // Download CSV
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        const dateStr = new Date().toISOString().split('T')[0];
        const farmFilter = selectedFarmId ? '-farm-' + selectedFarmId.substring(0, 8) : '';
        const cropFilter = selectedCropId ? '-crop-' + selectedCropId.substring(0, 8) : '';
        a.download = `smart-farm-analytics${farmFilter}${cropFilter}-${dateStr}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);

        btn.disabled = false;
        btn.innerHTML = originalHTML;
        alert(`Report exported successfully! ${allSensorData.length} data points exported.`);
    } catch (error) {
        console.error('Error exporting report:', error);
        const btn = document.getElementById('export-report-btn');
        btn.disabled = false;
        btn.innerHTML = '<span class="material-symbols-outlined text-[20px]">download</span><span class="font-medium">Export Report</span>';
        alert('Failed to export report: ' + error.message);
    }
});

console.log('App initialized');
