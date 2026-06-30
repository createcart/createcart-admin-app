import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';
import 'theme.dart';

/// Friendly label + colour + icon for each delivery status.
class StatusMeta {
  final String label;
  final Color fg;
  final Color bg;
  final IconData icon;
  const StatusMeta(this.label, this.fg, this.bg, this.icon);
}

StatusMeta statusMeta(String status) {
  switch (status) {
    case 'placed':
      return const StatusMeta('New', Ui.warn, Ui.warnBg, Icons.fiber_new_rounded);
    case 'confirmed':
      return const StatusMeta('Accepted', Ui.info, Ui.infoBg, Icons.check_circle_outline);
    case 'preparing':
      return const StatusMeta('Preparing', Color(0xFF7C3AED), Color(0xFFEDE9FE), Icons.restaurant_rounded);
    case 'out_for_delivery':
      return const StatusMeta('Out for delivery', Ui.indigo, Color(0xFFE0E7FF), Icons.delivery_dining_rounded);
    case 'delivered':
      return const StatusMeta('Delivered', Ui.success, Ui.successBg, Icons.task_alt_rounded);
    case 'cancelled':
      return const StatusMeta('Cancelled', Ui.danger, Ui.dangerBg, Icons.cancel_outlined);
    default:
      return StatusMeta(status, Ui.muted, const Color(0xFFF1F5F9), Icons.circle);
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  final bool small;
  const StatusChip(this.status, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final m = statusMeta(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: m.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m.icon, size: small ? 12 : 14, color: m.fg),
          const SizedBox(width: 5),
          Text(m.label,
              style: TextStyle(
                  color: m.fg, fontWeight: FontWeight.w700, fontSize: small ? 11 : 12.5)),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  final String? label;
  const LoadingView({super.key, this.label});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Ui.indigo),
            if (label != null) ...[
              const SizedBox(height: 14),
              Text(label!, style: const TextStyle(color: Ui.muted)),
            ],
          ],
        ),
      );
}

class InfoState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const InfoState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                child: Icon(icon, color: Ui.indigo, size: 36),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Ui.muted, height: 1.4)),
              ],
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      );
}

/// The CreateCart admin mark — an indigo rounded badge with a dashboard glyph.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Ui.indigo, Ui.indigoDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(Icons.storefront_rounded, color: Colors.white, size: size * 0.55),
      );
}

class PoweredByBar extends StatelessWidget {
  const PoweredByBar({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Text(
          AppConfig.poweredBy,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
              color: Ui.muted, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      );
}

/// A small labelled metric used on dashboards.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Ui.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Ui.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 10),
              Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Ui.ink)),
              Text(label, style: const TextStyle(color: Ui.muted, fontSize: 12)),
            ],
          ),
        ),
      );
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
