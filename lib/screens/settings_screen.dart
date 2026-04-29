import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: context.read<AppProvider>().myName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF080F08),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00FF41)),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Color(0xFF00FF41),
            fontFamily: 'monospace',
            letterSpacing: 4,
            fontSize: 16,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR NAME',
              style: TextStyle(
                color: Color(0xFF00A828),
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(
                color: Color(0xFFCCFFCC),
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                border: _border(),
                enabledBorder: _border(),
                focusedBorder: _border(focused: true),
                hintText: 'Visible to nearby peers',
                hintStyle: const TextStyle(
                  color: Color(0xFF336633),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4A1A),
                  foregroundColor: const Color(0xFF00FF41),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: Color(0xFF00FF41)),
                  ),
                ),
                onPressed: () async {
                  await provider.setMyName(_nameController.text);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Name saved · mesh restarted'),
                        backgroundColor: Color(0xFF1A4A1A),
                      ),
                    );
                  }
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'ACTIVITY LOG',
              style: TextStyle(
                color: Color(0xFF00A828),
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1A0A),
                  border: Border.all(
                    color: const Color(0xFF00FF41).withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: provider.log.isEmpty
                    ? const Center(
                        child: Text(
                          'No activity yet',
                          style: TextStyle(
                            color: Color(0xFF336633),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.log.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            provider.log[i],
                            style: const TextStyle(
                              color: Color(0xFF66CC66),
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'GHOST MESH · v1.0\n'
              'Peer-to-peer mesh chat using Google Nearby Connections.\n'
              'No accounts. No servers. Range: ~30–100m.',
              style: TextStyle(
                color: Color(0xFF336633),
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _border({bool focused = false}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: const Color(0xFF00FF41).withOpacity(focused ? 1 : 0.3),
        ),
      );
}
