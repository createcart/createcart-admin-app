import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../session.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'orders_screen.dart';
import 'menu_admin_screen.dart';

class TenantShell extends StatefulWidget {
  const TenantShell({super.key});
  @override
  State<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends State<TenantShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [OrdersScreen(), MenuAdminScreen(), _AccountTab()];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PoweredByBar(),
          NavigationBar(
            selectedIndex: _index,
            height: 64,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Orders'),
              NavigationDestination(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  selectedIcon: Icon(Icons.restaurant_menu_rounded),
                  label: 'Menu'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Account'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your username and password to sign back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && context.mounted) context.read<Session>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Ui.indigo, Ui.indigoDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.tenantSlug,
                          style: GoogleFonts.spaceGrotesk(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Business admin',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _row(Icons.badge_outlined, 'Username', s.tenantSlug),
                if (s.tenantId != null) ...[
                  const Divider(),
                  _row(Icons.tag_rounded, 'Tenant ID', '${s.tenantId}'),
                ],
                if (s.tenantBaseUrl != null && s.tenantBaseUrl!.isNotEmpty) ...[
                  const Divider(),
                  _row(Icons.language_rounded, 'Website', s.tenantBaseUrl!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded, color: Ui.danger),
            label: const Text('Sign out', style: TextStyle(color: Ui.danger)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Ui.danger,
              side: const BorderSide(color: Ui.dangerBg),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(AppConfig.poweredBy,
                style: GoogleFonts.spaceGrotesk(
                    color: Ui.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Ui.muted, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Ui.muted, fontSize: 13.5)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Ui.ink)),
            ),
          ],
        ),
      );
}
