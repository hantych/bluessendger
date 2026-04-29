import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/peer.dart';
import '../providers/app_provider.dart';
import '../widgets/radar_painter.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _openChat(Peer peer) {
    context.read<AppProvider>().setActiveChat(peer.id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)),
    ).then((_) {
      context.read<AppProvider>().setActiveChat(null);
    });
  }

  Color _stateColor(PeerState s) {
    switch (s) {
      case PeerState.connected:
        return const Color(0xFF00FF41);
      case PeerState.connecting:
        return const Color(0xFFFFCC00);
      case PeerState.discovered:
        return const Color(0xFF66CCFF);
      case PeerState.disconnected:
        return const Color(0xFF555555);
    }
  }

  String _stateLabel(PeerState s) {
    switch (s) {
      case PeerState.connected:
        return '● CONNECTED';
      case PeerState.connecting:
        return '◐ CONNECTING';
      case PeerState.discovered:
        return '○ FOUND';
      case PeerState.disconnected:
        return '· OFFLINE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final peers = provider.peerList
        .where((p) => p.state != PeerState.disconnected)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF080F08),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GHOST MESH',
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            Text(
              '${provider.myName} · ${peers.length} peer${peers.length == 1 ? '' : 's'} nearby',
              style: const TextStyle(
                color: Color(0xFF00A828),
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00FF41)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Radar
          Expanded(
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) {
                return CustomPaint(
                  painter: RadarPainter(
                    peers: peers,
                    sweepAngle: _sweep.value * 2 * math.pi,
                    myName: provider.myName,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
          // Peer list / empty hint
          if (peers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: const Text(
                'Scanning…\nMake sure Bluetooth and Location are ON,\nand the other phone has Ghost Mesh open.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF00A828),
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            )
          else
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A0A),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF00FF41).withOpacity(0.25),
                  ),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: peers.length,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemBuilder: (context, i) {
                  final peer = peers[i];
                  final color = _stateColor(peer.state);
                  return GestureDetector(
                    onTap: peer.isConnected ? () => _openChat(peer) : null,
                    child: Opacity(
                      opacity: peer.isConnected ? 1 : 0.6,
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: color.withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(4),
                          color: const Color(0xFF0D1F0D),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              peer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFCCFFCC),
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _stateLabel(peer.state),
                              style: TextStyle(
                                color: color,
                                fontFamily: 'monospace',
                                fontSize: 9,
                              ),
                            ),
                            if (peer.isConnected) ...[
                              const SizedBox(height: 4),
                              Text(
                                'tap to chat',
                                style: TextStyle(
                                  color: color.withOpacity(0.5),
                                  fontFamily: 'monospace',
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
