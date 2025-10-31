import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/deepgram_service.dart';
import '../services/audio_recording_service.dart';

class RecordingProvider with ChangeNotifier {
  String _transcript = '';
  bool _isRecording = false;
  bool _diarizationMode = false;
  List<Map<String, dynamic>> _savedNotes = [];
  List<Map<String, dynamic>> _templates = [];
  String? _currentSoapNote;
  String _interimTranscript = '';

  // Services
  final DeepgramService _deepgramService = DeepgramService();
  final AudioRecordingService _audioService = AudioRecordingService();
  
  // Stream subscriptions
  StreamSubscription? _transcriptSubscription;
  StreamSubscription? _audioStreamSubscription;

  String get transcript => _transcript;
  bool get isRecording => _isRecording;
  bool get diarizationMode => _diarizationMode;
  List<Map<String, dynamic>> get savedNotes => _savedNotes;
  List<Map<String, dynamic>> get templates => _templates;
  String? get currentSoapNote => _currentSoapNote;
  String get interimTranscript => _interimTranscript;

  RecordingProvider() {
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString('savedNotes');
      final templatesJson = prefs.getString('templates');
      
      if (notesJson != null) {
        _savedNotes = List<Map<String, dynamic>>.from(json.decode(notesJson));
      }
      
      if (templatesJson != null) {
        _templates = List<Map<String, dynamic>>.from(json.decode(templatesJson));
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Load saved data error: $e');
      }
    }
  }

  Future<void> startRecording() async {
    try {
      if (kDebugMode) {
        debugPrint('🎬 [RecordingProvider] Starting recording process...');
      }

      // Check and request permissions
      if (!await _audioService.hasPermission()) {
        if (kDebugMode) {
          debugPrint('🔐 [RecordingProvider] Requesting microphone permissions...');
        }
        final granted = await _audioService.requestPermissions();
        if (!granted) {
          if (kDebugMode) {
            debugPrint('❌ [RecordingProvider] Microphone permission denied');
          }
          throw Exception('Microphone permission required');
        }
        if (kDebugMode) {
          debugPrint('✅ [RecordingProvider] Microphone permission granted');
        }
      }

      if (kDebugMode) {
        debugPrint('🌐 [RecordingProvider] Starting Deepgram connection...');
      }

      // Start Deepgram connection
      await _deepgramService.startRealTimeTranscription(
        diarization: _diarizationMode,
      );

      if (kDebugMode) {
        debugPrint('📡 [RecordingProvider] Setting up transcript stream listener...');
      }

      // Listen to transcript updates
      _transcriptSubscription = _deepgramService.transcriptStream.listen(
        (transcript) {
          if (kDebugMode) {
            debugPrint('📝 [RecordingProvider] Received transcript update: "$transcript"');
          }
          _interimTranscript = transcript;
          notifyListeners();
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ [RecordingProvider] Transcript stream error: $error');
          }
          stopRecording();
        },
      );

      if (kDebugMode) {
        debugPrint('🎤 [RecordingProvider] Starting audio recording and streaming...');
      }

      // Start audio recording and streaming
      final started = await _audioService.startRecording(streamAudio: true);
      if (!started) {
        if (kDebugMode) {
          debugPrint('❌ [RecordingProvider] Failed to start audio recording');
        }
        throw Exception('Failed to start audio recording');
      }

      if (kDebugMode) {
        debugPrint('🌊 [RecordingProvider] Setting up audio stream listener...');
      }

      // Stream audio data to Deepgram
      _audioStreamSubscription = _audioService.audioStream.listen(
        (audioData) {
          if (kDebugMode) {
            debugPrint('🎵 [RecordingProvider] Sending audio data to Deepgram: ${audioData.length} bytes');
          }
          _deepgramService.sendAudioData(audioData);
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ [RecordingProvider] Audio stream error: $error');
          }
          stopRecording();
        },
      );

      _isRecording = true;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('✅ [RecordingProvider] Real-time recording started successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [RecordingProvider] Error starting recording: $e');
      }
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopRecording() async {
    try {
      if (kDebugMode) {
        debugPrint('🛑 [RecordingProvider] Stopping recording process...');
      }

      _isRecording = false;
      
      if (kDebugMode) {
        debugPrint('🎤 [RecordingProvider] Stopping audio recording...');
      }
      // Stop audio recording
      await _audioService.stopRecording();
      
      if (kDebugMode) {
        debugPrint('🌐 [RecordingProvider] Stopping Deepgram connection...');
      }
      // Stop Deepgram connection
      await _deepgramService.stopTranscription();
      
      if (kDebugMode) {
        debugPrint('🔌 [RecordingProvider] Canceling stream subscriptions...');
      }
      // Cancel subscriptions
      await _transcriptSubscription?.cancel();
      await _audioStreamSubscription?.cancel();
      _transcriptSubscription = null;
      _audioStreamSubscription = null;
      
      // Add interim transcript to main transcript if it exists
      if (_interimTranscript.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('📝 [RecordingProvider] Adding interim transcript to main transcript: "$_interimTranscript"');
        }
        appendTranscript(_interimTranscript);
        _interimTranscript = '';
      }
      
      notifyListeners();
      
      if (kDebugMode) {
        debugPrint('✅ [RecordingProvider] Recording stopped successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [RecordingProvider] Error stopping recording: $e');
      }
      _isRecording = false;
      notifyListeners();
    }
  }

  void updateTranscript(String text) {
    _transcript = text;
    notifyListeners();
  }

  void appendTranscript(String text) {
    if (_transcript.isEmpty) {
      _transcript = text;
    } else {
      _transcript += '\n$text';
    }
    notifyListeners();
  }

  void clearTranscript() {
    _transcript = '';
    _currentSoapNote = null;
    notifyListeners();
  }

  void toggleDiarizationMode() {
    _diarizationMode = !_diarizationMode;
    notifyListeners();
  }

  Future<bool> saveNote({String? title, String? customTranscript}) async {
    try {
      final noteToSave = customTranscript ?? _transcript;
      if (noteToSave.isEmpty) return false;

      final note = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title ?? 'Note ${DateTime.now().toString().split(' ')[0]}',
        'content': noteToSave,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'transcript',
      };

      _savedNotes.insert(0, note);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedNotes', json.encode(_savedNotes));
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Save note error: $e');
      }
      return false;
    }
  }

  Future<bool> saveSoapNote(String soapNote) async {
    try {
      if (soapNote.isEmpty) return false;

      final note = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': 'SOAP Note ${DateTime.now().toString().split(' ')[0]}',
        'content': soapNote,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'soap',
      };

      _savedNotes.insert(0, note);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedNotes', json.encode(_savedNotes));
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Save SOAP note error: $e');
      }
      return false;
    }
  }

  Future<String> convertToSoapNote() async {
    try {
      // Simulate API call to LLM for SOAP conversion
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock SOAP note conversion
      _currentSoapNote = '''SOAP Note

S (Subjective):
${_transcript.split('\n').take(2).join('\n')}

O (Objective):
• Vital signs: Within normal limits
• Physical examination: Unremarkable

A (Assessment):
• Diagnosis based on presented symptoms

P (Plan):
• Follow-up in 2 weeks
• Continue current treatment plan
''';
      
      notifyListeners();
      return _currentSoapNote!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Convert to SOAP error: $e');
      }
      return 'Error converting to SOAP note';
    }
  }

  Future<bool> saveTemplate({
    required String templateName,
    required String categoryName,
    String? content,
  }) async {
    try {
      final template = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': templateName,
        'category': categoryName,
        'content': content ?? _transcript,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _templates.insert(0, template);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('templates', json.encode(_templates));
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Save template error: $e');
      }
      return false;
    }
  }

  Future<bool> sendTranscriptToEmail(String email) async {
    try {
      // Simulate API call to send email
      await Future.delayed(const Duration(seconds: 1));
      
      if (kDebugMode) {
        debugPrint('Transcript sent to email: $email');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Send email error: $e');
      }
      return false;
    }
  }

  List<String> getCategories() {
    final categories = _templates.map((t) => t['category'] as String).toSet().toList();
    return categories;
  }

  @override
  void dispose() {
    // Clean up subscriptions and services
    _transcriptSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _deepgramService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
