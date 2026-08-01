class ApiEndpoints {
  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String me = '/api/auth/me';
  static const String logout = '/api/auth/logout';
  static const String refresh = '/api/auth/refresh';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String changePassword = '/api/auth/change-password';

  // Questions
  static const String questions = '/api/questions';
  static const String topics = '/api/questions/topics';
  static const String bulkCsv = '/api/questions/bulk-csv';
  static String questionDetail(String id) => '/api/questions/$id';
  static String checkQuestion(String id) => '/api/questions/$id/check';

  // Tests
  static const String tests = '/api/tests';
  static const String upcomingTests = '/api/tests/upcoming';
  static String testDetail(String id) => '/api/tests/$id';
  static String startTest(String id) => '/api/tests/$id/start';
  static String submitTest(String id) => '/api/tests/$id/submit';
  static String testResult(String id) => '/api/tests/$id/result';
  static String testLeaderboard(String id) => '/api/tests/$id/leaderboard';
  static String testAttempts(String id) => '/api/tests/$id/attempts';

  // Videos
  static const String videos = '/api/videos';
  static String videoDetail(String id) => '/api/videos/$id';

  // Notes
  static const String notes = '/api/notes';
  static String noteDetail(String id) => '/api/notes/$id';

  // Flashcards
  static const String flashcards = '/api/flashcards';
  static String flashcardDetail(String id) => '/api/flashcards/$id';

  // Discussions
  static const String discussions = '/api/discussions';
  static String discussionDetail(String id) => '/api/discussions/$id';
  static String discussionReply(String id) => '/api/discussions/$id/reply';
  static String deleteDiscussionReply(String threadId, String replyId) =>
      '/api/discussions/$threadId/reply/$replyId';

  // Promos
  static const String promos = '/api/promos';
  static String promoDetail(String id) => '/api/promos/$id';

  // Leaderboard & Referrals
  static const String leaderboard = '/api/leaderboard';
  static const String myReferrals = '/api/referrals/me';

  // Plans
  static const String plans = '/api/plans';
  static const String adminPlans = '/api/admin/plans';
  static String adminPlanDetail(String id) => '/api/admin/plans/$id';

  // Payments
  static const String checkout = '/api/payments/checkout';
  static String paymentStatus(String sessionId) => '/api/payments/status/$sessionId';

  // Admin
  static const String adminStats = '/api/admin/stats';
  static const String adminUsers = '/api/admin/users';
  static const String adminAnalyticsWeekly = '/api/admin/analytics/weekly';
  static const String adminAnalyticsTopics = '/api/admin/analytics/topics';
  static const String adminAnalyticsTests = '/api/admin/analytics/tests';
  static const String adminPayments = '/api/admin/payments';
  static const String adminClassChangeRequests = '/api/admin/class-change-requests';
  static String adminClassChangeRequestAction(String id, String action) =>
      '/api/admin/class-change-requests/$id/$action';

  // Super Admin
  static const String superadminAdmins = '/api/superadmin/admins';
  static String superadminAdminDetail(String id) => '/api/superadmin/admins/$id';

  // Announcements
  static const String announcements = '/api/announcements';
  static String announcementDetail(String id) => '/api/announcements/$id';

  // Uploads
  static const String uploadImage = '/api/uploads/image';
  static String getImage(String id) => '/api/uploads/image/$id';

  // Analytics
  static const String studentAnalytics = '/api/students/me/analytics';
}
