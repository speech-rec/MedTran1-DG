import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../config/app_config.dart';
import 'services.dart';

/// Enhanced Audio Recording Service with cross-platform streaming support
/// Provides real-time audio streaming for speech-to-text applications
class AudioRecordingService {
  static final AudioRecordingService _instance = AudioRecordingService._internal();
  factory AudioRecordingService() => _instance;
  AudioRecordingService._internal();

  // Core components
  final AudioRecorder _recorder = AudioRecorder();
  final UnifiedAudioStreamingService _unifiedStreaming = UnifiedAudioStreamingService();
  final AudioBufferService _audioBuffer = AudioBufferService();
  
  // State management
  bool _isRecording = false;
  bool _isInitialized = false;
  String? _currentRecordingPath;
  
  // Stream controllers
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription<Uint8List>? _streamSubscription;
  StreamSubscription<Uint8List>? _bufferSubscription;
  
  // Error handling
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  
  // Performance monitoring
  int _totalBytesProcessed = 0;
  DateTime? _recordingStartTime;
  Timer? _performanceTimer;

  // Getters
  Stream<Uint8List> get audioStream => _audioStreamController?.stream ?? const Stream.empty();
  Stream<String> get errorStream => _errorController.stream;
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
  String? get currentRecordingPath => _currentRecordingPath;
  
  // Performance metrics
  int get totalBytesProcessed => _totalBytesProcessed;
  Duration? get recordingDuration => _recordingStartTime != null 
      ? DateTime.now().difference(_recordingStartTime!) 
      : null;

