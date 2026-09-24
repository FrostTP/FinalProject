class OAuthConfig {
  // Public OAuth client identifier, not a client secret.
  // A build can override this project default with --dart-define.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '563227805774-fuujkq4d8ham9i1p448t32rd005ub1sd.apps.googleusercontent.com',
  );
}
