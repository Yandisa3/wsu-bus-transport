import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/student.dart';
import '../widgets/portal_shell.dart';

class StudentQrScreen extends StatelessWidget {
  final bool embedded;
  const StudentQrScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PortalHeading(
          eyebrow: 'Testing tools',
          title: 'Scanner test codes',
          subtitle:
              'Open this page on a second screen to test the driver scanner. '
              'These sample codes do not authorise real travel.',
        ),
        for (final student in MockData.students)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      student.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(student.studentNumber),
                    const SizedBox(height: 20),
                    Center(
                      child: QrImageView(
                        data: student.studentNumber,
                        version: QrVersions.auto,
                        size: 184,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          student.isFunded
                              ? Icons.check_circle_outline
                              : Icons.block,
                          color: student.isFunded
                              ? const Color(0xFF16805D)
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            student.isFunded
                                ? 'Sample funded student'
                                : 'Sample unfunded student',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    return embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Scanner test codes')),
            body: content,
          );
  }
}
