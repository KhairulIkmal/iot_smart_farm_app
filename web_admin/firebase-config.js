// Firebase Configuration
const firebaseConfig = {
  apiKey: "AIzaSyDArwZnCqK0BYM7inemsbrhAnKVq8Ul4yI",
  authDomain: "iot-smartfarm-system.firebaseapp.com",
  databaseURL: "https://iot-smartfarm-system-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "iot-smartfarm-system",
  storageBucket: "iot-smartfarm-system.firebasestorage.app",
  messagingSenderId: "237251653433",
  appId: "1:237251653433:android:d9797017058261524ac2e8"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Initialize services
const auth = firebase.auth();
const db = firebase.firestore();
const rtdb = firebase.database();

console.log('Firebase initialized successfully');
