import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../models.dart';
import '../../session.dart';
import '../../theme.dart';
import '../../widgets.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});
  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  late Future<List<Tenant>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Tenant>> _load() {
    final s = context.read<Session>();
    return s.api.listTenants(s.adminKey);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your admin key to sign back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && mounted) context.read<Session>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Businesses'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Ui.indigo,
        foregroundColor: Colors.white,
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add business', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 6),
        child: PoweredByBar(),
      ),
      body: RefreshIndicator(
        color: Ui.indigo,
        onRefresh: _refresh,
        child: FutureBuilder<List<Tenant>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView(label: 'Loading businesses…');
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 120),
                InfoState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load',
                  subtitle: '${snap.error}',
                  action: OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                ),
              ]);
            }
            final tenants = snap.data ?? [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _OwnerCard(user: s.ownerUser, count: tenants.length),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Tenants', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (tenants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: InfoState(
                      icon: Icons.storefront_rounded,
                      title: 'No businesses yet',
                      subtitle: 'Tap “Add business” to onboard your first tenant\nwith a username and password.',
                    ),
                  )
                else
                  ...tenants.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TenantCard(
                          tenant: e.value,
                          onTap: () => _openManageSheet(e.value),
                        ).animate().fadeIn(delay: (40 * e.key).ms).moveY(begin: 8, end: 0),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── add a business ──────────────────────────────────────────────────────
  Future<void> _openAddSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Ui.surface,
      builder: (_) => const _TenantFormSheet(),
    );
    if (created == true) _refresh();
  }

  // ── manage an existing business ─────────────────────────────────────────
  Future<void> _openManageSheet(Tenant t) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Ui.surface,
      builder: (_) => _TenantFormSheet(existing: t),
    );
    if (changed == true) _refresh();
  }
}

class _OwnerCard extends StatelessWidget {
  final String user;
  final int count;
  const _OwnerCard({required this.user, required this.count});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Ui.indigo, Ui.indigoDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.shield_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Platform owner',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(user,
                      style: GoogleFonts.spaceGrotesk(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Column(
              children: [
                Text('$count',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                Text(count == 1 ? 'tenant' : 'tenants',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5)),
              ],
            ),
          ],
        ),
      );
}

class _TenantCard extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onTap;
  const _TenantCard({required this.tenant, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: Ui.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenant.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: Ui.ink)),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (tenant.id != null) ...[
                        Text('ID ${tenant.id}', style: const TextStyle(color: Ui.muted, fontSize: 12)),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: tenant.hasPassword ? Ui.successBg : Ui.warnBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tenant.hasPassword ? 'Password set' : 'No password',
                          style: TextStyle(
                              color: tenant.hasPassword ? Ui.success : Ui.warn,
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Ui.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add a new business or manage an existing one (reset password, set website).
class _TenantFormSheet extends StatefulWidget {
  final Tenant? existing;
  const _TenantFormSheet({this.existing});
  @override
  State<_TenantFormSheet> createState() => _TenantFormSheetState();
}

class _TenantFormSheetState extends State<_TenantFormSheet> {
  late final _slug = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.baseUrl ?? '');
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _err;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _slug.dispose();
    _url.dispose();
    _pass.dispose();
    super.dispose();
  }

  static final _slugRe = RegExp(r'^[a-z][a-z0-9-]{0,62}$');

  Future<void> _delete() async {
    final name = widget.existing!.name;
    final s = context.read<Session>(); // capture before any async gap
    final confirmCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Delete this business?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This permanently deletes “$name” and ALL its data — menu, '
                  'carts, orders and payments. This cannot be undone.',
                  style: const TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              Text('Type “$name” to confirm:',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: confirmCtl,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'business username'),
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Ui.danger),
              onPressed: confirmCtl.text.trim() == name ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Delete forever'),
            ),
          ],
        ),
      ),
    );
    confirmCtl.dispose();
    if (ok != true) return;
    setState(() { _busy = true; _err = null; });
    try {
      await s.api.deleteTenant(s.adminKey, name);
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, 'Deleted “$name”');
    } on ApiException catch (e) {
      setState(() { _busy = false; _err = e.detail; });
    } catch (_) {
      setState(() { _busy = false; _err = 'Network error — try again'; });
    }
  }

  Future<void> _save() async {
    final slug = _slug.text.trim().toLowerCase();
    final pass = _pass.text;
    if (!_slugRe.hasMatch(slug)) {
      setState(() => _err = 'Username must be a lowercase slug, e.g. brahmana-naivedyam');
      return;
    }
    if (!_isEdit && pass.isEmpty) {
      setState(() => _err = 'Set a password for the new business');
      return;
    }
    setState(() { _busy = true; _err = null; });
    final s = context.read<Session>();
    try {
      await s.api.upsertTenant(
        s.adminKey,
        name: slug,
        password: pass.isEmpty ? null : pass,
        baseUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, _isEdit ? 'Business updated' : 'Business “$slug” created');
    } on ApiException catch (e) {
      setState(() => _err = e.detail);
    } catch (_) {
      setState(() => _err = 'Network error — try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            Text(_isEdit ? 'Manage ${widget.existing!.name}' : 'Add a business',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              _isEdit
                  ? 'Reset the password or update the website. Usernames can’t be changed.'
                  : 'Pick a username (slug) and a password. The business signs in with these.',
              style: const TextStyle(color: Ui.muted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 18),
            const _Lbl('Business username'),
            TextField(
              controller: _slug,
              enabled: !_isEdit,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'brahmana-naivedyam'),
            ),
            const SizedBox(height: 14),
            _Lbl(_isEdit ? 'New password' : 'Password'),
            TextField(
              controller: _pass,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: _isEdit ? 'Leave blank to keep current' : 'Choose a strong password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Ui.muted, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_isEdit && widget.existing!.hasPassword)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 2),
                child: Text('A password is already set — passwords can be reset but never viewed.',
                    style: TextStyle(color: Ui.muted, fontSize: 11.5)),
              ),
            const SizedBox(height: 14),
            const _Lbl('Website URL (optional)'),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'https://your-store.vercel.app'),
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.error_outline, color: Ui.danger, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_err!, style: const TextStyle(color: Ui.danger, fontSize: 13))),
              ]),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_isEdit ? 'Save changes' : 'Create business'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Danger zone',
                  style: TextStyle(color: Ui.danger, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_forever_rounded, color: Ui.danger, size: 20),
                label: const Text('Delete this business', style: TextStyle(color: Ui.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Ui.dangerBg),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  final String text;
  const _Lbl(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Ui.inkSoft)),
      );
}
