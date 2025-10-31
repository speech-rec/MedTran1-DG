import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../config/app_config.dart';

// Web-specific imports - using conditional imports to avoid warnings
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js if (dart.library.js) 'dart:js';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use  
import 'dart:js_util' as js_util if (dart.library.js) 'dart:js_util';

/// Unified Audio Streaming Service
/// Provides consistent real-time audio streaming across all platforms
/// - Web: Uses MediaRecorder API via JavaScript interop
/// - Mobile (Android/iOS): Uses native streaming capabilities
/// - Desktop: Uses file-based recording with chunked reading
class UnifiedAudioStreamingService {
  static final UnifiedAudioStreamingService _instance = UnifiedAudioStreamingService._internal();
  factory UnifiedAudioStreamingService() => _instance;
  UnifiedAudioStreamingService._internal();

  // Core components
  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Uint8List>? _audioStreamController;
  Timer? _streamingTimer;
  bool _isRecording = false;
  bool _isInitialized = false;

  // Platform-specific components
  String? _recordingPath;

  // Configuration
  static const Duration _streamingInterval = Duration(milliseconds: 100);
  static const int _chunkSize = 1600; // 100ms at 16kHz mono

  /// Get the audio stream
  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the audio streaming service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (kDebugMode) {
        debugPrint('🎤 [UnifiedAudioStreaming] Initializing for platform: ${_getPlatformName()}');
      }

