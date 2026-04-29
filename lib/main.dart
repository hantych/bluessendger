import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/radar_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF080F08),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const GhostMeshApp(),
    ),
  );
}

class GhostMeshApp extends StatelessWidget {
  const GhostMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghost Mesh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080F08),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          secondary: Color(0xFF00A828),
          surface: Color(0xFF0A1A0A),
        ),
        fontFamily: 'monospace',
      ),
      home: const _PermissionsGate(),
    );
  }
}

class _PermissionsGate extends StatefulWidget {
  const _PermissionsGate();

  @override
  State<_PermissionsGate> createState() => _PermissionsGateState();
}

class _PermissionsGateState extends State<_PermissionsGate> {
  String _status = 'Tap "Grant permissions" to start';
  bool _ready = false;
  bool _working = false;
  List<String> _missing = const [];
  bool _locationServiceOff = false;

  Future<void> _go() async {
    if (!Platform.isAndroid) {
      setState(() => _status = 'This app currently runs on Android only.');
      return;
    }

    setState(() {
      _working = true;
      _status = 'Requesting permissions…';
      _missing = const [];
      _locationServiceOff = false;
    });

    // Step 1: location permission. Both fine and "when in use" because
    // different Android versions / OEM ROMs check different ones.
    var locStatus = await Permission.locationWhenInUse.status;
    if (!locStatus.isGranted) {
      locStatus = await Permission.locationWhenInUse.request();
    }
    var locFull = await Permission.location.status;
    if (!locFull.isGranted) {
      locFull = await Permission.location.request();
    }

    // Step 2: nearby + bluetooth (Android 12+)
    final perms = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.notification,
    ];
    final results = await perms.request();

    // Step 3: check the location *service* is actually turned ON in the
    // system, not just the permission. Nearby silently fails without it.
    final locServiceOn = await Permission.location.serviceStatus.isEnabled;

    final missingList = <String>[];
    if (!locStatus.isGranted && !locStatus.isLimited) {
      missingList.add('Location (when in use)');
    }
    if (!locFull.isGranted && !locFull.isLimited) {
      missingList.add('Location');
    }
    results.forEach((perm, status) {
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        missingList.add(perm.toString().split('.').last);
      }
    });

    setState(() {
      _missing = missingList;
      _locationServiceOff = !locServiceOn;
      _working = false;
    });

    if (missingList.isNotEmpty || !locServiceOn) {
      setState(() => _status = 'Some things are missing — see below');
      return;
    }

    if (!mounted) return;
    setState(() {
      _status = 'Starting mesh…';
      _working = true;
    });
    await context.read<AppProvider>().init();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (_ready && provider.initialized) return const RadarScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF080F08),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '◎',
                  style: TextStyle(color: Color(0xFF00FF41), fontSize: 80),
                ),
                const SizedBox(height: 24),
                const Text(
                  'GHOST MESH',
                  style: TextStyle(
                    color: Color(0xFF00FF41),
                    fontFamily: 'monospace',
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'P2P · NO ACCOUNTS · NO SERVERS',
                  style: TextStyle(
                    color: Color(0xFF336633),
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 48),
                if (_working)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FF41),
                      strokeWidth: 2,
                    ),
                  )
                else ...[
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF66CC66),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_locationServiceOff)
                    _warningCard(
                      title: '⚠ LOCATION SERVICE IS OFF',
                      body:
                          'Swipe down from the top of your screen and turn ON Location / GPS. Nearby cannot scan without it.',
                      buttonLabel: 'OPEN APP SETTINGS',
                      onTap: openAppSettings,
                    ),
                  if (_missing.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _warningCard(
                      title: '⚠ MISSING PERMISSIONS',
                      body: _missing.join(', '),
                      buttonLabel: 'OPEN APP SETTINGS',
                      onTap: openAppSettings,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A4A1A),
                      foregroundColor: const Color(0xFF00FF41),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: const BorderSide(color: Color(0xFF00FF41)),
                      ),
                    ),
                    onPressed: _go,
                    child: const Text(
                      'GRANT PERMISSIONS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _warningCard({
    required String title,
    required String body,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A0A),
        border: Border.all(color: const Color(0xFFFFCC00)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFCC00),
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFCCCCAA),
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFCC00),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
