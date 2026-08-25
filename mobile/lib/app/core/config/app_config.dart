class AppConfig {
  static const String appName = 'StudyBook';
  static const String appVersion = '1.0.0';
  
  // Base URL for production / local backend
  static String baseUrl = 'https://studybook1-production.up.railway.app';
  
  // Optional Web Client ID for Google Sign-In backend token verification
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 15000;
}
