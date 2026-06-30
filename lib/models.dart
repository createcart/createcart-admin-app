// Data models mirroring the createcart-api JSON shapes (admin views).

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// A business onboarded on the platform. Passwords are stored hashed server-side
/// and are never returned — only [hasPassword] tells whether one is set.
class Tenant {
  final int? id;
  final String name;
  final String? baseUrl;
  final bool hasPassword;

  Tenant({this.id, required this.name, this.baseUrl, this.hasPassword = false});

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
        id: j['id'] == null ? null : _toInt(j['id']),
        name: (j['name'] ?? '').toString(),
        baseUrl: (j['base_url'] == null || '${j['base_url']}'.isEmpty)
            ? null
            : j['base_url'].toString(),
        hasPassword: j['has_password'] == true,
      );
}

class MenuItem {
  final String id;
  final String name;
  final String? nameLocalized;
  final String description;
  final double price;
  final String currency;
  final String? imageUrl;
  final String? icon;
  final String? category;
  final List<String> tags;
  final bool available;
  final int? stock;
  final int sortOrder;

  MenuItem({
    required this.id,
    required this.name,
    this.nameLocalized,
    this.description = '',
    this.price = 0,
    this.currency = 'INR',
    this.imageUrl,
    this.icon,
    this.category,
    this.tags = const [],
    this.available = true,
    this.stock,
    this.sortOrder = 0,
  });

  /// In stock + available to sell.
  bool get sellable => available && (stock == null || stock! > 0);

  /// Out of stock for any reason (toggled off, or stock exhausted).
  bool get soldOut => !sellable;

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        nameLocalized: (j['name_localized'] == null || '${j['name_localized']}'.isEmpty)
            ? null
            : j['name_localized'].toString(),
        description: (j['description'] ?? '').toString(),
        price: _toDouble(j['price']),
        currency: (j['currency'] ?? 'INR').toString(),
        imageUrl: (j['image_url'] == null || '${j['image_url']}'.isEmpty)
            ? null
            : j['image_url'].toString(),
        icon: (j['icon'] == null || '${j['icon']}'.isEmpty) ? null : j['icon'].toString(),
        category: (j['category'] == null || '${j['category']}'.isEmpty)
            ? null
            : j['category'].toString(),
        tags: (j['tags'] is List)
            ? (j['tags'] as List).map((e) => e.toString()).toList()
            : const [],
        available: j['available'] == true || j['available'] == 1,
        stock: j['stock'] == null ? null : _toInt(j['stock']),
        sortOrder: _toInt(j['sort_order']),
      );
}

class Category {
  final String id;
  final String name;
  final int sortOrder;
  Category({required this.id, required this.name, this.sortOrder = 0});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        sortOrder: _toInt(j['sort_order']),
      );
}

class OrderCustomer {
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final double? lat;
  final double? lng;

  OrderCustomer({required this.name, this.phone, this.address, this.email, this.lat, this.lng});

  factory OrderCustomer.fromJson(Map<String, dynamic> j) => OrderCustomer(
        name: (j['name'] ?? '').toString(),
        phone: j['phone']?.toString(),
        address: j['address']?.toString(),
        email: j['email']?.toString(),
        lat: j['lat'] == null ? null : _toDouble(j['lat']),
        lng: j['lng'] == null ? null : _toDouble(j['lng']),
      );
}

class OrderLine {
  final String itemId;
  final String name;
  final int quantity;
  final double unitPrice;
  OrderLine({required this.itemId, required this.name, this.quantity = 1, this.unitPrice = 0});

  double get lineTotal => unitPrice * quantity;

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        itemId: (j['item_id'] ?? j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        quantity: _toInt(j['quantity']),
        unitPrice: _toDouble(j['unit_price']),
      );
}

class Courier {
  final String name;
  final String? phone;
  final String? trackingUrl;
  Courier({required this.name, this.phone, this.trackingUrl});

  factory Courier.fromJson(Map<String, dynamic> j) => Courier(
        name: (j['name'] ?? '').toString(),
        phone: j['phone']?.toString(),
        trackingUrl: j['tracking_url']?.toString(),
      );
}

class StatusEvent {
  final String status;
  final DateTime? at;
  final String? note;
  StatusEvent({required this.status, this.at, this.note});

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        status: (j['status'] ?? '').toString(),
        at: _toDate(j['at']),
        note: j['note']?.toString(),
      );
}

class Order {
  final String id;
  final String status;
  final OrderCustomer? customer;
  final List<OrderLine> items;
  final double? amount;
  final String currency;
  final String? paymentId;
  final List<StatusEvent> timeline;
  final Courier? courier;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.status,
    this.customer,
    this.items = const [],
    this.amount,
    this.currency = 'INR',
    this.paymentId,
    this.timeline = const [],
    this.courier,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  int get itemCount => items.fold(0, (s, l) => s + l.quantity);
  bool get isTerminal => status == 'delivered' || status == 'cancelled';

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'].toString(),
        status: (j['status'] ?? 'placed').toString(),
        customer: j['customer'] is Map
            ? OrderCustomer.fromJson((j['customer'] as Map).cast<String, dynamic>())
            : null,
        items: (j['items'] is List)
            ? (j['items'] as List)
                .map((e) => OrderLine.fromJson((e as Map).cast<String, dynamic>()))
                .toList()
            : const [],
        amount: j['amount'] == null ? null : _toDouble(j['amount']),
        currency: (j['currency'] ?? 'INR').toString(),
        paymentId: j['payment_id']?.toString(),
        timeline: (j['timeline'] is List)
            ? (j['timeline'] as List)
                .map((e) => StatusEvent.fromJson((e as Map).cast<String, dynamic>()))
                .toList()
            : const [],
        courier: j['courier'] is Map
            ? Courier.fromJson((j['courier'] as Map).cast<String, dynamic>())
            : null,
        notes: (j['notes'] ?? '').toString(),
        createdAt: _toDate(j['created_at']),
        updatedAt: _toDate(j['updated_at']),
      );
}
