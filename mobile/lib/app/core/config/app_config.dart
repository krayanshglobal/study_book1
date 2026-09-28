class AppConfig {
  static const String appName = 'CMATHS';
  static const String appVersion = '1.0.0';
  
  // Override for local/testing builds with:
  // --dart-define=API_BASE_URL=http://localhost:8001
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cmaths-backend.onrender.com',
  );

  // Optional Web Client ID for Google Sign-In backend token verification
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 15000;
}
