import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../widgets/funding_card.dart';
import '../widgets/portal_shell.dart';
import 'shared_trips_screen.dart';

class StudentDashboard extends StatefulWidget {
  final UserProfile profile;
  final bool signingOut;
  final VoidCallback onSignOut;
  const StudentDashboard({
    super.key,
    required this.profile,
    required this.signingOut,
    required this.onSignOut,
  });
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _tab = 0;
  UserProfile get profile => widget.profile;

  Widget _page(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(20), children: children);

  Widget _funding() => profile.studentNumber == null
      ? const EmptyPanel(
          title: 'Student number missing',
          message:
              'Contact the transport administrator to correct your profile.',
        )
      : FundingCard(
          key: ValueKey(profile.uid),
          uid: profile.uid,
          studentNumber: profile.studentNumber!,
        );

  Widget _home() => _page([
    PortalHeading(
      eyebrow: 'Student overview',
      title: 'Hello, ${profile.fullName.split(' ').first}',
      subtitle: 'Your transport details, organised around your day.',
    ),
    RouteHero(
      label: 'WSU STUDENT ACCOUNT',
      title: profile.fullName,
      subtitle:
          'Student number: ${profile.studentNumber ?? 'Unavailable'}\n'
          'Your account is active. Funding is checked separately below.',
    ),
    const SizedBox(height: 20),
    _funding(),
    const SizedBox(height: 24),
    Text('Your travel', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    Card(
      child: ListTile(
        leading: const Icon(Icons.directions_bus_outlined),
        title: const Text('Find your bus'),
        subtitle: const Text('View active trips, buses and driver details.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: widget.signingOut
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SharedTripsScreen(profile: profile),
                  ),
                );
              },
      ),
    ),
    const SizedBox(height: 16),
    const EmptyPanel(
      title: 'Travel history is being connected',
      message: 'Shared trips and your boarding history will appear here once live boarding is enabled.',
      icon: Icons.route_outlined,
    ),
  ]);

  Widget _account() => _page([
    const PortalHeading(
      eyebrow: 'Your account',
      title: 'Student details',
      subtitle: 'These details are linked to your signed-in account.',
    ),
    Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Full name'),
            subtitle: Text(profile.fullName),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Student number'),
            subtitle: Text(profile.studentNumber ?? 'Unavailable'),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('Assigned portal'),
            subtitle: Text('Student'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    const Text(
      'If your name, student number or funding details are incorrect, '
      'contact the transport administrator. Role and funding changes are not self-service.',
    ),
    const SizedBox(height: 24),
    OutlinedButton.icon(
      onPressed: widget.signingOut ? null : widget.onSignOut,
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
    ),
  ]);

  @override
  Widget build(BuildContext context) => PortalShell(
    profile: profile,
    signingOut: widget.signingOut,
    onSignOut: widget.onSignOut,
    selected: _tab,
    onSelect: (v) => setState(() => _tab = v),
    destinations: const [
      PortalDestination('Home', Icons.home_outlined),
      PortalDestination('Funding', Icons.verified_outlined),
      PortalDestination('Account', Icons.person_outline),
    ],
    child: switch (_tab) {
      0 => _home(),
      1 => _page([
        const PortalHeading(
          eyebrow: 'Transport eligibility',
          title: 'Your funding',
          subtitle: 'Status and expiry from your funding record.',
        ),
        _funding(),
      ]),
      _ => _account(),
    },
  );
}