  /// Initialize the audio recording service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (kDebugMode) {
        debugPrint('🎤 [AudioRecordingService] Initializing enhanced service...');
      }

      // Initialize unified streaming service
      final streamingInitialized = await _unifiedStreaming.initialize();
      if (!streamingInitialized) {
        throw Exception('Failed to initialize unified streaming service');
      }

      // Initialize audio buffer service
      await _audioBuffer.initialize();

      // Check permissions
      await _ensurePermissions();

      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ [AudioRecordingService] Enhanced service initialized successfully');
        debugPrint('📊 [AudioRecordingService] Audio buffer service ready');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioRecordingService] Initialization failed: $e');
      }
      _errorController.add('Initialization failed: $e');
      return false;
    }
  }

  /// Enhanced stop recording with proper cleanup and error handling
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      if (kDebugMode) {
        debugPrint('⚠️ [AudioRecordingService] Not currently recording');
      }
      return _currentRecordingPath;
    }

    try {
      if (kDebugMode) {
        debugPrint('🛑 [AudioRecordingService] Stopping enhanced recording...');
      }

      _isRecording = false;

      // Stop performance monitoring
      _performanceTimer?.cancel();
      _performanceTimer = null;

      // Stop unified streaming
      await _unifiedStreaming.stopStreaming();

      // Cancel stream subscriptions
      await _streamSubscription?.cancel();
      _streamSubscription = null;

      await _bufferSubscription?.cancel();
      _bufferSubscription = null;

      // Stop and cleanup audio buffer
      await _audioBuffer.stopProcessing();

      // Close audio stream controller
      await _audioStreamController?.close();
      _audioStreamController = null;

      // Stop traditional recorder if it was used
      String? recordingPath;
      if (await _recorder.isRecording()) {
        recordingPath = await _recorder.stop();
      }

      // Log performance metrics
      if (kDebugMode && _recordingStartTime != null) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        final avgBytesPerSecond = _totalBytesProcessed / duration.inSeconds;
        debugPrint('📊 [AudioRecordingService] Recording completed:');
        debugPrint('   Duration: ${duration.inSeconds}s');
        debugPrint('   Total bytes: $_totalBytesProcessed');
        debugPrint('   Avg bytes/sec: ${avgBytesPerSecond.toStringAsFixed(2)}');
      }

      _recordingStartTime = null;
      _totalBytesProcessed = 0;

      if (kDebugMode) {
        debugPrint('✅ [AudioRecordingService] Enhanced recording stopped successfully');
      }

      return recordingPath ?? _currentRecordingPath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioRecordingService] Error stopping recording: $e');
      }
      _errorController.add('Error stopping recording: $e');
      return null;
    }
  }

  // Helper methods

  /// Handle incoming audio data with processing and forwarding
  Future<void> _handleAudioData(Uint8List audioData) async {
    if (!_isRecording || _audioStreamController == null || _audioStreamController!.isClosed) {
      return;
    }

    try {
      // Update performance metrics
      _totalBytesProcessed += audioData.length;

      // Process audio through buffer service for optimization
      await _audioBuffer.processAudioData(audioData);

      // Forward processed audio data to stream
      _audioStreamController!.add(audioData);

      if (kDebugMode) {
        debugPrint('🎵 [AudioRecordingService] Processed audio: ${audioData.length} bytes (total: $_totalBytesProcessed)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioRecordingService] Error handling audio data: $e');
      }
      _errorController.add('Error processing audio data: $e');
    }
  }

  /// Start performance monitoring
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      if (kDebugMode && _recordingStartTime != null) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        final avgBytesPerSecond = duration.inSeconds > 0 
            ? _totalBytesProcessed / duration.inSeconds 
            : 0;
        
        debugPrint('📊 [AudioRecordingService] Performance update:');
        debugPrint('   Duration: ${duration.inSeconds}s');
        debugPrint('   Total bytes: $_totalBytesProcessed');
        debugPrint('   Avg bytes/sec: ${avgBytesPerSecond.toStringAsFixed(2)}');
        debugPrint('   Unified streaming status: ${_unifiedStreaming.getStatus()}');
      }
    });
  }

  /// Start file-based recording (fallback method)
  Future<void> _startFileRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    _currentRecordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    final config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: AppConfig.sampleRate,
      bitRate: AppConfig.bitRate,
      numChannels: AppConfig.channels,
    );

    await _recorder.start(config, path: _currentRecordingPath!);
    
    if (kDebugMode) {
      debugPrint('📁 [AudioRecordingService] File recording started: $_currentRecordingPath');
    }
  }

  /// Ensure proper permissions are granted
  Future<void> _ensurePermissions() async {
    if (!kIsWeb) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          throw Exception('Microphone permission not granted');
        }
      }
    }
  }

  /// Enhanced start recording with real-time streaming
  Future<bool> startRecording({bool streamAudio = true}) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isRecording) {
      if (kDebugMode) {
        debugPrint('⚠️ [AudioRecordingService] Already recording');
      }
      return true;
    }

    try {
      if (kDebugMode) {
        debugPrint('🎬 [AudioRecordingService] Starting enhanced recording (streaming: $streamAudio)...');
      }

      // Reset performance counters
      _totalBytesProcessed = 0;
      _recordingStartTime = DateTime.now();

      if (streamAudio) {
        // Use unified streaming service for real-time audio
        final streamingStarted = await _unifiedStreaming.startStreaming();
        if (!streamingStarted) {
          throw Exception('Failed to start unified streaming');
        }

        // Set up audio stream controller
        _audioStreamController = StreamController<Uint8List>.broadcast();

        // Subscribe to unified streaming service
        _streamSubscription = _unifiedStreaming.audioStream?.listen(
          (audioData) {
            _handleAudioData(audioData);
          },
          onError: (error) {
            if (kDebugMode) {
              debugPrint('❌ [AudioRecordingService] Stream error: $error');
            }
            _errorController.add('Audio stream error: $error');
          },
          onDone: () {
            if (kDebugMode) {
              debugPrint('🏁 [AudioRecordingService] Audio stream completed');
            }
          },
        );

        // Subscribe to buffered audio stream for optimized chunks
        _bufferSubscription = _audioBuffer.processedAudioStream.listen(
          (processedAudio) {
            // Forward optimized audio chunks to the main stream
            if (_audioStreamController != null && !_audioStreamController!.isClosed) {
              _audioStreamController!.add(processedAudio);
            }
          },
          onError: (error) {
            if (kDebugMode) {
              debugPrint('❌ [AudioRecordingService] Buffer stream error: $error');
            }
            _errorController.add('Audio buffer error: $error');
          },
        );

        // Start performance monitoring
        _startPerformanceMonitoring();

        if (kDebugMode) {
          debugPrint('✅ [AudioRecordingService] Enhanced streaming started successfully');
        }
      } else {
        // File-based recording for non-streaming scenarios
        await _startFileRecording();
      }

      _isRecording = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioRecordingService] Failed to start recording: $e');
      }
      _errorController.add('Failed to start recording: $e');
      await stopRecording();
      return false;
    }
  }

  /// Get current service status and diagnostics
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isRecording': _isRecording,
      'hasAudioStream': _audioStreamController != null,
      'streamControllerClosed': _audioStreamController?.isClosed ?? true,
      'totalBytesProcessed': _totalBytesProcessed,
      'recordingDuration': recordingDuration?.inSeconds ?? 0,
      'currentRecordingPath': _currentRecordingPath,
      'unifiedStreamingStatus': _unifiedStreaming.getStatus(),
      'audioBufferStatus': _audioBuffer.getMetrics(),
    };
  }

  /// Get audio configuration
  Map<String, dynamic> getAudioConfig() {
    return _unifiedStreaming.getAudioConfig();
  }

  /// Dispose resources and cleanup
  Future<void> dispose() async {
    await stopRecording();
    await _unifiedStreaming.dispose();
    await _audioBuffer.dispose();
    await _errorController.close();
    _recorder.dispose();
    _isInitialized = false;
  }

  // Legacy methods for backward compatibility

  /// Legacy method - use initialize() instead
  Future<bool> requestPermissions() async {
    return await initialize();
  }

  /// Legacy method - use isInitialized getter instead
  Future<bool> hasPermission() async {
    return _isInitialized;
  }

  /// Legacy method - use stopRecording() instead
  Future<void> pauseRecording() async {
    if (kDebugMode) {
      debugPrint('⚠️ [AudioRecordingService] pauseRecording() is deprecated, use stopRecording() instead');
    }
  }

  /// Legacy method - use startRecording() instead
  Future<void> resumeRecording() async {
    if (kDebugMode) {
      debugPrint('⚠️ [AudioRecordingService] resumeRecording() is deprecated, use startRecording() instead');
    }
  }

  /// Legacy method - use isInitialized getter instead
  Future<bool> isRecorderAvailable() async {
    return _isInitialized;
  }

  /// Legacy method for file cleanup
  Future<void> deleteRecording(String? path) async {
    if (path == null) return;
    
    try {
      if (!kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) {
            debugPrint('📁 [AudioRecordingService] Recording file deleted: $path');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioRecordingService] Error deleting recording file: $e');
      }
    }
  }

  /// Legacy method - audio data is now streamed automatically
  Future<Uint8List?> getAudioData() async {
    if (kDebugMode) {
      debugPrint('⚠️ [AudioRecordingService] getAudioData() is deprecated, use audioStream instead');
    }
    return null;
  }
}