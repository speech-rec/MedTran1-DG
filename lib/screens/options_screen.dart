import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recording_provider.dart';
import '../widgets/record_save_dialog.dart';
import 'network_test_screen.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndStartNew() async {
    showDialog(
      context: context,
      builder: (context) => RecordSaveDialog(
        onSaveAndNew: () async {
          final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
          await recordingProvider.saveNote();
          recordingProvider.clearTranscript();
          if (!mounted) return;
          if (context.mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transcript saved! Starting new dictation.'),
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

  Future<void> _handleConvertToSoap() async {
    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    if (recordingProvider.transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcript to convert')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    await recordingProvider.convertToSoapNote();

    if (!mounted) return;
    
    Navigator.of(context).pop(); // Close loading dialog
    Navigator.of(context).pop(); // Close options screen
    Navigator.of(context).pushNamed('/soap-note');
  }

  Future<void> _handleSendEmail() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    if (recordingProvider.transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcript to send')),
      );
      return;
    }

    final success = await recordingProvider.sendTranscriptToEmail(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript sent to email successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _emailController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send email. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF16213E),
            elevation: 0,
            title: const Text('Options'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Save & Start New
                _buildOptionCard(
                  title: 'Save & Start New',
                  subtitle: 'Save current transcript and start a new dictation',
                  icon: Icons.save,
                  onTap: _handleSaveAndStartNew,
                ),
                const SizedBox(height: 16),
                // Convert to SOAP Notes
                _buildOptionCard(
                  title: 'Convert to SOAP Notes',
                  subtitle: 'Convert transcript to structured SOAP format',
                  icon: Icons.description,
                  onTap: _handleConvertToSoap,
                ),
                const SizedBox(height: 16),
                // Save as Template
                _buildOptionCard(
                  title: 'Save as Template',
                  subtitle: 'Save current transcript as a reusable template',
                  icon: Icons.bookmark,
                  onTap: () {
                    Navigator.of(context).pushNamed('/save-as-template');
                  },
                ),
                const SizedBox(height: 16),
                // Diarization Mode Toggle
                _buildDiarizationCard(recordingProvider),
                const SizedBox(height: 16),
                // Network Test
                _buildOptionCard(
                  title: 'Network Test',
                  subtitle: 'Test network connectivity and diagnose issues',
                  icon: Icons.network_check,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NetworkTestScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Send to Email
                _buildSendEmailCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF4A90E2),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiarizationCard(RecordingProvider recordingProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people,
                color: Color(0xFF4A90E2),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diarization Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Identify different speakers in the recording',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: recordingProvider.diarizationMode,
              onChanged: (value) {
                recordingProvider.toggleDiarizationMode();
              },
              activeTrackColor: const Color(0xFF4A90E2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendEmailCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.email,
                    color: Color(0xFF4A90E2),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send to Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Send transcript to email address',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSendEmail,
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
