/// App-wide configuration for the CreateCart Admin console.
///
/// This is a thin client over the SAME `createcart-api` the storefronts use —
/// the multi-tenant API backed by Supabase. No new backend.
class AppConfig {
  /// CreateCart API base.
  ///   • production (default): the deployed Vercel API.
  ///   • local dev: override at build time with
  ///     --dart-define=API_BASE=http://localhost:8000 (works on a real device
  ///     over `adb reverse tcp:8000 tcp:8000`, or use the emulator's
  ///     'http://10.0.2.2:8000' / your PC's LAN IP).
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://createcart-api.vercel.app',
  );

  /// Default platform-owner username. The real secret is the admin key
  /// (the API's CREATECART_ADMIN_KEY). The username is shown on the console
  /// and can be anything you like — set CREATECART_ADMIN_USER on the API if
  /// you want it validated server-side later.
  static const String defaultOwnerUser = 'admin';

  static const String appName = 'CreateCart Admin';
  static const String poweredBy = 'Powered by CreateCart';
}
