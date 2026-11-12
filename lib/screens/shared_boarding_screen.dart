import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/shared_trip.dart';
import '../models/user_profile.dart';
import '../services/qr_codec.dart';
import '../services/shared_boarding_service.dart';
import '../widgets/boarding_scanner.dart';

class SharedBoardingScreen extends StatefulWidget {
  final SharedTrip trip;
  final UserProfile profile;

  const SharedBoardingScreen({
    super.key,
    required this.trip,
    required this.profile,
  });

  @override
  State<SharedBoardingScreen> createState() => _SharedBoardingScreenState();
}

class _SharedBoardingScreenState extends State<SharedBoardingScreen> {
  final _service = SharedBoardingService();
  final _number = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _records;

  bool _busy = false;
  bool _showScanner = false;
  String? _result;

  bool get _canBoard =>
      widget.trip.isActive &&
      widget.profile.role == UserRole.driver &&
      widget.profile.uid == widget.trip.driverUid;
  @override
  void initState() {
    super.initState();
    _records = _service.watch(widget.trip.id);
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _check(String raw, {bool manual = false}) async {
    if (!_canBoard || _busy || _result != null) return;

    final decoded = QrCodec.decode(raw.trim());

    if (decoded == null ||
        !RegExp(r'^\d{5,15}$').hasMatch(decoded.studentNumber)) {
      setState(() => _result = 'Enter a valid student number or QR.');
      return;
    }

    if (!manual && !decoded.isFresh) {
      setState(() => _result = 'This QR has expired. Refresh it.');
      return;
    }

    setState(() {
      _busy = true;
      _showScanner = false;
    });

    try {
      final result = await _service.board(
        tripId: widget.trip.id,
        studentNumber: decoded.studentNumber,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _number.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _result = error is StateError
              ? error.message.toString()
              : 'Could not confirm boarding. Check your connection '
                    'and permissions, then retry the same student.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.trip.bus} boardings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.trip.route,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Driver: ${widget.trip.driverName}'),
              const SizedBox(height: 12),
              const Text(
                'BOARDING CHECK\n'
                'Funding is checked against sample students. '
                'Accepted boardings are saved in Firebase.',
              ),
              const SizedBox(height: 20),
              if (_canBoard) ...[
                TextField(
                  controller: _number,
                  readOnly: _busy || _result != null,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Student number',
                    hintText: '221012345',
                  ),
                  onSubmitted: (value) => _check(value, manual: true),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || _result != null
                      ? null
                      : () => _check(_number.text, manual: true),
                  child: Text(_busy ? 'Checking...' : 'Check student'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || _result != null
                      ? null
                      : () => setState(() => _showScanner = !_showScanner),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    _showScanner ? 'Close camera' : 'Scan student QR',
                  ),
                ),
                if (_showScanner && !_busy && _result == null)
                  BoardingScanner(onCode: (code) => _check(code)),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _result!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _result = null),
                    child: const Text('Check next student / retry'),
                  ),
                ],
                const SizedBox(height: 20),
              ],
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _records,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Unable to load boardings. Check your connection '
                      'and Firestore permissions.',
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final records = snapshot.data!.docs;
                  final cached = snapshot.data!.metadata.isFromCache;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Accepted boardings: ${records.length}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.trip.capacity != null) ...[
                        const SizedBox(height: 8),
                        Text('Boarding limit: ${widget.trip.capacity}'),
                        Text(
                          'Boarding places remaining: '
                          '${(widget.trip.capacity! - records.length).clamp(0, widget.trip.capacity!)}',
                        ),
                        const Text(
                          'Passengers getting off are not tracked. '
                          'This is not a live seat-occupancy count.',
                        ),
                      ] else
                        const Text(
                          'Older trip: boarding limit was not recorded.',
                        ),
                      if (cached)
                        const Text('Cached records; waiting for confirmation.'),
                      const SizedBox(height: 12),
                      if (records.isEmpty)
                        const Text('No accepted boardings on this trip yet.'),
                      ...records.map((record) {
                        final data = record.data();
                        final timestamp = data['boardedAt'] as Timestamp?;
                        final time = timestamp == null
                            ? 'Confirming save...'
                            : TimeOfDay.fromDateTime(
                                timestamp.toDate().toLocal(),
                              ).format(context);

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(data['studentName'] as String),
                            subtitle: Text('${data['studentNumber']} • $time'),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
