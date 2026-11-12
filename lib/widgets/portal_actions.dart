import 'package:flutter/material.dart';

class PortalSignOut extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final VoidCallback onSignOut;
  const PortalSignOut({
    super.key,
    required this.busy,
    required this.onSignOut,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: busy ? 'Signing out...' : 'Sign out',
    onPressed: busy || !enabled ? null : onSignOut,
    icon: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.logout),
  );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'LOCAL RECORDS • Trips, scans and reports are local to this device. '
        'Not connected to live student funding.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    ),
  );
}
