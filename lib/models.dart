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
  final int? weightG;
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
    this.weightG,
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
        weightG: j['weight_g'] == null ? null : _toInt(j['weight_g']),
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
  final String? pincode;
  final double? lat;
  final double? lng;

  OrderCustomer(
      {required this.name, this.phone, this.address, this.email, this.pincode, this.lat, this.lng});

  factory OrderCustomer.fromJson(Map<String, dynamic> j) => OrderCustomer(
        name: (j['name'] ?? '').toString(),
        phone: j['phone']?.toString(),
        address: j['address']?.toString(),
        email: j['email']?.toString(),
        pincode: j['pincode']?.toString(),
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
  final Map<String, dynamic> metadata;

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
    this.metadata = const {},
  });

  int get itemCount => items.fold(0, (s, l) => s + l.quantity);
  bool get isTerminal => status == 'delivered' || status == 'cancelled';

  /// Set once the order has been manifested with a courier (see /ship).
  String? get waybill => metadata['waybill']?.toString();
  String? get courierStatus => metadata['courier_status']?.toString();
  bool get isShipped => waybill != null;

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
        metadata: j['metadata'] is Map ? (j['metadata'] as Map).cast<String, dynamic>() : const {},
      );
}

/// A courier's view of one order: a waybill (AWB) plus its current status.
class Shipment {
  final String waybill;
  final String status;
  final String? rawStatus;
  final String? trackingUrl;
  final String? remarks;

  Shipment(
      {required this.waybill, required this.status, this.rawStatus, this.trackingUrl, this.remarks});

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
        waybill: (j['waybill'] ?? '').toString(),
        status: (j['status'] ?? 'unknown').toString(),
        rawStatus: j['raw_status']?.toString(),
        trackingUrl: j['tracking_url']?.toString(),
        remarks: j['remarks']?.toString(),
      );
}

/// Response from POST .../ship — the new shipment plus the updated order.
class ShipResult {
  final Shipment shipment;
  final Order order;
  ShipResult({required this.shipment, required this.order});

  factory ShipResult.fromJson(Map<String, dynamic> j) => ShipResult(
        shipment: Shipment.fromJson((j['shipment'] as Map).cast<String, dynamic>()),
        order: Order.fromJson((j['order'] as Map).cast<String, dynamic>()),
      );
}

/// One set of shipping/pickup fields — used both for a tenant's own raw
/// overrides (any field may be null = "not set, inherit the platform
/// default") and for the merged "effective" values actually used to quote
/// and ship.
class ShippingSettings {
  final String? originPin;
  final String? originCity;
  final String? originState;
  final String? originAddress;
  final String? originPhone;
  final String? pickupLocation;
  final String? sellerName;
  final String? sellerGstTin;
  final String? hsnCode;
  final int? defaultWeightG;
  final double? handlingFee;

  ShippingSettings({
    this.originPin,
    this.originCity,
    this.originState,
    this.originAddress,
    this.originPhone,
    this.pickupLocation,
    this.sellerName,
    this.sellerGstTin,
    this.hsnCode,
    this.defaultWeightG,
    this.handlingFee,
  });

  factory ShippingSettings.fromJson(Map<String, dynamic> j) => ShippingSettings(
        originPin: j['origin_pin']?.toString(),
        originCity: j['origin_city']?.toString(),
        originState: j['origin_state']?.toString(),
        originAddress: j['origin_address']?.toString(),
        originPhone: j['origin_phone']?.toString(),
        pickupLocation: j['pickup_location']?.toString(),
        sellerName: j['seller_name']?.toString(),
        sellerGstTin: j['seller_gst_tin']?.toString(),
        hsnCode: j['hsn_code']?.toString(),
        defaultWeightG: j['default_weight_g'] == null ? null : _toInt(j['default_weight_g']),
        handlingFee: j['handling_fee'] == null ? null : _toDouble(j['handling_fee']),
      );
}

/// Response from GET/PATCH .../shipping/settings: the tenant's own raw
/// overrides ([own], blanks allowed) plus what's actually applied ([effective]).
class TenantShippingSettings {
  final ShippingSettings own;
  final ShippingSettings effective;
  TenantShippingSettings({required this.own, required this.effective});

  factory TenantShippingSettings.fromJson(Map<String, dynamic> j) => TenantShippingSettings(
        own: ShippingSettings.fromJson((j['settings'] as Map).cast<String, dynamic>()),
        effective: ShippingSettings.fromJson((j['effective'] as Map).cast<String, dynamic>()),
      );
}

class PickupResult {
  final bool ok;
  final String? pickupId;
  final String? remarks;
  PickupResult({required this.ok, this.pickupId, this.remarks});

  factory PickupResult.fromJson(Map<String, dynamic> j) => PickupResult(
        ok: j['ok'] == true,
        pickupId: j['pickup_id']?.toString(),
        remarks: j['remarks']?.toString(),
      );
}
