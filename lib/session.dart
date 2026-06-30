import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

enum Role { none, platform, tenant }

/// Holds the signed-in admin session and persists it so the console reopens
/// already logged in. Credentials live only on this device.
class Session extends ChangeNotifier {
  final AdminApi api = AdminApi();

  Role role = Role.none;
  bool ready = false; // restore() finished

  // Platform owner
  String ownerUser = 'admin';
  String _adminKey = '';
  String get adminKey => _adminKey;

  // Tenant admin
  String tenantSlug = '';
  String _tenantKey = '';
  String get tenantKey => _tenantKey;
  int? tenantId;
  String? tenantBaseUrl;

  bool get isPlatform => role == Role.platform;
  bool get isTenant => role == Role.tenant;

  static const _kRole = 'role';
  static const _kOwnerUser = 'owner_user';
  static const _kAdminKey = 'admin_key';
  static const _kTenantSlug = 'tenant_slug';
  static const _kTenantKey = 'tenant_key';

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    final r = p.getString(_kRole);
    if (r == 'platform') {
      ownerUser = p.getString(_kOwnerUser) ?? 'admin';
      _adminKey = p.getString(_kAdminKey) ?? '';
      if (_adminKey.isNotEmpty) role = Role.platform;
    } else if (r == 'tenant') {
      tenantSlug = p.getString(_kTenantSlug) ?? '';
      _tenantKey = p.getString(_kTenantKey) ?? '';
      if (tenantSlug.isNotEmpty && _tenantKey.isNotEmpty) role = Role.tenant;
    }
    ready = true;
    notifyListeners();
  }

  /// Sign in as the platform owner. [username] is a display label; the [key]
  /// (admin key) is what the API actually verifies.
  Future<void> loginPlatform(String username, String key) async {
    final ok = await api.platformLogin(key);
    if (!ok) throw ApiException(401, 'Invalid admin key');
    ownerUser = username.trim().isEmpty ? 'admin' : username.trim();
    _adminKey = key;
    role = Role.platform;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRole, 'platform');
    await p.setString(_kOwnerUser, ownerUser);
    await p.setString(_kAdminKey, key);
    notifyListeners();
  }

  /// Sign in as a business (tenant slug + password).
  Future<void> loginTenant(String slug, String key) async {
    final me = await api.tenantLogin(slug, key);
    tenantSlug = slug;
    _tenantKey = key;
    tenantId = me['id'] is int ? me['id'] as int : null;
    tenantBaseUrl = me['base_url']?.toString();
    role = Role.tenant;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRole, 'tenant');
    await p.setString(_kTenantSlug, slug);
    await p.setString(_kTenantKey, key);
    notifyListeners();
  }

  Future<void> logout() async {
    role = Role.none;
    _adminKey = '';
    _tenantKey = '';
    tenantSlug = '';
    tenantId = null;
    tenantBaseUrl = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kRole);
    await p.remove(_kAdminKey);
    await p.remove(_kTenantKey);
    await p.remove(_kTenantSlug);
    notifyListeners();
  }
}
