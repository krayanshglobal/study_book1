import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import "@/App.css";
import { AuthProvider, useAuth } from "@/contexts/AuthContext";
import ProtectedRoute from "@/components/ProtectedRoute";
import Layout from "@/components/Layout";
import { Toaster } from "@/components/ui/sonner";

import Landing from "@/pages/Landing";
import Login from "@/pages/Login";
import Register from "@/pages/Register";
import ForgotPassword from "@/pages/ForgotPassword";
import StudentDashboard from "@/pages/StudentDashboard";
import QuestionBank from "@/pages/QuestionBank";
import Tests from "@/pages/Tests";
import LiveTest from "@/pages/LiveTest";
import TestResult from "@/pages/TestResult";
import Videos from "@/pages/Videos";
import Leaderboard from "@/pages/Leaderboard";
import Referrals from "@/pages/Referrals";
import Pricing from "@/pages/Pricing";
import PaymentSuccess from "@/pages/PaymentSuccess";
import Profile from "@/pages/Profile";

import MyAnalytics from "@/pages/MyAnalytics";
import Explorer from "@/pages/Explorer";

import AdminDashboard from "@/pages/admin/AdminDashboard";
import ManageQuestions from "@/pages/admin/ManageQuestions";
import ManageTests from "@/pages/admin/ManageTests";
import ManageVideos from "@/pages/admin/ManageVideos";
import ManageNotes from "@/pages/admin/ManageNotes";
import ManagePromos from "@/pages/admin/ManagePromos";
import ManageUsers from "@/pages/admin/ManageUsers";
import ManagePlans from "@/pages/admin/ManagePlans";
import ManageAnnouncements from "@/pages/admin/ManageAnnouncements";
import AdminAnalytics from "@/pages/admin/AdminAnalytics";
import ManageClassRequests from "@/pages/admin/ManageClassRequests";
import SuperAdmin from "@/pages/admin/SuperAdmin";
import ManageFlashcards from "@/pages/admin/ManageFlashcards";
import ManagePayments from "@/pages/admin/ManagePayments";

function DashboardRouter() {
  const { user } = useAuth();
  if (!user) return null;
  if (user.role === "admin" || user.role === "superadmin") return <Navigate to="/admin" replace />;
  return <StudentDashboard />;
}

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Toaster position="top-right" richColors />
        <Routes>
          {/* Public */}
          <Route path="/" element={<Layout><Landing /></Layout>} />
          <Route path="/login" element={<Layout><Login /></Layout>} />
          <Route path="/register" element={<Layout><Register /></Layout>} />
          <Route path="/forgot-password" element={<Layout><ForgotPassword /></Layout>} />

          {/* Student */}
          <Route path="/dashboard" element={<ProtectedRoute><Layout><DashboardRouter /></Layout></ProtectedRoute>} />
          <Route path="/explorer" element={<ProtectedRoute><Layout><Explorer /></Layout></ProtectedRoute>} />
          <Route path="/questions" element={<ProtectedRoute><Layout><QuestionBank /></Layout></ProtectedRoute>} />
          <Route path="/tests" element={<ProtectedRoute><Layout><Tests /></Layout></ProtectedRoute>} />
          <Route path="/tests/:id/live" element={<ProtectedRoute roles={["student"]}><LiveTest /></ProtectedRoute>} />
          <Route path="/tests/:id/result" element={<ProtectedRoute><Layout><TestResult /></Layout></ProtectedRoute>} />
          <Route path="/videos" element={<ProtectedRoute><Layout><Videos /></Layout></ProtectedRoute>} />
          <Route path="/leaderboard" element={<ProtectedRoute><Layout><Leaderboard /></Layout></ProtectedRoute>} />
          <Route path="/my-analytics" element={<ProtectedRoute roles={["student"]}><Layout><MyAnalytics /></Layout></ProtectedRoute>} />
          <Route path="/referrals" element={<ProtectedRoute roles={["student"]}><Layout><Referrals /></Layout></ProtectedRoute>} />
          <Route path="/pricing" element={<ProtectedRoute><Layout><Pricing /></Layout></ProtectedRoute>} />
          <Route path="/payment/success" element={<ProtectedRoute><Layout><PaymentSuccess /></Layout></ProtectedRoute>} />
          <Route path="/profile" element={<ProtectedRoute><Layout><Profile /></Layout></ProtectedRoute>} />

          {/* Admin */}
          <Route path="/admin" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><AdminDashboard /></Layout></ProtectedRoute>} />
          <Route path="/admin/questions" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageQuestions /></Layout></ProtectedRoute>} />
          <Route path="/admin/tests" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageTests /></Layout></ProtectedRoute>} />
          <Route path="/admin/videos" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageVideos /></Layout></ProtectedRoute>} />
          <Route path="/admin/notes" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageNotes /></Layout></ProtectedRoute>} />
          <Route path="/admin/promos" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManagePromos /></Layout></ProtectedRoute>} />
          <Route path="/admin/analytics" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><AdminAnalytics /></Layout></ProtectedRoute>} />
          <Route path="/admin/users" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageUsers /></Layout></ProtectedRoute>} />
          <Route path="/admin/plans" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManagePlans /></Layout></ProtectedRoute>} />
          <Route path="/admin/announcements" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageAnnouncements /></Layout></ProtectedRoute>} />
          <Route path="/admin/class-requests" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageClassRequests /></Layout></ProtectedRoute>} />
          <Route path="/admin/flashcards" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManageFlashcards /></Layout></ProtectedRoute>} />
          <Route path="/admin/payments" element={<ProtectedRoute roles={["admin", "superadmin"]}><Layout><ManagePayments /></Layout></ProtectedRoute>} />
          <Route path="/superadmin" element={<ProtectedRoute roles={["superadmin"]}><Layout><SuperAdmin /></Layout></ProtectedRoute>} />

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
