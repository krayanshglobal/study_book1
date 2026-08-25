import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyD8mhfEEX99SaJ5A7bkQ1C8d2QLs2dlKGM",
  authDomain: "student-managment-a4ef3.firebaseapp.com",
  projectId: "student-managment-a4ef3",
  storageBucket: "student-managment-a4ef3.firebasestorage.app",
  messagingSenderId: "185340772057",
  appId: "1:185340772057:web:56cdf3309aa83f37bc08c8"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export default app;
