import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/funding_service.dart';

class FundingCard extends StatefulWidget {
  final String uid;
  final String studentNumber;

  const FundingCard({
    super.key,
    required this.uid,
    required this.studentNumber,
  });

  @override
  State<FundingCard> createState() => _FundingCardState();
}

class _FundingCardState extends State<FundingCard> with WidgetsBindingObserver {
  final _service = FundingService();
  late Stream<FundingUpdate> _updates;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updates = _service.watchFunding(widget.uid);

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant FundingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _updates = _service.watchFunding(widget.uid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _retry() {
    setState(() {
      _updates = _service.watchFunding(widget.uid);
    });
  }

  Widget _card(
    String title,
    String message, {
    IconData icon = Icons.info_outline,
    bool loading = false,
    bool retry = false,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(height: 1.5)),
            if (retry) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _retry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FundingUpdate>(
      stream: _updates,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _card(
            'Checking funding',
            'Loading your transport funding record.',
            loading: true,
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          var message = 'Check your connection and try again.';

          if (error is FirebaseException && error.code == 'permission-denied') {
            message =
                'Your account cannot read this funding record. '
                'Contact the transport administrator.';
          } else if (error is FormatException) {
            message =
                'Your funding record needs correction. '
                'Contact the transport administrator.';
          }

          return _card('Funding unavailable', message, retry: true);
        }

        final update = snapshot.data;

        if (update == null || update.fromCache) {
          return _card(
            'Awaiting funding confirmation',
            'Current funding has not been confirmed with the server. '
                'Check your connection.',
            icon: Icons.cloud_off_outlined,
            retry: true,
          );
        }

        final record = update.record;

        if (record == null) {
          return _card(
            'Funding not yet verified',
            'No funding record is linked to your account. '
                'Contact the transport administrator.',
          );
        }

        if (record.studentNumber != widget.studentNumber) {
          return _card(
            'Account details need checking',
            'Your profile and funding record have different student '
                'numbers. Contact the transport administrator.',
          );
        }

        if (!record.isFunded) {
          return _card(
            'Not funded for transport',
            'Your record does not show transport funding. '
                'Contact student finance if this is incorrect.',
          );
        }

        final expiry = record.expiry;

        if (expiry == null) {
          return _card(
            'Funding details incomplete',
            'Your funding expiry date is missing. '
                'Contact the transport administrator.',
          );
        }

        if (!DateTime.now().isBefore(expiry)) {
          return _card(
            'Transport funding expired',
            'Contact student finance to confirm your renewal.',
            icon: Icons.event_busy_outlined,
          );
        }

        final localExpiry = expiry.toLocal();
        final localizations = MaterialLocalizations.of(context);
        final date = localizations.formatMediumDate(localExpiry);
        final time = localizations.formatTimeOfDay(
          TimeOfDay.fromDateTime(localExpiry),
        );

        return _card(
          'Funded for transport',
          'Your recorded funding is valid until $date at $time.',
          icon: Icons.check_circle_outline,
        );
      },
    );
  }
}
