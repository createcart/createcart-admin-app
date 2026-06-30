import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../models.dart';
import '../../session.dart';
import '../../theme.dart';
import '../../widgets.dart';

class MenuAdminScreen extends StatefulWidget {
  const MenuAdminScreen({super.key});
  @override
  State<MenuAdminScreen> createState() => _MenuAdminScreenState();
}

class _MenuAdminScreenState extends State<MenuAdminScreen> {
  List<MenuItem> _items = [];
  List<Category> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _query = '';
  String? _catFilter;

  /// Staged availability edits: itemId -> desired availability. Toggling a
  /// switch only changes this map (no network). Nothing hits the server until
  /// the user taps Save, after which we re-query so the screen shows the truth.
  final Map<String, bool> _draft = {};

  Session get _s => context.read<Session>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _s.api.listItems(_s.tenantSlug);
      List<Category> cats = [];
      try {
        cats = await _s.api.listCategories(_s.tenantSlug);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _categories = cats;
        _draft.clear(); // fresh truth from the server wins
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.detail; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Network error'; _loading = false; });
    }
  }

  List<String> get _catNames {
    final s = <String>{..._categories.map((c) => c.name)};
    for (final i in _items) {
      if (i.category != null && i.category!.isNotEmpty) s.add(i.category!);
    }
    return s.toList()..sort();
  }

  /// Effective availability for display = staged value if any, else server value.
  bool _effectiveAvailable(MenuItem i) => _draft[i.id] ?? i.available;

  bool _isDirty(MenuItem i) => _draft.containsKey(i.id) && _draft[i.id] != i.available;

  List<MenuItem> get _dirtyItems => _items.where(_isDirty).toList();

  List<MenuItem> get _filtered {
    return _items.where((i) {
      if (_catFilter != null && i.category != _catFilter) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return i.name.toLowerCase().contains(q) ||
            (i.nameLocalized ?? '').toLowerCase().contains(q) ||
            (i.category ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void _stageToggle(MenuItem item, bool value) {
    setState(() {
      if (value == item.available) {
        _draft.remove(item.id); // back to original -> no longer dirty
      } else {
        _draft[item.id] = value;
      }
    });
  }

  void _discard() => setState(() => _draft.clear());

  /// Apply staged availability changes one-by-one (sequential, never parallel —
  /// the API rewrites the whole catalog on each write, so overlapping writes
  /// could clobber each other). Then re-query to display the real state.
  Future<void> _save() async {
    final pending = _dirtyItems;
    if (pending.isEmpty) return;
    setState(() => _saving = true);
    final failures = <String>[];
    for (final item in pending) {
      try {
        await _s.api.setAvailability(_s.tenantSlug, _s.tenantKey, item.id, _draft[item.id]!);
      } on ApiException catch (e) {
        failures.add('${item.name}: ${e.detail}');
      } catch (_) {
        failures.add('${item.name}: network error');
      }
    }
    if (!mounted) return;
    await _load(); // re-query: the screen now reflects the server
    if (!mounted) return;
    setState(() => _saving = false);
    if (failures.isEmpty) {
      toast(context, 'Saved ${pending.length} change${pending.length == 1 ? '' : 's'}');
    } else {
      toast(context, 'Some changes failed: ${failures.first}');
    }
  }

  Future<void> _clearMenu() async {
    final confirmCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Delete entire menu?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This removes all ${_items.length} item${_items.length == 1 ? '' : 's'} '
                  '(and combos) from your menu. Categories are kept. This cannot be undone.',
                  style: const TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              const Text('Type DELETE to confirm:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: confirmCtl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'DELETE'),
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Ui.danger),
              onPressed: confirmCtl.text.trim().toUpperCase() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Delete all'),
            ),
          ],
        ),
      ),
    );
    confirmCtl.dispose();
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final n = await _s.api.clearMenu(_s.tenantSlug, _s.tenantKey);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, 'Deleted entire menu ($n item${n == 1 ? '' : 's'})');
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) toast(context, e.detail);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      if (mounted) toast(context, 'Network error — try again');
    }
  }

  Future<void> _openEditor({MenuItem? item}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Ui.surface,
      builder: (_) => _ItemEditor(existing: item, categories: _catNames),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final dirtyCount = _dirtyItems.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          if (dirtyCount == 0) ...[
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
            if (_items.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'clear') _clearMenu();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(children: [
                      Icon(Icons.delete_sweep_rounded, color: Ui.danger, size: 20),
                      SizedBox(width: 10),
                      Text('Delete entire menu', style: TextStyle(color: Ui.danger)),
                    ]),
                  ),
                ],
              ),
          ],
        ],
      ),
      floatingActionButton: dirtyCount > 0
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Ui.indigo,
              foregroundColor: Colors.white,
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      bottomNavigationBar: dirtyCount > 0 ? _SaveBar(
        count: dirtyCount,
        saving: _saving,
        onSave: _save,
        onDiscard: _saving ? null : _discard,
      ) : null,
      body: _loading
          ? const LoadingView(label: 'Loading menu…')
          : _error != null
              ? InfoState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load menu',
                  subtitle: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('Retry')),
                )
              : RefreshIndicator(
                  color: Ui.indigo,
                  onRefresh: _load,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            hintText: 'Search items',
                            prefixIcon: Icon(Icons.search_rounded, color: Ui.muted),
                          ),
                        ),
                      ),
                      if (_catNames.isNotEmpty)
                        SizedBox(
                          height: 42,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _catChip('All', _catFilter == null, () => setState(() => _catFilter = null)),
                              ..._catNames.map((c) =>
                                  _catChip(c, _catFilter == c, () => setState(() => _catFilter = c))),
                            ],
                          ),
                        ),
                      Expanded(
                        child: _filtered.isEmpty
                            ? InfoState(
                                icon: Icons.restaurant_menu_rounded,
                                title: _items.isEmpty ? 'No items yet' : 'No matches',
                                subtitle: _items.isEmpty
                                    ? 'Tap “Add item” to put your first\ndish on the menu.'
                                    : 'Try a different search or category.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final item = _filtered[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ItemCard(
                                      item: item,
                                      available: _effectiveAvailable(item),
                                      dirty: _isDirty(item),
                                      enabled: !_saving,
                                      onToggle: (v) => _stageToggle(item, v),
                                      onTap: _saving ? null : () => _openEditor(item: item),
                                    ).animate().fadeIn(delay: (25 * i).ms).moveY(begin: 6, end: 0),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _catChip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: active,
          showCheckmark: false,
          label: Text(label),
          labelStyle: TextStyle(
              color: active ? Colors.white : Ui.inkSoft, fontWeight: FontWeight.w700, fontSize: 13),
          selectedColor: Ui.indigo,
          backgroundColor: Ui.surface,
          side: BorderSide(color: active ? Ui.indigo : Ui.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          onSelected: (_) => onTap(),
        ),
      );
}

