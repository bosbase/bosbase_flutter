/// Centralized Bosbase configuration.
class AppConfig {
  // Bosbase server URL (without trailing slash).
  static const String endpoint = 'http://192.168.37.129:8090';

  // Superuser/admin credentials used by this demo app.
  // NOTE: For production apps, do NOT hardcode secrets.
  static const String adminEmail = 'a@qq.com';
  static const String adminPassword = 'bosbasepass';
}