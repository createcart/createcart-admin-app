import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../session.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'order_detail_screen.dart';

const _filters = <String?>[null, 'placed', 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'];

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _future;
  String? _filter; // null = all

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Order>> _load() {
    final s = context.read<Session>();
    return s.api.listOrders(s.tenantSlug, s.tenantKey);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        color: Ui.indigo,
        onRefresh: _refresh,
        child: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView(label: 'Loading orders…');
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 120),
                InfoState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load orders',
                  subtitle: '${snap.error}',
                  action: OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                ),
              ]);
            }
            final all = snap.data ?? [];
            final counts = <String, int>{};
            for (final o in all) {
              counts[o.status] = (counts[o.status] ?? 0) + 1;
            }
            final shown = _filter == null ? all : all.where((o) => o.status == _filter).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _SummaryStrip(counts: counts, total: all.length),
                _FilterChips(
                  selected: _filter,
                  counts: counts,
                  total: all.length,
                  onSelect: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 4),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: InfoState(
                      icon: Icons.receipt_long_rounded,
                      title: _filter == null ? 'No orders yet' : 'Nothing here',
                      subtitle: _filter == null
                          ? 'Paid orders from your storefront\nwill show up here in real time.'
                          : 'No ${statusMeta(_filter!).label.toLowerCase()} orders right now.',
                    ),
                  )
                else
                  ...shown.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _OrderCard(
                          order: e.value,
                          onTap: () => _open(e.value),
                        ).animate().fadeIn(delay: (30 * e.key).ms).moveY(begin: 8, end: 0),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(Order o) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id, initial: o)),
    );
    if (changed == true) _refresh();
  }
}

class _SummaryStrip extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  const _SummaryStrip({required this.counts, required this.total});
  @override
  Widget build(BuildContext context) {
    final active = (counts['placed'] ?? 0) + (counts['confirmed'] ?? 0) + (counts['preparing'] ?? 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
                value: '${counts['placed'] ?? 0}', label: 'New', color: Ui.warn, icon: Icons.fiber_new_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
                value: '$active', label: 'In kitchen', color: Ui.indigo, icon: Icons.soup_kitchen_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
                value: '${counts['out_for_delivery'] ?? 0}',
                label: 'On the way', color: const Color(0xFF7C3AED), icon: Icons.delivery_dining_rounded),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String? selected;
  final Map<String, int> counts;
  final int total;
  final ValueChanged<String?> onSelect;
  const _FilterChips(
      {required this.selected, required this.counts, required this.total, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filters.map((f) {
          final label = f == null ? 'All' : statusMeta(f).label;
          final n = f == null ? total : (counts[f] ?? 0);
          final active = selected == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              showCheckmark: false,
              label: Text('$label · $n'),
              labelStyle: TextStyle(
                  color: active ? Colors.white : Ui.inkSoft,
                  fontWeight: FontWeight.w700, fontSize: 13),
              selectedColor: Ui.indigo,
              backgroundColor: Ui.surface,
              side: BorderSide(color: active ? Ui.indigo : Ui.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              onSelected: (_) => onSelect(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shortId = order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id;
    final when = order.createdAt != null ? DateFormat('d MMM, h:mm a').format(order.createdAt!) : '';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('#$shortId',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Ui.ink)),
                  const SizedBox(width: 8),
                  StatusChip(order.status, small: true),
                  const Spacer(),
                  if (order.amount != null)
                    Text(rupees(order.amount!),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Ui.ink)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 15, color: Ui.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(order.customer?.name ?? 'Customer',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Ui.inkSoft, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  Text('${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                      style: const TextStyle(color: Ui.muted, fontSize: 12.5)),
                ],
              ),
              if (when.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Ui.muted),
                  const SizedBox(width: 4),
                  Text(when, style: const TextStyle(color: Ui.muted, fontSize: 12)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
