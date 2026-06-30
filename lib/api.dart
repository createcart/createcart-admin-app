import 'dart:convert';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String detail;
  ApiException(this.status, this.detail);
  @override
  String toString() => detail;
}

/// REST client for createcart-api admin surfaces.
///
///  • Platform owner calls authenticate with `X-Admin-Key` (the admin key).
///  • A tenant's own admin calls authenticate with `X-Tenant-Key` (the
///    business password). Reads (menu/categories) are public; writes are gated.
class AdminApi {
  final String base;
  AdminApi({this.base = AppConfig.apiBase});

  Uri _u(String path) => Uri.parse('$base$path');

  // Always fetch fresh — never serve a cached menu/order anywhere.
  static const _noCache = {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'};

  Map<String, String> _admin(String key) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Admin-Key': key,
        ..._noCache,
      };

  Map<String, String> _tenant(String key) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Tenant-Key': key,
        ..._noCache,
      };

  Map<String, String> get _read => {'Accept': 'application/json', ..._noCache};

  dynamic _handle(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.body.isEmpty ? null : jsonDecode(r.body);
    }
    String detail = r.reasonPhrase ?? 'Request failed';
    try {
      final j = jsonDecode(r.body);
      if (j is Map && j['detail'] != null) detail = j['detail'].toString();
    } catch (_) {}
    throw ApiException(r.statusCode, detail);
  }

  // ══════════════════════════ platform (owner) ══════════════════════════

  /// Validate the platform admin key. Returns true on 200.
  Future<bool> platformLogin(String adminKey) async {
    final r = await http.get(_u('/api/_tenants'), headers: _admin(adminKey));
    if (r.statusCode == 200) return true;
    if (r.statusCode == 401) return false;
    _handle(r); // surfaces other errors (network/5xx)
    return false;
  }

  Future<List<Tenant>> listTenants(String adminKey) async {
    final data = await _handle(
        await http.get(_u('/api/_tenants'), headers: _admin(adminKey))) as List;
    return data
        .map((e) => Tenant.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Tenant> getTenant(String adminKey, String name) async {
    final data = await _handle(
        await http.get(_u('/api/_tenants/$name'), headers: _admin(adminKey)));
    return Tenant.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Onboard a new business or update an existing one (idempotent upsert).
  /// Setting [password] (re)sets the login password; [baseUrl] sets the website.
  Future<Tenant> upsertTenant(
    String adminKey, {
    required String name,
    String? password,
    String? baseUrl,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (baseUrl != null && baseUrl.isNotEmpty) body['base_url'] = baseUrl;
    final data = await _handle(await http.post(_u('/api/_tenants'),
        headers: _admin(adminKey), body: jsonEncode(body)));
    return Tenant.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Off-board a tenant: deletes the tenant and DROPs all its data. Irreversible.
  Future<void> deleteTenant(String adminKey, String name) async {
    _handle(await http.delete(_u('/api/_tenants/$name'), headers: _admin(adminKey)));
  }

  // ══════════════════════════ tenant auth ══════════════════════════

  /// Validate a tenant slug + password. Returns the identity map on success.
  Future<Map<String, dynamic>> tenantLogin(String tenant, String key) async {
    final data = await _handle(await http.get(
        _u('/api/$tenant/admin/me'), headers: _tenant(key)));
    return (data as Map).cast<String, dynamic>();
  }

  // ══════════════════════════ menu (tenant) ══════════════════════════

  Future<List<MenuItem>> listItems(String tenant) async {
    final data = await _handle(await http.get(_u('/api/$tenant/items'),
        headers: _read)) as List;
    final items = data
        .map((e) => MenuItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<List<Category>> listCategories(String tenant) async {
    final data = await _handle(await http.get(_u('/api/$tenant/categories'),
        headers: _read)) as List;
    return data
        .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<MenuItem> createItem(String tenant, String key, Map<String, dynamic> body) async {
    final data = await _handle(await http.post(_u('/api/$tenant/items'),
        headers: _tenant(key), body: jsonEncode(body)));
    return MenuItem.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MenuItem> updateItem(
      String tenant, String key, String id, Map<String, dynamic> fields) async {
    final data = await _handle(await http.patch(_u('/api/$tenant/items/$id'),
        headers: _tenant(key), body: jsonEncode(fields)));
    return MenuItem.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> deleteItem(String tenant, String key, String id) async {
    _handle(await http.delete(_u('/api/$tenant/items/$id'), headers: _tenant(key)));
  }

  /// Wipe the entire menu (all items + combos). Returns how many items were removed.
  Future<int> clearMenu(String tenant, String key) async {
    final data = await _handle(await http.delete(_u('/api/$tenant/items'), headers: _tenant(key)));
    if (data is Map && data['removed'] != null) {
      return int.tryParse('${data['removed']}') ?? 0;
    }
    return 0;
  }

  Future<MenuItem> setAvailability(
      String tenant, String key, String id, bool available) async {
    final data = await _handle(await http.post(
        _u('/api/$tenant/items/$id/availability'),
        headers: _tenant(key),
        body: jsonEncode({'available': available})));
    return MenuItem.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MenuItem> setPrice(String tenant, String key, String id, num price) async {
    final data = await _handle(await http.post(_u('/api/$tenant/items/$id/price'),
        headers: _tenant(key), body: jsonEncode({'price': price})));
    return MenuItem.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MenuItem> setStock(String tenant, String key, String id, int? stock) async {
    final data = await _handle(await http.post(_u('/api/$tenant/items/$id/stock/set'),
        headers: _tenant(key), body: jsonEncode({'stock': stock})));
    return MenuItem.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Category> createCategory(String tenant, String key, String name) async {
    final data = await _handle(await http.post(_u('/api/$tenant/categories'),
        headers: _tenant(key), body: jsonEncode({'name': name})));
    return Category.fromJson((data as Map).cast<String, dynamic>());
  }

  // ══════════════════════════ orders / delivery (tenant) ══════════════════════════

  Future<List<Order>> listOrders(String tenant, String key, {String? status}) async {
    final path = status == null || status.isEmpty
        ? '/api/$tenant/deliveries'
        : '/api/$tenant/deliveries?status=$status';
    final data = await _handle(
        await http.get(_u(path), headers: _tenant(key))) as List;
    return data
        .map((e) => Order.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Order> advanceOrder(String tenant, String key, String id, {String? note}) async {
    final data = await _handle(await http.post(
        _u('/api/$tenant/deliveries/$id/advance'),
        headers: _tenant(key),
        body: jsonEncode({if (note != null) 'note': note})));
    return Order.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Order> setOrderStatus(
      String tenant, String key, String id, String status, {String? note}) async {
    final data = await _handle(await http.post(
        _u('/api/$tenant/deliveries/$id/status'),
        headers: _tenant(key),
        body: jsonEncode({'status': status, if (note != null) 'note': note})));
    return Order.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Order> cancelOrder(String tenant, String key, String id, {String? reason}) async {
    final data = await _handle(await http.post(
        _u('/api/$tenant/deliveries/$id/cancel'),
        headers: _tenant(key),
        body: jsonEncode({if (reason != null) 'reason': reason})));
    return Order.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Order> assignCourier(
    String tenant,
    String key,
    String id, {
    required String name,
    String? phone,
    String? trackingUrl,
  }) async {
    final data = await _handle(await http.post(
        _u('/api/$tenant/deliveries/$id/courier'),
        headers: _tenant(key),
        body: jsonEncode({
          'name': name,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (trackingUrl != null && trackingUrl.isNotEmpty) 'tracking_url': trackingUrl,
        })));
    return Order.fromJson((data as Map).cast<String, dynamic>());
  }
}
