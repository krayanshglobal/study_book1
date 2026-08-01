class AppConfig {
  static const String appName = 'StudyBook';
  static const String appVersion = '1.0.0';
  
  // Default to localhost for Android emulator / local dev, overrideable
  static String baseUrl = 'https://studybook1-production.up.railway.app';
  
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 15000;
}
