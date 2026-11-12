import 'dart:async';

import 'package:flutter/material.dart';

import '../models/driver_trip.dart';
import '../models/student.dart';
import '../models/user_profile.dart';
import '../services/demo_trip_store.dart';
import '../services/qr_codec.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/boarding_scanner.dart';
import '../widgets/portal_shell.dart';
import '../widgets/trip_history.dart';
import 'shared_trips_screen.dart';

class LocalDemoDriverScreen extends StatefulWidget {
  final UserProfile profile;
  final bool signingOut;
  final VoidCallback onSignOut;
  const LocalDemoDriverScreen({
    super.key,
    required this.profile,
    required this.signingOut,
    required this.onSignOut,
  });
  @override
  State<LocalDemoDriverScreen> createState() => _LocalDemoDriverScreenState();
}

class _LocalDemoDriverScreenState extends State<LocalDemoDriverScreen> {
  final _store = DemoTripStore.instance;
  final _bus = TextEditingController();
  final _route = TextEditingController();
  final _capacity = TextEditingController(text: '60');
  final _manual = TextEditingController();
  final _startKey = GlobalKey<FormState>();
  Timer? _clock;
  int _tab = 0;
  bool _working = false;
  bool _sound = true;
  String _search = '';
  String _filter = 'All';
  TripEntry? _result;
  String? _scanMessage;
  DriverTrip? get _trip => _store.activeFor(widget.profile.uid);
  bool get _disabled => _working || _store.busy || widget.signingOut;

  @override
  void initState() {
    super.initState();
    unawaited(_store.load());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _bus.dispose();
    _route.dispose();
    _capacity.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disabled) {
      return;
    }
    setState(() => _working = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The action could not be saved. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _start() async {
    if (!_startKey.currentState!.validate()) {
      return;
    }
    await _run(() async {
      await _store.start(
        uid: widget.profile.uid,
        driverName: widget.profile.fullName,
        bus: _bus.text,
        route: _route.text,
        capacity: int.parse(_capacity.text),
        stops: List<String>.from(MockData.stops),
      );
      if (mounted) {
        setState(() {
          _result = null;
          _scanMessage = null;
        });
      }
    });
  }

  Future<void> _end(DriverTrip trip) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish this trip?'),
        content: Text(
          '${trip.boarded} boarded and ${trip.denied} not-boarded attempts '
          'will remain in your trip history. A new trip starts a new count.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish trip'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) {
      return;
    }
    await _run(() async {
      await _store.end(widget.profile.uid, trip.id);
      if (mounted) {
        setState(() {
          _tab = 3;
          _result = null;
          _scanMessage = null;
        });
      }
    });
  }

  Future<void> _addNote(DriverTrip trip) async {
    String noteText = '';
    String category = 'Delay';
    final key = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Record a trip note'),
          content: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Saved on this device only. This does not notify a manager or emergency service.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    items: ['Delay', 'Vehicle issue', 'Boarding issue', 'Other']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (s) {
                      if (s != null) {
                        update(() => category = s);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    onChanged: (value) => noteText = value,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                    ),
                    validator: (s) => s == null || s.trim().isEmpty
                        ? 'Enter a short note.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save note'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) {
      return;
    }
    await _run(
      () => _store.addNote(widget.profile.uid, trip.id, category, noteText),
    );
  }

