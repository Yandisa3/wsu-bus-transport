import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../widgets/portal_shell.dart';
import 'shared_trips_screen.dart';

class DriverScreen extends StatefulWidget {
  final UserProfile profile;
  final bool signingOut;
  final VoidCallback onSignOut;

  const DriverScreen({
    super.key,
    required this.profile,
    required this.signingOut,
    required this.onSignOut,
  });

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  int _tab = 0;

  void _openTrips() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedTripsScreen(profile: widget.profile),
      ),
    );
  }

  Widget _home() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PortalHeading(
          eyebrow: 'Driver portal',
          title: 'Welcome, ${widget.profile.fullName}',
          subtitle: 'Manage your journey from one place.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.directions_bus_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Ready for your next journey?',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Start or continue your trip, board students, '
                  'and end the trip when your journey is complete.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: widget.signingOut ? null : _openTrips,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Manage my trip'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('How it works', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const ListTile(
          leading: CircleAvatar(child: Text('1')),
          title: Text('Start your trip'),
          subtitle: Text('Enter the bus, route and boarding limit.'),
        ),
        const ListTile(
          leading: CircleAvatar(child: Text('2')),
          title: Text('Board students'),
          subtitle: Text(
            'Open Board students to scan a QR or enter a student number. '
            'Accepted passengers appear on that same page.',
          ),
        ),
        const ListTile(
          leading: CircleAvatar(child: Text('3')),
          title: Text('End your trip'),
          subtitle: Text(
            'Return to your trip controls and select End trip. '
            'Use the history button there to review completed trips.',
          ),
        ),
      ],
    );
  }

  Widget _account() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PortalHeading(
          eyebrow: 'Your account',
          title: 'Driver details',
          subtitle: 'Your assigned transport account.',
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
                leading: Icon(Icons.badge_outlined),
                title: Text('Assigned role'),
                subtitle: Text('Driver'),
              ),
            ],
          ),
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
        PortalDestination('Home', Icons.home_outlined),
        PortalDestination('Account', Icons.person_outline),
      ],
      child: _tab == 0 ? _home() : _account(),
    );
  }
}
