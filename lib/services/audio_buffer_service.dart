import 'dart:async';

import 'package:flutter/foundation.dart';

/// Audio Buffer Service for real-time audio processing and optimization
/// 
/// This service handles:
/// - Audio data buffering and chunking
/// - Format conversion and optimization
/// - Quality enhancement for speech recognition
/// - Adaptive buffering based on network conditions
class AudioBufferService {
  static const int _defaultChunkSize = 4096; // 4KB chunks
  static const int _maxBufferSize = 32768; // 32KB max buffer
  static const int _minChunkSize = 1024; // 1KB minimum
  static const Duration _bufferTimeout = Duration(milliseconds: 100);
  
  final StreamController<Uint8List> _processedAudioController = StreamController<Uint8List>.broadcast();
  final List<int> _audioBuffer = [];
  
  Timer? _bufferTimer;
  int _chunkSize = _defaultChunkSize;
  int _totalBytesProcessed = 0;
  int _chunksProcessed = 0;
  bool _isProcessing = false;
  
  // Performance metrics
  double _averageChunkSize = 0;
  double _processingLatency = 0;
  
  /// Stream of processed audio chunks optimized for Deepgram
  Stream<Uint8List> get processedAudioStream => _processedAudioController.stream;
  
  /// Current buffer size in bytes
  int get bufferSize => _audioBuffer.length;
  
  /// Total bytes processed since start
  int get totalBytesProcessed => _totalBytesProcessed;
  
  /// Number of chunks processed
  int get chunksProcessed => _chunksProcessed;
  
  /// Current processing latency in milliseconds
  double get processingLatency => _processingLatency;
  
  /// Average chunk size being processed
  double get averageChunkSize => _averageChunkSize;
  
  /// Whether the service is currently processing audio
  bool get isProcessing => _isProcessing;
  
