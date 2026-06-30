import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'session.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/platform/tenants_screen.dart';
import 'screens/tenant/tenant_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => Session()..restore(),
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CreateCart Admin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Routes between the login screen and the right console for the signed-in role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (!s.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Ui.indigo)));
    }
    switch (s.role) {
      case Role.platform:
        return const TenantsScreen();
      case Role.tenant:
        return const TenantShell();
      case Role.none:
        return const LoginScreen();
    }
  }
}
