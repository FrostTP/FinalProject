class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://192.168.1.26/timeguard_api/',
    defaultValue: 'http://10.0.2.2/timeguard_api/',
  );
  static const timeout = Duration(seconds: 60);
}