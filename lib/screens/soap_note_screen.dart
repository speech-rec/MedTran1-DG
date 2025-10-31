import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recording_provider.dart';

class SoapNoteScreen extends StatefulWidget {
  const SoapNoteScreen({super.key});

  @override
  State<SoapNoteScreen> createState() => _SoapNoteScreenState();
}

class _SoapNoteScreenState extends State<SoapNoteScreen> {
  final _soapNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    _soapNoteController.text = recordingProvider.currentSoapNote ?? '';
  }

  @override
  void dispose() {
    _soapNoteController.dispose();
    super.dispose();
  }

  void _handleNewDictation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Start New Dictation?'),
        content: const Text(
          'Are you sure you want to start a new dictation? Current SOAP note will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
              recordingProvider.clearTranscript();
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((route) => route.settings.name == '/record');
            },
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveSoapNote() async {
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    if (_soapNoteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOAP note is empty')),
      );
      return;
    }

    final success = await recordingProvider.saveSoapNote(_soapNoteController.text);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOAP note saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save SOAP note')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text('SOAP Note'),
      ),
      body: Column(
        children: [
          // Top Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF16213E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  'New Dictation',
                  Icons.add_circle_outline,
                  _handleNewDictation,
                ),
                _buildActionButton(
                  'Save SOAP Note',
                  Icons.save,
                  _handleSaveSoapNote,
                ),
              ],
            ),
          ),
          // SOAP Note Editor
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: Color(0xFF4A90E2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'SOAP Format',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend
                  _buildLegend(),
                  const SizedBox(height: 16),
                  // Editor
                  Expanded(
                    child: TextField(
                      controller: _soapNoteController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'SOAP note will appear here...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF16213E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: const Color(0xFF4A90E2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOAP Format Guide:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A90E2),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'S - Subjective: Patient\'s symptoms and complaints',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          SizedBox(height: 4),
          Text(
            'O - Objective: Observable findings and measurements',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          SizedBox(height: 4),
          Text(
            'A - Assessment: Diagnosis and evaluation',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          SizedBox(height: 4),
          Text(
            'P - Plan: Treatment plan and next steps',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
