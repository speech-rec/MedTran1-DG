import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recording_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/record_save_dialog.dart';
import '../widgets/new_dictation_dialog.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _transcriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    _transcriptController.text = recordingProvider.transcript;
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  void _handleNewDictation() {
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    if (recordingProvider.transcript.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => NewDictationDialog(
          onConfirm: () {
            recordingProvider.clearTranscript();
            _transcriptController.clear();
            Navigator.of(context).pop();
          },
        ),
      );
    } else {
      recordingProvider.clearTranscript();
      _transcriptController.clear();
    }
  }

  void _handleOptions() {
    Navigator.of(context).pushNamed('/options');
  }

  void _handleSave() {
    showDialog(
      context: context,
      builder: (context) => RecordSaveDialog(
        onSaveAndNew: () async {
          final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
          await recordingProvider.saveNote();
          recordingProvider.clearTranscript();
          _transcriptController.clear();
          if (!mounted) return;
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transcript saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onContinueEditing: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _startRecording() async {
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    try {
      await recordingProvider.startRecording();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    try {
      await recordingProvider.stopRecording();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping recording: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        // Sync transcript with controller
        if (_transcriptController.text != recordingProvider.transcript) {
          _transcriptController.text = recordingProvider.transcript;
          _transcriptController.selection = TextSelection.fromPosition(
            TextPosition(offset: _transcriptController.text.length),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF16213E),
            elevation: 0,
            title: const Text('Record'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.logout();
                  if (!mounted) return;
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ],
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
                      'NEW',
                      Icons.add_circle_outline,
                      _handleNewDictation,
                    ),
                    _buildActionButton(
                      'OPTIONS',
                      Icons.settings,
                      _handleOptions,
                    ),
                    _buildActionButton(
                      'SAVE',
                      Icons.save,
                      _handleSave,
                    ),
                  ],
                ),
              ),
              // Enhanced Real-Time Transcript Editor
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  constraints: const BoxConstraints(
                    minHeight: 200, // Ensure minimum height
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A47),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: recordingProvider.isRecording 
                          ? const Color(0xFF4A90E2)
                          : Colors.grey.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header with status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: recordingProvider.isRecording 
                              ? const Color(0xFF4A90E2).withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              recordingProvider.isRecording ? Icons.mic : Icons.mic_off,
                              color: recordingProvider.isRecording 
                                  ? const Color(0xFF4A90E2)
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              recordingProvider.isRecording
                                  ? 'Live Transcription Active'
                                  : 'Ready to Record',
                              style: TextStyle(
                                color: recordingProvider.isRecording 
                                    ? const Color(0xFF4A90E2)
                                    : Colors.grey,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            if (recordingProvider.isRecording)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Real-time transcript display area
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Main transcript editor
                              Expanded(
                                flex: recordingProvider.isRecording ? 3 : 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A3B5C), // Slightly lighter background
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: TextField(
                                    controller: _transcriptController,
                                    maxLines: null,
                                    expands: true,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      height: 1.6,
                                      letterSpacing: 0.3,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: recordingProvider.isRecording
                                          ? 'Speak clearly into your microphone...'
                                          : 'Your transcribed text will appear here.\n\nTap the microphone button below to start recording.',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                      border: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      recordingProvider.updateTranscript(value);
                                    },
                                  ),
                                ),
                              ),
                              // Live interim transcript display
                              if (recordingProvider.isRecording)
                                Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(
                                    minHeight: 60,
                                    maxHeight: 120,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(top: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF4A90E2).withOpacity(0.1),
                                        const Color(0xFF4A90E2).withOpacity(0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4A90E2),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Live Speech',
                                            style: TextStyle(
                                              color: const Color(0xFF4A90E2),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Text(
                                            recordingProvider.interimTranscript.isEmpty
                                                ? 'Listening...'
                                                : recordingProvider.interimTranscript,
                                            style: TextStyle(
                                              color: recordingProvider.interimTranscript.isEmpty
                                                  ? Colors.white.withOpacity(0.4)
                                                  : Colors.white.withOpacity(0.9),
                                              fontSize: 16,
                                              fontStyle: recordingProvider.interimTranscript.isEmpty
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Recording Status Bar
              if (recordingProvider.isRecording)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF4A90E2).withOpacity(0.2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Recording in progress...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              // Bottom Recording Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: recordingProvider.isRecording
                          ? _stopRecording
                          : _startRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: recordingProvider.isRecording
                              ? Colors.red
                              : const Color(0xFF4A90E2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (recordingProvider.isRecording
                                      ? Colors.red
                                      : const Color(0xFF4A90E2))
                                  .withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          recordingProvider.isRecording
                              ? Icons.stop
                              : Icons.mic,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