class _SaveBar extends StatelessWidget {
  final int count;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback? onDiscard;
  const _SaveBar({required this.count, required this.saving, required this.onSave, this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ui.surface,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$count unsaved change${count == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Ui.ink, fontSize: 14.5)),
                    const Text('Changes apply only after you save',
                        style: TextStyle(color: Ui.muted, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onDiscard,
                child: const Text('Discard', style: TextStyle(color: Ui.muted, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(saving ? 'Saving…' : 'Save'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final MenuItem item;
  final bool available;
  final bool dirty;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;
  const _ItemCard({
    required this.item,
    required this.available,
    required this.dirty,
    required this.enabled,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sold out if toggled off OR the tracked stock is exhausted.
    final sold = !(available && (item.stock == null || item.stock! > 0));
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dirty ? Ui.indigo : Ui.border, width: dirty ? 1.4 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(item.icon ?? '🍽️', style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(item.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15,
                                  color: sold ? Ui.muted : Ui.ink)),
                        ),
                        if (dirty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(6)),
                            child: const Text('edited', style: TextStyle(color: Ui.indigo, fontSize: 10.5, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(rupees(item.price),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Ui.inkSoft, fontSize: 13.5)),
                        if (item.category != null && item.category!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text('· ${item.category}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Ui.muted, fontSize: 12.5)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(sold ? 'Out of stock' : 'In stock',
                        style: TextStyle(
                            color: sold ? Ui.danger : Ui.success,
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: available,
                activeTrackColor: Ui.success,
                onChanged: enabled ? onToggle : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create or edit a menu item.
class _ItemEditor extends StatefulWidget {
  final MenuItem? existing;
  final List<String> categories;
  const _ItemEditor({this.existing, required this.categories});
  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _localized = TextEditingController(text: widget.existing?.nameLocalized ?? '');
  late final _price = TextEditingController(
      text: widget.existing != null ? widget.existing!.price.toStringAsFixed(0) : '');
  late final _category = TextEditingController(text: widget.existing?.category ?? '');
  late final _icon = TextEditingController(text: widget.existing?.icon ?? '');
  late final _image = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _stock = TextEditingController(
      text: widget.existing?.stock != null ? '${widget.existing!.stock}' : '');
  late bool _available = widget.existing?.available ?? true;
  bool _busy = false;
  String? _err;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _localized, _price, _category, _icon, _image, _desc, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Name is required');
      return;
    }
    final price = double.tryParse(_price.text.trim());
    if (price == null) {
      setState(() => _err = 'Enter a valid price');
      return;
    }
    final stock = _stock.text.trim().isEmpty ? null : int.tryParse(_stock.text.trim());

    setState(() { _busy = true; _err = null; });
    final body = <String, dynamic>{
      'name': name,
      'price': price,
      'name_localized': _localized.text.trim().isEmpty ? null : _localized.text.trim(),
      'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
      'icon': _icon.text.trim().isEmpty ? null : _icon.text.trim(),
      'image_url': _image.text.trim().isEmpty ? null : _image.text.trim(),
      'description': _desc.text.trim(),
      'available': _available,
      'stock': stock,
    };
    try {
      if (_isEdit) {
        await _s.api.updateItem(_s.tenantSlug, _s.tenantKey, widget.existing!.id, body);
      } else {
        await _s.api.createItem(_s.tenantSlug, _s.tenantKey, body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, _isEdit ? 'Item updated' : 'Item added');
    } on ApiException catch (e) {
      setState(() => _err = e.detail);
    } catch (_) {
      setState(() => _err = 'Network error — try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('“${widget.existing!.name}” will be removed from the menu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Ui.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _s.api.deleteItem(_s.tenantSlug, _s.tenantKey, widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, 'Item deleted');
    } on ApiException catch (e) {
      setState(() { _busy = false; _err = e.detail; });
    } catch (_) {
      setState(() { _busy = false; _err = 'Network error — try again'; });
    }
  }

  Session get _s => context.read<Session>();

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
            Row(
              children: [
                Expanded(
                  child: Text(_isEdit ? 'Edit item' : 'Add item',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (_isEdit)
                  IconButton(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Ui.danger),
                    tooltip: 'Delete',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _icon,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(hintText: '🍽️', contentPadding: EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _localized,
              decoration: const InputDecoration(labelText: 'Local name (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(labelText: 'Price ₹', prefixText: '₹ '),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Stock (blank = ∞)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category (optional)'),
            ),
            if (widget.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.categories
                      .map((c) => ActionChip(
                            label: Text(c, style: const TextStyle(fontSize: 12.5)),
                            backgroundColor: Ui.fieldFill,
                            side: const BorderSide(color: Ui.border),
                            onPressed: () => setState(() => _category.text = c),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _image,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Image URL (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Ui.fieldFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Ui.border),
              ),
              child: SwitchListTile(
                value: _available,
                activeTrackColor: Ui.success,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                title: const Text('Available to order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text(_available ? 'Shown as in stock' : 'Shown as out of stock',
                    style: const TextStyle(fontSize: 12.5, color: Ui.muted)),
                onChanged: (v) => setState(() => _available = v),
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.error_outline, color: Ui.danger, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_err!, style: const TextStyle(color: Ui.danger, fontSize: 13))),
              ]),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_isEdit ? 'Save changes' : 'Add to menu'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