  /// Initialize the audio buffer service
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('🔧 [AudioBufferService] Initializing audio buffer service...');
    }
    
    _resetMetrics();
    _startBufferTimer();
    
    if (kDebugMode) {
      debugPrint('✅ [AudioBufferService] Audio buffer service initialized');
      debugPrint('📊 [AudioBufferService] Chunk size: $_chunkSize bytes');
      debugPrint('📊 [AudioBufferService] Max buffer: $_maxBufferSize bytes');
      debugPrint('📊 [AudioBufferService] Buffer timeout: ${_bufferTimeout.inMilliseconds}ms');
    }
  }
  
  /// Process incoming raw audio data
  Future<void> processAudioData(Uint8List audioData) async {
    if (!_isProcessing) return;
    
    final startTime = DateTime.now();
    
    try {
      // Add to buffer
      _audioBuffer.addAll(audioData);
      
      if (kDebugMode && _audioBuffer.length > _maxBufferSize) {
        debugPrint('⚠️ [AudioBufferService] Buffer size exceeded: ${_audioBuffer.length} bytes');
      }
      
      // Process buffer if it's large enough or if we're approaching max size
      if (_audioBuffer.length >= _chunkSize || _audioBuffer.length >= _maxBufferSize) {
        await _processBuffer();
      }
      
      // Update processing latency
      final processingTime = DateTime.now().difference(startTime);
      _processingLatency = (_processingLatency + processingTime.inMicroseconds / 1000) / 2;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioBufferService] Error processing audio data: $e');
      }
    }
  }
  
  /// Start audio processing
  void startProcessing() {
    if (_isProcessing) return;
    
    _isProcessing = true;
    _resetMetrics();
    _startBufferTimer();
    
    if (kDebugMode) {
      debugPrint('▶️ [AudioBufferService] Started audio processing');
    }
  }
  
  /// Stop audio processing and flush remaining buffer
  Future<void> stopProcessing() async {
    if (!_isProcessing) return;
    
    _isProcessing = false;
    _bufferTimer?.cancel();
    _bufferTimer = null;
    
    // Flush remaining buffer
    if (_audioBuffer.isNotEmpty) {
      await _processBuffer(forceFlush: true);
    }
    
    if (kDebugMode) {
      debugPrint('⏹️ [AudioBufferService] Stopped audio processing');
      debugPrint('📊 [AudioBufferService] Final stats:');
      debugPrint('   Total bytes: $_totalBytesProcessed');
      debugPrint('   Chunks processed: $_chunksProcessed');
      debugPrint('   Avg chunk size: ${_averageChunkSize.toStringAsFixed(2)} bytes');
      debugPrint('   Avg latency: ${_processingLatency.toStringAsFixed(2)}ms');
    }
  }
  
  /// Adjust chunk size based on network conditions
  void adjustChunkSize({required double networkLatency, required bool isStable}) {
    int newChunkSize;
    
    if (networkLatency > 200) {
      // High latency - use larger chunks
      newChunkSize = (_chunkSize * 1.5).round();
    } else if (networkLatency < 50 && isStable) {
      // Low latency and stable - use smaller chunks for better responsiveness
      newChunkSize = (_chunkSize * 0.8).round();
    } else {
      // Keep current size
      newChunkSize = _chunkSize;
    }
    
    // Clamp to valid range
    newChunkSize = newChunkSize.clamp(_minChunkSize, _maxBufferSize ~/ 2);
    
    if (newChunkSize != _chunkSize) {
      if (kDebugMode) {
        debugPrint('📊 [AudioBufferService] Adjusted chunk size: $_chunkSize -> $newChunkSize bytes');
        debugPrint('📊 [AudioBufferService] Network latency: ${networkLatency.toStringAsFixed(2)}ms, stable: $isStable');
      }
      _chunkSize = newChunkSize;
    }
  }
  
  /// Get current performance metrics
  Map<String, dynamic> getMetrics() {
    return {
      'bufferSize': _audioBuffer.length,
      'totalBytesProcessed': _totalBytesProcessed,
      'chunksProcessed': _chunksProcessed,
      'averageChunkSize': _averageChunkSize,
      'processingLatency': _processingLatency,
      'currentChunkSize': _chunkSize,
      'isProcessing': _isProcessing,
      'bufferUtilization': _audioBuffer.length / _maxBufferSize,
    };
  }
  
  /// Process the current buffer
  Future<void> _processBuffer({bool forceFlush = false}) async {
    if (_audioBuffer.isEmpty) return;
    
    final int bytesToProcess = forceFlush 
        ? _audioBuffer.length 
        : (_audioBuffer.length ~/ _chunkSize) * _chunkSize;
    
    if (bytesToProcess < _minChunkSize && !forceFlush) return;
    
    try {
      // Extract chunk from buffer
      final chunk = Uint8List.fromList(_audioBuffer.take(bytesToProcess).toList());
      _audioBuffer.removeRange(0, bytesToProcess);
      
      // Apply audio processing optimizations
      final processedChunk = _optimizeAudioChunk(chunk);
      
      // Send processed chunk
      if (!_processedAudioController.isClosed) {
        _processedAudioController.add(processedChunk);
      }
      
      // Update metrics
      _totalBytesProcessed += processedChunk.length;
      _chunksProcessed++;
      _averageChunkSize = (_averageChunkSize * (_chunksProcessed - 1) + processedChunk.length) / _chunksProcessed;
      
      if (kDebugMode && _chunksProcessed % 10 == 0) {
        debugPrint('📊 [AudioBufferService] Processed chunk #$_chunksProcessed: ${processedChunk.length} bytes');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioBufferService] Error processing buffer: $e');
      }
    }
  }
  
  /// Optimize audio chunk for speech recognition
  Uint8List _optimizeAudioChunk(Uint8List chunk) {
    try {
      // Ensure chunk is properly formatted for Deepgram
      // Convert to 16-bit PCM if needed and apply basic audio processing
      
      final List<int> optimizedData = [];
      
      // Process in 16-bit samples (2 bytes per sample)
      for (int i = 0; i < chunk.length - 1; i += 2) {
        // Read 16-bit little-endian sample
        int sample = chunk[i] | (chunk[i + 1] << 8);
        
        // Convert to signed 16-bit
        if (sample > 32767) sample -= 65536;
        
        // Apply basic noise gate (remove very quiet samples)
        if (sample.abs() < 100) {
          sample = 0;
        }
        
        // Apply gentle compression to normalize levels
        if (sample > 0) {
          sample = (sample * 0.9).round();
        } else if (sample < 0) {
          sample = (sample * 0.9).round();
        }
        
        // Clamp to valid range
        sample = sample.clamp(-32768, 32767);
        
        // Convert back to unsigned and add to output
        if (sample < 0) sample += 65536;
        optimizedData.add(sample & 0xFF);
        optimizedData.add((sample >> 8) & 0xFF);
      }
      
      return Uint8List.fromList(optimizedData);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [AudioBufferService] Error optimizing audio chunk: $e');
      }
      // Return original chunk if optimization fails
      return chunk;
    }
  }
  
  /// Start the buffer timeout timer
  void _startBufferTimer() {
    _bufferTimer?.cancel();
    _bufferTimer = Timer.periodic(_bufferTimeout, (timer) {
      if (_isProcessing && _audioBuffer.isNotEmpty) {
        _processBuffer();
      }
    });
  }
  
  /// Reset performance metrics
  void _resetMetrics() {
    _totalBytesProcessed = 0;
    _chunksProcessed = 0;
    _averageChunkSize = 0;
    _processingLatency = 0;
    _audioBuffer.clear();
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await stopProcessing();
    await _processedAudioController.close();
    
    if (kDebugMode) {
      debugPrint('🗑️ [AudioBufferService] Audio buffer service disposed');
    }
  }
}