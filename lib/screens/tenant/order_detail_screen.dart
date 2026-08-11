import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api.dart';
import '../../models.dart';
import '../../session.dart';
import '../../theme.dart';
import '../../widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Order initial;
  const OrderDetailScreen({super.key, required this.orderId, required this.initial});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order = widget.initial;
  bool _busy = false;
  bool _changed = false;
  Shipment? _tracked; // latest courier status pulled via "Refresh tracking"

  Session get _s => context.read<Session>();

  Future<void> _run(Future<Order> Function() op, String okMsg) async {
    setState(() => _busy = true);
    try {
      final updated = await op();
      if (!mounted) return;
      setState(() { _order = updated; _changed = true; });
      toast(context, okMsg);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.detail);
    } catch (_) {
      if (mounted) toast(context, 'Network error — try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _accept() =>
      _run(() => _s.api.setOrderStatus(_s.tenantSlug, _s.tenantKey, _order.id, 'confirmed'),
          'Order accepted');

  void _prepare() =>
      _run(() => _s.api.setOrderStatus(_s.tenantSlug, _s.tenantKey, _order.id, 'preparing'),
          'Marked as preparing');

  void _delivered() =>
      _run(() => _s.api.setOrderStatus(_s.tenantSlug, _s.tenantKey, _order.id, 'delivered'),
          'Order delivered 🎉');

  Future<void> _cancel() async {
    final reason = await _askText(
      title: 'Cancel this order?',
      hint: 'Reason (optional)',
      confirm: 'Cancel order',
      danger: true,
    );
    if (reason == null) return; // dismissed
    _run(() => _s.api.cancelOrder(_s.tenantSlug, _s.tenantKey, _order.id, reason: reason.isEmpty ? null : reason),
        'Order cancelled');
  }

  /// Assign a delivery partner. If the order is still in the kitchen, dispatch
  /// it (→ out_for_delivery) right after.
  Future<void> _assignCourier({required bool dispatch}) async {
    final res = await showModalBottomSheet<_CourierData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Ui.surface,
      builder: (_) => _CourierSheet(existing: _order.courier, dispatch: dispatch),
    );
    if (res == null) return;
    await _run(() async {
      var o = await _s.api.assignCourier(_s.tenantSlug, _s.tenantKey, _order.id,
          name: res.name, phone: res.phone);
      if (dispatch && o.status == 'preparing') {
        o = await _s.api.setOrderStatus(_s.tenantSlug, _s.tenantKey, _order.id, 'out_for_delivery');
      }
      return o;
    }, dispatch ? 'Out for delivery' : 'Delivery partner updated');
  }

  /// Manifest a real Delhivery shipment and dispatch — a one-tap alternative to
  /// manually typing a delivery partner's name/phone.
  Future<void> _shipViaDelhivery() async {
    await _run(() async {
      final result = await _s.api.shipOrder(_s.tenantSlug, _s.tenantKey, _order.id);
      var o = result.order;
      if (o.status == 'preparing') {
        o = await _s.api.setOrderStatus(_s.tenantSlug, _s.tenantKey, _order.id, 'out_for_delivery');
      }
      return o;
    }, 'Shipped via Delhivery — out for delivery');
  }

  Future<void> _refreshTracking() async {
    setState(() => _busy = true);
    try {
      final shipment = await _s.api.refreshTracking(_s.tenantSlug, _s.tenantKey, _order.id);
      if (mounted) setState(() => _tracked = shipment);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.detail);
    } catch (_) {
      if (mounted) toast(context, 'Network error — try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTrackingLink() async {
    final url = _order.courier?.trackingUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    required String confirm,
    bool danger = false,
  }) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, decoration: InputDecoration(hintText: hint), maxLines: 2, minLines: 1),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Ui.danger) : null,
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _dial(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap() async {
    final c = _order.customer;
    if (c == null) return;
    Uri? uri;
    if (c.lat != null && c.lng != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${c.lat},${c.lng}');
    } else if (c.address != null && c.address!.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(c.address!)}');
    }
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final shortId = o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context, _changed)),
          title: Text('Order #$shortId'),
        ),
        bottomNavigationBar: _ActionBar(
          status: o.status,
          busy: _busy,
          hasCourier: o.courier != null,
          canShipDelhivery: o.customer?.pincode != null && o.customer!.pincode!.isNotEmpty && !o.isShipped,
          onAccept: _accept,
          onPrepare: _prepare,
          onDispatch: () => _assignCourier(dispatch: true),
          onShipDelhivery: _shipViaDelhivery,
          onDelivered: _delivered,
          onCancel: _cancel,
          onUpdateCourier: () => _assignCourier(dispatch: false),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            // status banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusMeta(o.status).bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(statusMeta(o.status).icon, color: statusMeta(o.status).fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current status',
                            style: TextStyle(color: statusMeta(o.status).fg.withValues(alpha: 0.8), fontSize: 12)),
                        Text(statusMeta(o.status).label,
                            style: TextStyle(
                                color: statusMeta(o.status).fg, fontWeight: FontWeight.w800, fontSize: 17)),
                      ],
                    ),
                  ),
                  if (o.amount != null)
                    Text(rupees(o.amount!),
                        style: TextStyle(
                            color: statusMeta(o.status).fg, fontWeight: FontWeight.w800, fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // customer
            _SectionCard(
              title: 'Customer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(Icons.person_rounded, o.customer?.name ?? '—'),
                  if (o.customer?.phone != null && o.customer!.phone!.isNotEmpty)
                    _kvAction(Icons.call_rounded, o.customer!.phone!, 'Call', () => _dial(o.customer!.phone)),
                  if (o.customer?.address != null && o.customer!.address!.isNotEmpty)
                    _kvAction(Icons.location_on_rounded, o.customer!.address!, 'Map', _openMap),
                  if (o.customer?.email != null && o.customer!.email!.isNotEmpty)
                    _kv(Icons.mail_outline_rounded, o.customer!.email!),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // items
            _SectionCard(
              title: 'Items (${o.itemCount})',
              child: Column(
                children: [
                  for (final l in o.items) _itemRow(l),
                  if (o.amount != null) ...[
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(rupees(o.amount!),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Ui.indigo)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // courier
            if (o.courier != null)
              _SectionCard(
                title: 'Delivery partner',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv(Icons.delivery_dining_rounded, o.courier!.name),
                    if (o.courier!.phone != null && o.courier!.phone!.isNotEmpty)
                      _kvAction(Icons.call_rounded, o.courier!.phone!, 'Call', () => _dial(o.courier!.phone)),
                  ],
                ),
              ),
            if (o.courier != null) const SizedBox(height: 14),

            // courier shipment (waybill + live tracking)
            if (o.isShipped)
              _SectionCard(
                title: 'Shipment',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv(Icons.qr_code_2_rounded, 'Waybill ${o.waybill}'),
                    _kv(Icons.local_shipping_rounded,
                        _tracked?.rawStatus ?? o.courierStatus ?? 'Manifested'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (o.courier?.trackingUrl != null && o.courier!.trackingUrl!.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openTrackingLink,
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text('Track'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _refreshTracking,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Refresh'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (o.isShipped) const SizedBox(height: 14),

            // timeline
            _SectionCard(
              title: 'Timeline',
              child: Column(
                children: [
                  for (int i = 0; i < o.timeline.length; i++)
                    _timelineRow(o.timeline[i], last: i == o.timeline.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(IconData icon, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Ui.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14.5, color: Ui.ink))),
          ],
        ),
      );

  Widget _kvAction(IconData icon, String value, String action, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Ui.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14.5, color: Ui.ink))),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _itemRow(OrderLine l) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
              child: Text('${l.quantity}×',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Ui.indigo, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(l.name, style: const TextStyle(fontSize: 14.5, color: Ui.ink))),
            Text(rupees(l.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700, color: Ui.inkSoft)),
          ],
        ),
      );

  Widget _timelineRow(StatusEvent e, {required bool last}) {
    final m = statusMeta(e.status);
    final when = e.at != null ? DateFormat('d MMM, h:mm a').format(e.at!) : '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: m.fg, shape: BoxShape.circle)),
              if (!last) Expanded(child: Container(width: 2, color: Ui.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700, color: Ui.ink, fontSize: 14)),
                  if (when.isNotEmpty)
                    Text(when, style: const TextStyle(color: Ui.muted, fontSize: 12)),
                  if (e.note != null && e.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(e.note!, style: const TextStyle(color: Ui.inkSoft, fontSize: 12.5)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      color: Ui.muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );
}

/// Sticky action bar that adapts to the order's current status.
class _ActionBar extends StatelessWidget {
  final String status;
  final bool busy;
  final bool hasCourier;
  final bool canShipDelhivery;
  final VoidCallback onAccept, onPrepare, onDispatch, onShipDelhivery, onDelivered, onCancel, onUpdateCourier;
  const _ActionBar({
    required this.status,
    required this.busy,
    required this.hasCourier,
    required this.canShipDelhivery,
    required this.onAccept,
    required this.onPrepare,
    required this.onDispatch,
    required this.onShipDelhivery,
    required this.onDelivered,
    required this.onCancel,
    required this.onUpdateCourier,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'delivered' || status == 'cancelled') {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: statusMeta(status).bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            status == 'delivered' ? 'This order was delivered.' : 'This order was cancelled.',
            style: TextStyle(color: statusMeta(status).fg, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    // primary action per status
    late final String primaryLabel;
    late final IconData primaryIcon;
    late final VoidCallback primary;
    switch (status) {
      case 'placed':
        primaryLabel = 'Accept order';
        primaryIcon = Icons.check_circle_rounded;
        primary = onAccept;
        break;
      case 'confirmed':
        primaryLabel = 'Start preparing';
        primaryIcon = Icons.restaurant_rounded;
        primary = onPrepare;
        break;
      case 'preparing':
        primaryLabel = 'Assign partner & dispatch';
        primaryIcon = Icons.delivery_dining_rounded;
        primary = onDispatch;
        break;
      case 'out_for_delivery':
        primaryLabel = 'Mark delivered';
        primaryIcon = Icons.task_alt_rounded;
        primary = onDelivered;
        break;
      default:
        primaryLabel = 'Advance';
        primaryIcon = Icons.arrow_forward_rounded;
        primary = onAccept;
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : primary,
              icon: busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Icon(primaryIcon),
              label: Text(busy ? 'Working…' : primaryLabel),
            ),
          ),
          if (status == 'preparing' && canShipDelhivery) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onShipDelhivery,
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Ship via Delhivery'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18, color: Ui.danger),
                  label: const Text('Cancel', style: TextStyle(color: Ui.danger)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Ui.dangerBg)),
                ),
              ),
              if (status == 'out_for_delivery') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onUpdateCourier,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(hasCourier ? 'Edit partner' : 'Add partner'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CourierData {
  final String name;
  final String? phone;
  _CourierData(this.name, this.phone);
}

class _CourierSheet extends StatefulWidget {
  final Courier? existing;
  final bool dispatch;
  const _CourierSheet({this.existing, required this.dispatch});
  @override
  State<_CourierSheet> createState() => _CourierSheetState();
}

class _CourierSheetState extends State<_CourierSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.dispatch ? 'Assign delivery partner' : 'Update delivery partner',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Who is taking this order to the customer?',
                style: TextStyle(color: Ui.muted, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'Partner name')),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Partner phone (optional)'),
            ),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!, style: const TextStyle(color: Ui.danger, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                if (_name.text.trim().isEmpty) {
                  setState(() => _err = 'Enter the partner name');
                  return;
                }
                Navigator.pop(context, _CourierData(_name.text.trim(), _phone.text.trim()));
              },
              icon: Icon(widget.dispatch ? Icons.delivery_dining_rounded : Icons.save_rounded),
              label: Text(widget.dispatch ? 'Dispatch order' : 'Save partner'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            ),
          ],
        ),
      ),
    );
  }
}
