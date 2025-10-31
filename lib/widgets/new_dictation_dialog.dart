import 'package:flutter/material.dart';

class NewDictationDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const NewDictationDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          SizedBox(width: 12),
          Text(
            'Start New Dictation?',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to start a new dictation? The current transcript will be cleared. Make sure you have saved your work.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('Clear & Start New'),
        ),
      ],
    );
  }
}
