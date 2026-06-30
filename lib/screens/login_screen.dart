import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../config.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _owner = false; // false = business, true = platform owner
  final _user = TextEditingController();
  final _slug = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _err;

  @override
  void dispose() {
    _user.dispose();
    _slug.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _err = null; });
    final s = context.read<Session>();
    try {
      if (_owner) {
        await s.loginPlatform(_user.text.trim(), _pass.text);
      } else {
        final slug = _slug.text.trim().toLowerCase();
        if (slug.isEmpty) throw ApiException(0, 'Enter your business username');
        await s.loginTenant(slug, _pass.text);
      }
      // AuthGate swaps the screen on success.
    } on ApiException catch (e) {
      setState(() => _err = e.status == 401
          ? (_owner ? 'Invalid admin key' : 'Wrong username or password')
          : e.detail);
    } catch (_) {
      setState(() => _err = 'Network error — check your connection');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ui.night,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Center(child: const BrandMark(size: 64).animate().scale(duration: 400.ms, curve: Curves.easeOutBack)),
              const SizedBox(height: 18),
              Text(AppConfig.appName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Run your store from anywhere',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Ui.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoleToggle(
                      owner: _owner,
                      onChanged: (v) => setState(() { _owner = v; _err = null; }),
                    ),
                    const SizedBox(height: 18),
                    if (_owner) ...[
                      _Label('Owner username'),
                      TextField(
                        controller: _user,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(hintText: 'admin'),
                      ),
                      const SizedBox(height: 14),
                      _Label('Admin key'),
                      _passwordField(hint: 'Your platform admin key'),
                    ] else ...[
                      _Label('Business username'),
                      TextField(
                        controller: _slug,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(hintText: 'e.g. brahmana-naivedyam'),
                      ),
                      const SizedBox(height: 14),
                      _Label('Password'),
                      _passwordField(hint: 'Your business password'),
                    ],
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
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text(_owner ? 'Enter console' : 'Sign in'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _owner
                          ? 'Manage businesses, usernames and passwords.'
                          : 'Manage your menu and orders.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Ui.muted, fontSize: 12),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).moveY(begin: 16, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 22),
              Text(AppConfig.poweredBy,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({required String hint}) => TextField(
        controller: _pass,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _busy ? null : _submit(),
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Ui.muted, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Ui.inkSoft)),
      );
}

class _RoleToggle extends StatelessWidget {
  final bool owner;
  final ValueChanged<bool> onChanged;
  const _RoleToggle({required this.owner, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Ui.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Ui.border),
      ),
      child: Row(
        children: [
          _seg('Business', Icons.storefront_rounded, !owner, () => onChanged(false)),
          _seg('Platform owner', Icons.shield_rounded, owner, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? Ui.indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: active ? Colors.white : Ui.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: active ? Colors.white : Ui.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      );
}