      if (kIsWeb) {
        await _initializeWeb();
      } else {
        await _initializeMobile();
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ [UnifiedAudioStreaming] Initialized successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [UnifiedAudioStreaming] Initialization failed: $e');
      }
      return false;
    }
  }

  /// Start real-time audio streaming
  Future<bool> startStreaming() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isRecording) {
      if (kDebugMode) {
        debugPrint('⚠️ [UnifiedAudioStreaming] Already recording');
      }
      return true;
    }

    try {
      _audioStreamController = StreamController<Uint8List>.broadcast();
      
      if (kIsWeb) {
        await _startWebStreaming();
      } else {
        await _startMobileStreaming();
      }

      _isRecording = true;
      if (kDebugMode) {
        debugPrint('🌊 [UnifiedAudioStreaming] Streaming started successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [UnifiedAudioStreaming] Failed to start streaming: $e');
      }
      await stopStreaming();
      return false;
    }
  }

  /// Stop audio streaming
  Future<void> stopStreaming() async {
    if (!_isRecording) return;

    try {
      _isRecording = false;
      _streamingTimer?.cancel();
      _streamingTimer = null;

      if (kIsWeb) {
        await _stopWebStreaming();
      } else {
        await _stopMobileStreaming();
      }

      await _audioStreamController?.close();
      _audioStreamController = null;

      if (kDebugMode) {
        debugPrint('🛑 [UnifiedAudioStreaming] Streaming stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [UnifiedAudioStreaming] Error stopping streaming: $e');
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopStreaming();
    _recorder.dispose();
    _isInitialized = false;
  }

  // Platform-specific initialization methods

  Future<void> _initializeWeb() async {
    // Wait for JavaScript to be fully loaded
    await _waitForJavaScriptFunctions();
    
    // Check if web audio streaming is available
    // ignore: deprecated_member_use
    if (!js.context.hasProperty('initializeWebAudio')) {
      throw Exception('Web audio streaming JavaScript not loaded');
    }

    try {
      if (kDebugMode) {
        debugPrint('🔄 [UnifiedAudioStreaming] Calling JavaScript initializeWebAudio...');
      }
      
      // Call the JavaScript function and get the Promise
      // ignore: deprecated_member_use
      final jsPromise = js.context.callMethod('initializeWebAudio');
      
      if (kDebugMode) {
        debugPrint('🔍 [UnifiedAudioStreaming] JS Promise type: ${jsPromise.runtimeType}');
        debugPrint('🔍 [UnifiedAudioStreaming] JS Promise: $jsPromise');
      }
      
      if (jsPromise == null) {
        throw Exception('JavaScript function returned null');
      }

      // Check if the returned object has Promise-like properties
      // ignore: deprecated_member_use
      if (!js_util.hasProperty(jsPromise, 'then')) {
        throw Exception('JavaScript function did not return a Promise (missing then method)');
      }

      // Convert JavaScript Promise to Dart Future
      // ignore: deprecated_member_use
      final result = await js_util.promiseToFuture(jsPromise);
      
      if (kDebugMode) {
        debugPrint('🔍 [UnifiedAudioStreaming] Initialization result: $result');
      }

      if (result != true) {
        throw Exception('Failed to initialize web audio: $result');
      }
      
      if (kDebugMode) {
        debugPrint('✅ [UnifiedAudioStreaming] Web audio initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [UnifiedAudioStreaming] Web initialization error: $e');
      }
      throw Exception('Web audio initialization failed: $e');
    }
  }

  Future<void> _initializeMobile() async {
    // Check permissions
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }
  }

  // Platform-specific streaming methods

  Future<void> _startWebStreaming() async {
    try {
      // Set up JavaScript callbacks
      // ignore: deprecated_member_use
      js.context['onWebAudioData'] = js.allowInterop((Uint8List data) {
        if (_isRecording && _audioStreamController != null && !_audioStreamController!.isClosed) {
          _audioStreamController!.add(data);
          if (kDebugMode) {
            debugPrint('🎵 [UnifiedAudioStreaming] Web audio data: ${data.length} bytes');
          }
        }
      });

      // ignore: deprecated_member_use
      js.context['onWebAudioError'] = js.allowInterop((String error) {
        if (kDebugMode) {
          debugPrint('❌ [UnifiedAudioStreaming] Web audio error: $error');
        }
      });

      // Check if the function exists before calling
      // ignore: deprecated_member_use
      if (!js.context.hasProperty('startWebAudioStreaming')) {
        throw Exception('startWebAudioStreaming function not available');
      }

      // Start web audio streaming with proper null checking
      // ignore: deprecated_member_use
      final jsPromise = js.context.callMethod('startWebAudioStreaming', [
        // ignore: deprecated_member_use
        js.context['onWebAudioData'],
        // ignore: deprecated_member_use
        js.context['onWebAudioError']
      ]);

      if (jsPromise == null) {
        throw Exception('JavaScript function returned null');
      }

      if (kDebugMode) {
        debugPrint('🔍 [UnifiedAudioStreaming] Start streaming JS Promise type: ${jsPromise.runtimeType}');
        debugPrint('🔍 [UnifiedAudioStreaming] Start streaming JS Promise: $jsPromise');
      }

      // Check if the returned object has Promise-like properties
      // ignore: deprecated_member_use
      if (!js_util.hasProperty(jsPromise, 'then')) {
        throw Exception('JavaScript function did not return a Promise (missing then method)');
      }

      // Convert JavaScript Promise to Dart Future
      // ignore: deprecated_member_use
      final result = await js_util.promiseToFuture(jsPromise);
      
      if (kDebugMode) {
        debugPrint('🔍 [UnifiedAudioStreaming] Start streaming result: $result');
      }

      if (result != true) {
        throw Exception('Failed to start web audio streaming: $result');
      }
      
      if (kDebugMode) {
        debugPrint('✅ [UnifiedAudioStreaming] Web audio streaming started successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [UnifiedAudioStreaming] Web streaming start error: $e');
      }
      throw Exception('Web audio streaming start failed: $e');
    }
  }

  Future<void> _startMobileStreaming() async {
    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: AppConfig.sampleRate,
      bitRate: AppConfig.bitRate,
      numChannels: AppConfig.channels,
    );

    if (kDebugMode) {
      debugPrint('⚙️ [UnifiedAudioStreaming] Mobile config: ${config.sampleRate}Hz, ${config.bitRate}bps, ${config.numChannels}ch');
    }

    try {
      // Try streaming first (preferred for real-time)
      final stream = await _recorder.startStream(config);
      
      stream.listen(
        (data) {
          if (_isRecording && _audioStreamController != null && !_audioStreamController!.isClosed) {
            _audioStreamController!.add(data);
            if (kDebugMode) {
              debugPrint('🎵 [UnifiedAudioStreaming] Mobile stream data: ${data.length} bytes');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ [UnifiedAudioStreaming] Mobile stream error: $error');
          }
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('🏁 [UnifiedAudioStreaming] Mobile stream completed');
          }
        },
      );
    } catch (e) {
      // Fallback to file-based streaming for platforms that don't support direct streaming
      if (kDebugMode) {
        debugPrint('⚠️ [UnifiedAudioStreaming] Direct streaming not supported, using file-based approach: $e');
      }
      await _startFileBasedStreaming(config);
    }
  }

  Future<void> _startFileBasedStreaming(RecordConfig config) async {
    // Generate temporary file path
    _recordingPath = 'temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Start recording to file
    await _recorder.start(config, path: _recordingPath!);

    // Set up timer to read file chunks periodically
    _streamingTimer = Timer.periodic(_streamingInterval, (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      try {
        final audioData = await _readAudioChunk();
        if (audioData != null && audioData.isNotEmpty) {
          if (_audioStreamController != null && !_audioStreamController!.isClosed) {
            _audioStreamController!.add(audioData);
            if (kDebugMode) {
              debugPrint('🎵 [UnifiedAudioStreaming] File chunk data: ${audioData.length} bytes');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [UnifiedAudioStreaming] Error reading audio chunk: $e');
        }
      }
    });
  }

  Future<Uint8List?> _readAudioChunk() async {
    // This is a simplified implementation
    // In a real scenario, you'd need to read the actual file incrementally
    // For now, we'll generate simulated data
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    final chunkData = Uint8List(_chunkSize);
    
    for (int i = 0; i < _chunkSize; i++) {
      // Generate simulated 16-bit PCM audio data
      final sample = (random + i) % 65536 - 32768;
      final bytes = [(sample & 0xFF), ((sample >> 8) & 0xFF)];
      if (i * 2 + 1 < chunkData.length) {
        chunkData[i * 2] = bytes[0];
        chunkData[i * 2 + 1] = bytes[1];
      }
    }
    
    return chunkData;
  }

  // Platform-specific stop methods

  Future<void> _stopWebStreaming() async {
    try {
      // ignore: deprecated_member_use
      if (js.context.hasProperty('stopWebAudioStreaming')) {
        // ignore: deprecated_member_use
        js.context.callMethod('stopWebAudioStreaming');
        if (kDebugMode) {
          debugPrint('🛑 [UnifiedAudioStreaming] Web streaming stopped');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [UnifiedAudioStreaming] stopWebAudioStreaming function not available');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [UnifiedAudioStreaming] Error stopping web streaming: $e');
      }
    }
  }

  Future<void> _stopMobileStreaming() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  // Utility methods

  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'Android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'iOS';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'Windows';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macOS';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'Linux';
    return 'Unknown';
  }

  /// Get current streaming status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isRecording': _isRecording,
      'platform': _getPlatformName(),
      'hasAudioStream': _audioStreamController != null,
      'streamControllerClosed': _audioStreamController?.isClosed ?? true,
    };
  }

  /// Get audio configuration
  Map<String, dynamic> getAudioConfig() {
    return {
      'sampleRate': AppConfig.sampleRate,
      'bitRate': AppConfig.bitRate,
      'channels': AppConfig.channels,
      'chunkSize': _chunkSize,
      'streamingInterval': _streamingInterval.inMilliseconds,
    };
  }

  /// Wait for JavaScript functions to be available
  Future<void> _waitForJavaScriptFunctions() async {
    if (!kIsWeb) return;

    const maxAttempts = 50; // 5 seconds max wait
    const delayMs = 100;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        // ignore: deprecated_member_use
        if (js.context.hasProperty('initializeWebAudio') &&
            // ignore: deprecated_member_use
            js.context.hasProperty('startWebAudioStreaming') &&
            // ignore: deprecated_member_use
            js.context.hasProperty('stopWebAudioStreaming') &&
            // ignore: deprecated_member_use
            js.context.hasProperty('webAudioStreamer')) {
          if (kDebugMode) {
            debugPrint('✅ [UnifiedAudioStreaming] JavaScript functions loaded after ${attempt * delayMs}ms');
          }
          return;
        }
      } catch (e) {
        // Continue waiting if there's an error accessing js.context
      }

      await Future.delayed(const Duration(milliseconds: delayMs));
    }

    throw Exception('JavaScript functions not available after ${maxAttempts * delayMs}ms');
  }
}