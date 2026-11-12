import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../widgets/portal_shell.dart';
import '../widgets/shared_manager_overview.dart';

class ManagerScreen extends StatefulWidget {
  final UserProfile profile;
  final bool signingOut;
  final VoidCallback onSignOut;

  const ManagerScreen({
    super.key,
    required this.profile,
    required this.signingOut,
    required this.onSignOut,
  });

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _tab = 0;

  Widget _account() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PortalHeading(
          eyebrow: 'Your account',
          title: 'Manager details',
          subtitle: 'Your assigned transport management account.',
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Name'),
                subtitle: Text(widget.profile.fullName),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.admin_panel_settings_outlined),
                title: Text('Assigned role'),
                subtitle: Text('Manager'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Use Fleet overview to inspect active trips, view bus locations '
          'and review passenger records. Completed journeys are available '
          'through the Completed trips button.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      profile: widget.profile,
      signingOut: widget.signingOut,
      onSignOut: widget.onSignOut,
      selected: _tab,
      onSelect: (value) => setState(() => _tab = value),
      destinations: const [
        PortalDestination('Fleet overview', Icons.directions_bus_outlined),
        PortalDestination('Account', Icons.person_outline),
      ],
      child: _tab == 0
          ? SharedManagerOverview(
              key: ValueKey(widget.profile.uid),
              profile: widget.profile,
              signingOut: widget.signingOut,
            )
          : _account(),
    );
  }
}
