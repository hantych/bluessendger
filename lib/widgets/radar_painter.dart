import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/peer.dart';

class RadarPainter extends CustomPainter {
  final List<Peer> peers;
  final double sweepAngle; // 0..2π
  final String myName;

  RadarPainter({
    required this.peers,
    required this.sweepAngle,
    required this.myName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;

    // Background disc
    canvas.drawCircle(
      center,
      radius + 8,
      Paint()..color = const Color(0xFF0A1A0A),
    );

    // Concentric rings
    final ringPaint = Paint()
      ..color = const Color(0xFF1A4A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, ringPaint);
    }

    // Crosshairs
    final crossPaint = Paint()
      ..color = const Color(0xFF1A4A1A)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      crossPaint,
    );

    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.6,
        endAngle: sweepAngle,
        colors: const [
          Color(0x0000FF41),
          Color(0x6600FF41),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    // Center dot — me
    final mePaint = Paint()..color = const Color(0xFF00FF41);
    canvas.drawCircle(center, 6, mePaint);
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = const Color(0xFF00FF41).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _drawText(
      canvas,
      myName.toUpperCase(),
      center.translate(0, 22),
      const Color(0xFF00FF41),
      10,
    );

    // Peers
    for (int i = 0; i < peers.length; i++) {
      final peer = peers[i];
      final angle = (peer.id.hashCode % 360) * math.pi / 180.0;

      // Position by connection state — more central if connected
      double normalized;
      switch (peer.state) {
        case PeerState.connected:
          normalized = 0.45; // close to center
          break;
        case PeerState.connecting:
          normalized = 0.65;
          break;
        case PeerState.discovered:
          normalized = 0.85;
          break;
        case PeerState.disconnected:
          normalized = 0.95;
          break;
      }

      final dist = normalized * radius;
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );

      Color color;
      switch (peer.state) {
        case PeerState.connected:
          color = const Color(0xFF00FF41);
          break;
        case PeerState.connecting:
          color = const Color(0xFFFFCC00);
          break;
        case PeerState.discovered:
          color = const Color(0xFF66CCFF);
          break;
        case PeerState.disconnected:
          color = const Color(0xFF555555);
          break;
      }

      // Pulse for connected peers
      if (peer.state == PeerState.connected) {
        canvas.drawCircle(
          pos,
          16,
          Paint()..color = color.withOpacity(0.15),
        );
      }
      canvas.drawCircle(pos, 8, Paint()..color = color);
      canvas.drawCircle(
        pos,
        8,
        Paint()
          ..color = Colors.black.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      _drawText(
        canvas,
        peer.name,
        pos.translate(0, 20),
        color,
        9,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos,
    Color color,
    double size,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: 100);
    tp.paint(
      canvas,
      Offset(pos.dx - tp.width / 2, pos.dy),
    );
  }

  @override
  bool shouldRepaint(RadarPainter old) =>
      old.sweepAngle != sweepAngle ||
      old.peers != peers ||
      old.myName != myName;
}
