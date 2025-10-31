import 'package:flutter/material.dart';

class RecordSaveDialog extends StatelessWidget {
  final VoidCallback onSaveAndNew;
  final VoidCallback onContinueEditing;

  const RecordSaveDialog({
    super.key,
    required this.onSaveAndNew,
    required this.onContinueEditing,
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
            Icons.save,
            color: Color(0xFF4A90E2),
          ),
          SizedBox(width: 12),
          Text(
            'Save Transcript',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: const Text(
        'Would you like to save the current transcript and start a new one, or continue editing?',
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
        TextButton(
          onPressed: onContinueEditing,
          child: const Text(
            'Continue Editing',
            style: TextStyle(color: Color(0xFF4A90E2)),
          ),
        ),
        ElevatedButton(
          onPressed: onSaveAndNew,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A90E2),
          ),
          child: const Text('Save & Start New'),
        ),
      ],
    );
  }
}
