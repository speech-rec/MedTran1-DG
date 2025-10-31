class AppConfig {
  // Deepgram Configuration
  // IMPORTANT: Replace with your actual Deepgram API key
  // You can get your API key from: https://console.deepgram.com/
  static const String deepgramApiKey = 'ce7e2a76b8132b28e4260608fb72e7c17d5c0af6';
  
  // Deepgram API Settings
  static const String deepgramBaseUrl = 'wss://api.deepgram.com/v1/listen';
  static const String deepgramModel = 'nova-2'; // Using Nova-2 (Nova-3 is not available yet)
  static const String defaultLanguage = 'en-US';
  
  // Audio Recording Settings
  static const int sampleRate = 16000;
  static const int bitRate = 128000;
  static const int channels = 1;
  
  // App Settings
  static const bool enableDebugLogs = true;
  static const int maxRecordingDurationMinutes = 60;
  
  // Validation
  static bool get isDeepgramConfigured => deepgramApiKey != 'YOUR_DEEPGRAM_API_KEY_HERE';
}