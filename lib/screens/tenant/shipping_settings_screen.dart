import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../models.dart';
import '../../session.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Pickup address, seller info, default parcel weight and handling fee used
/// to quote and ship this tenant's own orders on Delhivery. Any field left
/// blank falls back to the platform-wide default (shown as a hint).
class ShippingSettingsScreen extends StatefulWidget {
  const ShippingSettingsScreen({super.key});
  @override
  State<ShippingSettingsScreen> createState() => _ShippingSettingsScreenState();
}

class _ShippingSettingsScreenState extends State<ShippingSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  TenantShippingSettings? _data;

  late final _pin = TextEditingController();
  late final _city = TextEditingController();
  late final _state = TextEditingController();
  late final _address = TextEditingController();
  late final _phone = TextEditingController();
  late final _pickupLocation = TextEditingController();
  late final _sellerName = TextEditingController();
  late final _gst = TextEditingController();
  late final _hsn = TextEditingController();
  late final _weight = TextEditingController();
  late final _fee = TextEditingController();

  Session get _s => context.read<Session>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _pin, _city, _state, _address, _phone, _pickupLocation,
      _sellerName, _gst, _hsn, _weight, _fee,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(TenantShippingSettings d) {
    final o = d.own;
    _pin.text = o.originPin ?? '';
    _city.text = o.originCity ?? '';
    _state.text = o.originState ?? '';
    _address.text = o.originAddress ?? '';
    _phone.text = o.originPhone ?? '';
    _pickupLocation.text = o.pickupLocation ?? '';
    _sellerName.text = o.sellerName ?? '';
    _gst.text = o.sellerGstTin ?? '';
    _hsn.text = o.hsnCode ?? '';
    _weight.text = o.defaultWeightG?.toString() ?? '';
    _fee.text = o.handlingFee == null ? '' : _trimZeros(o.handlingFee!);
  }

  String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _s.api.getShippingSettings(_s.tenantSlug, _s.tenantKey);
      if (!mounted) return;
      setState(() { _data = data; _fill(data); _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.detail; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Network error'; _loading = false; });
    }
  }

  /// Blank text -> `null` (clears the override back to the platform default);
  /// non-blank -> the parsed value. Always included, so PATCH's exclude-unset
  /// semantics treat a cleared field as an explicit reset.
  Future<void> _save() async {
    final weight = _weight.text.trim().isEmpty ? null : int.tryParse(_weight.text.trim());
    final fee = _fee.text.trim().isEmpty ? null : double.tryParse(_fee.text.trim());
    if (_weight.text.trim().isNotEmpty && weight == null) {
      setState(() => _error = 'Weight must be a whole number');
      return;
    }
    if (_fee.text.trim().isNotEmpty && fee == null) {
      setState(() => _error = 'Handling fee must be a number');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final body = <String, dynamic>{
      'origin_pin': _pin.text.trim().isEmpty ? null : _pin.text.trim(),
      'origin_city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'origin_state': _state.text.trim().isEmpty ? null : _state.text.trim(),
      'origin_address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'origin_phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'pickup_location': _pickupLocation.text.trim().isEmpty ? null : _pickupLocation.text.trim(),
      'seller_name': _sellerName.text.trim().isEmpty ? null : _sellerName.text.trim(),
      'seller_gst_tin': _gst.text.trim().isEmpty ? null : _gst.text.trim(),
      'hsn_code': _hsn.text.trim().isEmpty ? null : _hsn.text.trim(),
      'default_weight_g': weight,
      'handling_fee': fee,
    };
    try {
      final data = await _s.api.updateShippingSettings(_s.tenantSlug, _s.tenantKey, body);
      if (!mounted) return;
      setState(() { _data = data; _fill(data); _saving = false; });
      toast(context, 'Shipping settings saved');
    } on ApiException catch (e) {
      setState(() { _saving = false; _error = e.detail; });
    } catch (_) {
      setState(() { _saving = false; _error = 'Network error — try again'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping settings'),
        actions: [
          if (!_loading && _error == null)
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const LoadingView(label: 'Loading shipping settings…')
          : _error != null && _data == null
              ? InfoState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load shipping settings',
                  subtitle: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('Retry')),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final eff = _data!.effective;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Ui.infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Ui.info, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Leave a field blank to use the platform default (shown as a hint). '
                    'These control where your Delhivery shipments are picked up from.',
                    style: TextStyle(fontSize: 12.5, color: Ui.inkSoft, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _section('Pickup address'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  decoration: InputDecoration(labelText: 'Pincode', hintText: eff.originPin),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'Phone', hintText: eff.originPhone),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _city,
                  decoration: InputDecoration(labelText: 'City', hintText: eff.originCity),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _state,
                  decoration: InputDecoration(labelText: 'State', hintText: eff.originState),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Full pickup address',
              hintText: eff.originAddress?.isNotEmpty == true ? eff.originAddress : 'Street, area, landmark',
            ),
          ),
          const SizedBox(height: 22),
          _section('Warehouse & seller (for real shipments)'),
          TextField(
            controller: _pickupLocation,
            decoration: InputDecoration(
              labelText: 'Pickup location (warehouse name)',
              hintText: eff.pickupLocation?.isNotEmpty == true
                  ? eff.pickupLocation
                  : 'Exact name registered in Delhivery',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sellerName,
            decoration: InputDecoration(labelText: 'Seller name', hintText: eff.sellerName),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gst,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'GST number (optional)',
                    hintText: eff.sellerGstTin?.isNotEmpty == true ? eff.sellerGstTin : '—',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _hsn,
                  decoration: InputDecoration(
                    labelText: 'HSN code (optional)',
                    hintText: eff.hsnCode?.isNotEmpty == true ? eff.hsnCode : '—',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _section('Parcel weight & fee'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Default weight (g)',
                    hintText: '${eff.defaultWeightG ?? 500}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _fee,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: 'Handling fee ₹',
                    hintText: eff.handlingFee == null ? null : rupees(eff.handlingFee!),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.error_outline, color: Ui.danger, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: const TextStyle(color: Ui.danger, fontSize: 13))),
            ]),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Save shipping settings'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Ui.muted)),
      );
}
