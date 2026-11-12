import 'package:flutter/material.dart';

import '../models/driver_trip.dart';
import 'portal_shell.dart';

class BoardingEntryTile extends StatelessWidget {
  final TripEntry entry;
  const BoardingEntryTile({super.key, required this.entry});
  @override
  Widget build(BuildContext context) {
    final accepted = entry.outcome == BoardingOutcome.boarded;
    final color = accepted
        ? const Color(0xFF16805D)
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        child: ListTile(
          isThreeLine: true,
          leading: Icon(
            accepted ? Icons.check_circle_outline : Icons.block,
            color: color,
          ),
          title: Text(entry.name),
          subtitle: Text(
            '${entry.number} • ${entry.stop}\n'
            '${entry.outcome.label} · ${portalTime(context, entry.time)}'
            '${entry.manual ? ' · Manual' : ' · QR'}',
          ),
        ),
      ),
    );
  }
}

class TripHistoryTile extends StatelessWidget {
  final DriverTrip trip;
  const TripHistoryTile({super.key, required this.trip});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ExpansionTile(
        leading: Icon(trip.active ? Icons.directions_bus : Icons.task_alt),
        title: Text('${trip.bus} · ${trip.route}'),
        subtitle: Text(
          '${trip.driverName}\n${portalDate(context, trip.startedAt)} · '
          '${portalTime(context, trip.startedAt)} · ${trip.active ? 'Active' : 'Completed'}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          MetricGrid(
            items: [
              PortalMetric('Boarded', '${trip.boarded}', Icons.people_outline),
              PortalMetric('Not boarded', '${trip.denied}', Icons.block),
            ],
          ),
          const SizedBox(height: 16),
          if (trip.endedAt != null)
            Text('Ended at ${portalTime(context, trip.endedAt!)}'),
          if (trip.entries.isEmpty)
            const Text('No boarding attempts recorded.'),
          if (trip.entries.length > 50)
            const Text('Showing the latest 50 attempts.'),
          ...trip.entries.reversed
              .take(50)
              .map((e) => BoardingEntryTile(entry: e)),
          for (final note in trip.notes.reversed)
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(note.category),
              subtitle: Text(
                '${note.text}\n'
                '${portalTime(context, note.time)} · Device-only note',
              ),
            ),
        ],
      ),
    ),
  );
}