  Future<void> _board(String raw, {bool manual = false}) async {
    if (!mounted || _disabled || _result != null || _scanMessage != null) {
      return;
    }
    final trip = _trip;
    if (trip == null) {
      return;
    }
    final decoded = QrCodec.decode(raw.trim());
    if (decoded == null ||
        !RegExp(r'^\d{5,15}$').hasMatch(decoded.studentNumber)) {
      setState(
        () => _scanMessage =
            'Invalid code. Use a student QR or enter a student number.',
      );
      return;
    }
    if (!manual && !decoded.isFresh) {
      setState(
        () => _scanMessage =
            'This QR has expired. Ask the student to refresh it.',
      );
      return;
    }
    // Mark busy synchronously before the first await to ignore repeated camera frames.
    setState(() => _working = true);
    try {
      final result = await _store.board(
        uid: widget.profile.uid,
        tripId: trip.id,
        number: decoded.studentNumber,
        manual: manual,
        students: MockData.students,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _manual.clear();
      });
      if (_sound) {
        try {
          if (result.outcome == BoardingOutcome.boarded) {
            await SoundService.playSuccess();
          } else {
            await SoundService.playWarning();
          }
        } catch (_) {
          /* Sound failure must not change a saved boarding result. */
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _scanMessage = 'Could not save this attempt. Do not count this passenger as boarded. Retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Widget _page(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(20), children: children);

  Widget _home() {
    final trip = _trip;
    return _page([
      OutlinedButton.icon(
        onPressed: _disabled
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SharedTripsScreen(profile: widget.profile),
                  ),
                );
              },
        icon: const Icon(Icons.directions_bus_outlined),
        label: const Text('Shared bus trips'),
      ),
      const SizedBox(height: 16),
      RouteHero(
        label: trip == null ? 'READY WHEN YOU ARE' : 'TRIP IN PROGRESS',
        title: trip?.route ?? 'Prepare your next trip',
        subtitle: trip == null
            ? 'Set your vehicle and boarding limit before opening the scanner.'
            : '${trip.bus} · Started ${portalTime(context, trip.startedAt)}\n'
                  '${DateTime.now().difference(trip.startedAt).inMinutes.clamp(0, 9999)} minutes elapsed',
        action: trip == null
            ? null
            : FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: _disabled ? null : () => setState(() => _tab = 1),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Open boarding'),
              ),
      ),
      const SizedBox(height: 20),
      if (trip == null)
        _startForm()
      else ...[
        MetricGrid(
          items: [
            PortalMetric(
              'Boarded this trip',
              '${trip.boarded}',
              Icons.people_outline,
            ),
            PortalMetric(
              'Places remaining',
              '${trip.remaining}',
              Icons.event_seat_outlined,
            ),
            PortalMetric('Not boarded', '${trip.denied}', Icons.block),
            PortalMetric(
              'Trip notes',
              '${trip.notes.length}',
              Icons.sticky_note_2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current boarding stop',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('${trip.id}-${trip.stopIndex}'),
                  initialValue: trip.stopIndex,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < trip.stops.length; i++)
                      DropdownMenuItem(value: i, child: Text(trip.stops[i])),
                  ],
                  onChanged: _disabled
                      ? null
                      : (i) {
                          if (i != null) {
                            _run(
                              () => _store.setStop(
                                widget.profile.uid,
                                trip.id,
                                i,
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: trip.boarded / trip.capacity,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Text(
                  '${trip.boarded} of ${trip.capacity} places used. '
                  'No alighting is tracked; places reset with the next trip.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _disabled ? null : () => _addNote(trip),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Trip note'),
            ),
            OutlinedButton.icon(
              onPressed: _disabled ? null : () => _end(trip),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Finish trip'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      const Text(
        'Student eligibility comes from sample records. '
        'No live boarding authorisation or manager notification is sent.',
      ),
    ]);
  }

  Widget _startForm() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _startKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Trip setup', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bus,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Bus name or registration',
                hintText: 'e.g. Bus 01',
              ),
              validator: (s) =>
                  s == null || s.trim().isEmpty ? 'Enter your bus.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _route,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Route name',
                hintText: 'e.g. Residence to campus',
              ),
              validator: (s) =>
                  s == null || s.trim().isEmpty ? 'Enter a route name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Boarding limit'),
              validator: (s) {
                final n = int.tryParse(s ?? '');
                return n == null || n < 1 || n > 100
                    ? 'Enter a number from 1 to 100.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${MockData.stops.length} stops available. Choose the current stop once the trip starts.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _disabled || MockData.stops.isEmpty ? null : _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start trip'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _boarding() {
    final trip = _trip;
    if (trip == null) {
      return _page([
        const EmptyPanel(
          title: 'Start a trip first',
          message:
              'Open Overview and enter your bus and route before boarding.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _tab = 0),
          child: const Text('Go to trip setup'),
        ),
      ]);
    }
    return _page([
      PortalHeading(
        eyebrow: 'Boarding',
        title: trip.currentStop,
        subtitle: '${trip.bus} · ${trip.remaining} places remaining',
      ),
      if (_working) const LinearProgressIndicator(),
      if (_result != null || _scanMessage != null) ...[
        EmptyPanel(
          title: _result?.outcome.label ?? 'Check this attempt',
          message: _result == null
              ? _scanMessage!
              : '${_result!.name}\n${_result!.number}\nSaved on this device.',
          icon: _result?.outcome == BoardingOutcome.boarded
              ? Icons.check_circle_outline
              : Icons.info_outline,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _disabled
              ? null
              : () => setState(() {
                  _result = null;
                  _scanMessage = null;
                }),
          child: const Text('Check next student'),
        ),
      ] else if (!_working)
        BoardingScanner(onCode: (code) => _board(code)),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Manual entry',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manual,
                keyboardType: TextInputType.number,
                readOnly: _disabled || _result != null || _scanMessage != null,
                decoration: const InputDecoration(labelText: 'Student number'),
                onSubmitted: (value) => _board(value, manual: true),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _disabled || _result != null || _scanMessage != null
                    ? null
                    : () => _board(_manual.text, manual: true),
                child: const Text('Check student'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sound feedback'),
                value: _sound,
                onChanged: (v) => setState(() => _sound = v),
              ),
              const Text(
                'Sample records: 221012345 is funded; 221099999 is not funded. '
                'A denied student cannot be admitted using this screen.',
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _activity() {
    final trip = _trip;
    if (trip == null) {
      return _page([
        const EmptyPanel(
          title: 'No active trip',
          message: 'Completed trips are available in History.',
        ),
      ]);
    }
    final entries = trip.entries.reversed.where((e) {
      final match = '${e.number} ${e.name} ${e.stop}'.toLowerCase().contains(
        _search.toLowerCase(),
      );
      return match &&
          (_filter == 'All' ||
              (_filter == 'Boarded'
                  ? e.outcome == BoardingOutcome.boarded
                  : e.outcome != BoardingOutcome.boarded));
    }).toList();
    return _page([
      const PortalHeading(
        eyebrow: 'Current trip',
        title: 'Boarding activity',
        subtitle:
            'Accepted passengers and unsuccessful attempts are kept separate.',
      ),
      TextField(
        decoration: const InputDecoration(
          labelText: 'Search name, number or stop',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: ['All', 'Boarded', 'Not boarded']
            .map(
              (v) => ChoiceChip(
                label: Text(v),
                selected: _filter == v,
                onSelected: (_) => setState(() => _filter = v),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      if (entries.isEmpty)
        const EmptyPanel(
          title: 'No matching attempts',
          message: 'Your boarding checks will appear here.',
        ),
      if (entries.length > 100)
        const Text('Showing the latest 100 matching attempts.'),
      ...entries.take(100).map((e) => BoardingEntryTile(entry: e)),
    ]);
  }

  Widget _history() {
    final trips = _store.trips.reversed
        .where((t) => t.driverUid == widget.profile.uid)
        .toList();
    return _page([
      const PortalHeading(
        eyebrow: 'Your records',
        title: 'Trip history',
        subtitle: 'Saved on this device, including completed trips and notes.',
      ),
      if (trips.isEmpty)
        const EmptyPanel(
          title: 'Your first trip starts here',
          message: 'Start a trip from Overview. It will be saved here.',
        ),
      ...trips.map((t) => TripHistoryTile(trip: t)),
    ]);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _store,
    builder: (context, _) {
      Widget body;
      if (!_store.loaded) {
        body = _page([
          EmptyPanel(
            title: _store.loadError == null
                ? 'Loading trips'
                : 'Trips unavailable',
            message: _store.loadError ?? 'Restoring your saved trip.',
          ),
          if (_store.loadError == null)
            const LinearProgressIndicator()
          else
            TextButton(onPressed: _store.load, child: const Text('Retry')),
        ]);
      } else {
        body = switch (_tab) {
          0 => _home(),
          1 => _boarding(),
          2 => _activity(),
          _ => _history(),
        };
      }
      return PortalShell(
        profile: widget.profile,
        signingOut: widget.signingOut,
        busy: _working || _store.busy,
        onSignOut: widget.onSignOut,
        demo: true,
        selected: _tab,
        onSelect: (v) {
          if (!_disabled) {
            setState(() => _tab = v);
          }
        },
        destinations: const [
          PortalDestination('Overview', Icons.space_dashboard_outlined),
          PortalDestination('Board', Icons.qr_code_scanner),
          PortalDestination('Activity', Icons.people_outline),
          PortalDestination('History', Icons.history),
        ],
        child: body,
      );
    },
  );
}
