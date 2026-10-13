import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/timeguard_service.dart';
import 'services/home_route_observer.dart';
import 'screens/login_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/common.dart';

class TimeGuardApp extends StatefulWidget {
  const TimeGuardApp({super.key});
  @override
  State<TimeGuardApp> createState() => _TimeGuardAppState();
}

class _TimeGuardAppState extends State<TimeGuardApp> {
  final api = ApiService();
  late final auth = AuthService(api);
  late final data = TimeGuardService(api);
  late Future<void> startup;
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    startup = auth.restore();
    auth.addListener(sessionChanged);
  }

  void sessionChanged() {
    if (auth.employee == null) {
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
    }
  }

  @override
  void dispose() {
    auth.removeListener(sessionChanged);
    auth.dispose();
    api.client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers: [homeRouteObserver],
    title: 'TimeGuard',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('th'),
    supportedLocales: const [Locale('th'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: FutureBuilder<void>(
      future: startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: SafeArea(child: LoadingPanel()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ErrorPanel(
                snapshot.error!,
                () => setState(() => startup = auth.restore()),
              ),
            ),
          );
        }
        return ListenableBuilder(
          listenable: auth,
          builder: (context, _) => auth.employee == null
              ? LoginScreen(auth: auth)
              : EmployeeShell(
                  key: ValueKey(auth.employee!.id),
                  auth: auth,
                  data: data,
                ),
        );
      },
    ),
  );
}

class EmployeeShell extends StatefulWidget {
  final AuthService auth;
  final TimeGuardService data;
  const EmployeeShell({super.key, required this.auth, required this.data});
  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int index = 0;
  bool permissionsSeen = false;
  @override
  Widget build(BuildContext context) {
    if (!permissionsSeen) {
      return PermissionScreen(
        onContinue: () => setState(() => permissionsSeen = true),
      );
    }
    final pages = [
      HomeScreen(
        auth: widget.auth,
        data: widget.data,
        onNotifications: () => setState(() => index = 2),
      ),
      HistoryScreen(data: widget.data, onHome: () => setState(() => index = 0)),
      NotificationsScreen(data: widget.data),
      ProfileScreen(auth: widget.auth, data: widget.data),
    ];
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFEAF1FF),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppTheme.primary
                : const Color(0xFF98A2B3),
          ),
        ),
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'ประวัติ'),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'การแจ้งเตือน',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
