import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Mounted only while the Boarding tab is open and no result is being shown.
/// Let MobileScanner own its controller so its built-in lifecycle handling
/// pauses/resumes the camera, and disposes it when this widget is removed.
class BoardingScanner extends StatelessWidget {
  final ValueChanged<String> onCode;
  const BoardingScanner({super.key, required this.onCode});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            useAppLifecycleState: true,
            onDetect: (capture) {
              for (final code in capture.barcodes) {
                final raw = code.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  onCode(raw);
                  break;
                }
              }
            },
            errorBuilder: (context, error) => Container(
              color: Theme.of(context).colorScheme.surfaceContainer,
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: Text(
                  'Camera unavailable. Allow camera access in your phone '
                  'settings, then reopen this tab. Manual entry is available below.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 190,
                height: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 2),
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
