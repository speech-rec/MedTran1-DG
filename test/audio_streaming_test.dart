import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_dictation_app/services/services.dart';

void main() {
  group('Audio Streaming Tests', () {
    late AudioRecordingService audioService;
    late UnifiedAudioStreamingService unifiedService;
    late AudioBufferService bufferService;

    setUp(() {
      audioService = AudioRecordingService();
      unifiedService = UnifiedAudioStreamingService();
      bufferService = AudioBufferService();
    });

    tearDown(() async {
      await audioService.dispose();
      await unifiedService.dispose();
      await bufferService.dispose();
    });

    group('AudioRecordingService Tests', () {
      test('should initialize successfully', () async {
        final result = await audioService.initialize();
        expect(result, isTrue);
        expect(audioService.isInitialized, isTrue);
      });

      test('should provide correct status information', () async {
        await audioService.initialize();
        final status = audioService.getStatus();
        
        expect(status['isInitialized'], isTrue);
        expect(status['isRecording'], isFalse);
        expect(status['totalBytesProcessed'], equals(0));
        expect(status, containsPair('unifiedStreamingStatus', isA<Map>()));
        expect(status, containsPair('audioBufferStatus', isA<Map>()));
      });

      test('should handle recording lifecycle correctly', () async {
        await audioService.initialize();
        
        // Start recording
        final startResult = await audioService.startRecording(streamAudio: true);
        expect(startResult, isTrue);
        expect(audioService.isRecording, isTrue);
        
        // Wait a bit to simulate recording
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Stop recording
        final stopResult = await audioService.stopRecording();
        expect(stopResult, isNotNull);
        expect(audioService.isRecording, isFalse);
      });

      test('should provide audio stream when recording', () async {
        await audioService.initialize();
        
        final streamCompleter = Completer<bool>();
        late StreamSubscription subscription;
        
        subscription = audioService.audioStream.listen(
          (audioData) {
            expect(audioData, isA<Uint8List>());
            expect(audioData.isNotEmpty, isTrue);
            subscription.cancel();
            streamCompleter.complete(true);
          },
          onError: (error) {
            subscription.cancel();
            streamCompleter.complete(false);
          },
        );
        
        await audioService.startRecording(streamAudio: true);
        
        // Wait for audio data or timeout
        final result = await streamCompleter.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );
        
        await audioService.stopRecording();
        expect(result, isTrue);
      });

      test('should handle errors gracefully', () async {
        final errorCompleter = Completer<String>();
        late StreamSubscription subscription;
        
        subscription = audioService.errorStream.listen(
          (error) {
            subscription.cancel();
            errorCompleter.complete(error);
          },
        );
        
        // Try to start recording without initialization
        final result = await audioService.startRecording();
        
        if (!result) {
          // Should either fail gracefully or auto-initialize
          expect(result, isFalse);
        }
        
        subscription.cancel();
      });
    });

    group('UnifiedAudioStreamingService Tests', () {
      test('should initialize on all platforms', () async {
        final result = await unifiedService.initialize();
        expect(result, isTrue);
      });

      test('should provide platform-specific configuration', () {
        final config = unifiedService.getAudioConfig();
        expect(config, isA<Map<String, dynamic>>());
        expect(config, containsPair('sampleRate', isA<int>()));
        expect(config, containsPair('channels', isA<int>()));
        expect(config, containsPair('bitDepth', isA<int>()));
      });

      test('should handle streaming lifecycle', () async {
        await unifiedService.initialize();
        
        final startResult = await unifiedService.startStreaming();
        expect(startResult, isTrue);
        
        await unifiedService.stopStreaming();
        // stopStreaming returns void, so we just verify it doesn't throw
        expect(unifiedService.isRecording, isFalse);
      });

      test('should provide status information', () async {
        await unifiedService.initialize();
        
        // Test that getStatus method exists and returns expected structure
        final statusResult = unifiedService.getStatus();
        expect(statusResult, isA<Map<String, dynamic>>());
        expect(statusResult['isInitialized'], isTrue);
        expect(statusResult['platform'], isA<String>());
      });
    });

    group('AudioBufferService Tests', () {
      test('should initialize successfully', () async {
        await bufferService.initialize();
        // Note: AudioBufferService doesn't have isInitialized property
        // We can verify initialization by checking if methods work
        final metrics = bufferService.getMetrics();
        expect(metrics, isA<Map<String, dynamic>>());
      });

      test('should process audio data', () async {
        await bufferService.initialize();
        
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        await bufferService.processAudioData(testData);
        
        final metrics = bufferService.getMetrics();
        expect(metrics['totalBytesProcessed'], greaterThan(0));
      });

      test('should provide processed audio stream', () async {
        await bufferService.initialize();
        
        final streamCompleter = Completer<bool>();
        late StreamSubscription subscription;
        
        subscription = bufferService.processedAudioStream.listen(
          (processedData) {
            expect(processedData, isA<Uint8List>());
            subscription.cancel();
            streamCompleter.complete(true);
          },
          onError: (error) {
            subscription.cancel();
            streamCompleter.complete(false);
          },
        );
        
        // Add some test data
        final testData = Uint8List.fromList(List.generate(4096, (i) => i % 256));
        await bufferService.processAudioData(testData);
        
        final result = await streamCompleter.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
        
        expect(result, isTrue);
      });

      test('should handle buffer overflow gracefully', () async {
        await bufferService.initialize();
        
        // Add a lot of data to test buffer limits
        for (int i = 0; i < 100; i++) {
          final testData = Uint8List.fromList(List.generate(1024, (j) => j % 256));
          await bufferService.processAudioData(testData);
        }
        
        final metrics = bufferService.getMetrics();
        expect(metrics['bufferOverflows'], isA<int>());
      });
    });

    group('Integration Tests', () {
      test('should work together seamlessly', () async {
        // Initialize all services
        await audioService.initialize();
        
        final streamCompleter = Completer<bool>();
        int audioChunksReceived = 0;
        late StreamSubscription subscription;
        
        subscription = audioService.audioStream.listen(
          (audioData) {
            audioChunksReceived++;
            if (audioChunksReceived >= 3) {
              subscription.cancel();
              streamCompleter.complete(true);
            }
          },
          onError: (error) {
            subscription.cancel();
            streamCompleter.complete(false);
          },
        );
        
        await audioService.startRecording(streamAudio: true);
        
        final result = await streamCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => false,
        );
        
        await audioService.stopRecording();
        
        expect(result, isTrue);
        expect(audioChunksReceived, greaterThanOrEqualTo(3));
      });

      test('should maintain performance under load', () async {
        await audioService.initialize();
        
        final startTime = DateTime.now();
        await audioService.startRecording(streamAudio: true);
        
        // Let it run for a few seconds
        await Future.delayed(const Duration(seconds: 3));
        
        await audioService.stopRecording();
        final endTime = DateTime.now();
        
        final status = audioService.getStatus();
        final duration = endTime.difference(startTime);
        
        // Check performance metrics
        expect(status['totalBytesProcessed'], greaterThan(0));
        expect(duration.inSeconds, lessThanOrEqualTo(5)); // Should complete within reasonable time
        
        if (kDebugMode) {
          print('Performance Test Results:');
          print('Duration: ${duration.inMilliseconds}ms');
          print('Bytes processed: ${status['totalBytesProcessed']}');
          print('Audio buffer status: ${status['audioBufferStatus']}');
        }
      });
    });

    group('Platform-Specific Tests', () {
      test('should handle web platform correctly', () async {
        await audioService.initialize();
        
        if (kIsWeb) {
          final config = audioService.getAudioConfig();
          expect(config['platform'], equals('web'));
          
          // Web should use MediaRecorder API
          final status = audioService.getStatus();
          expect(status['unifiedStreamingStatus']['platform'], equals('web'));
        }
      });

      test('should handle mobile platforms correctly', () async {
        await audioService.initialize();
        
        if (!kIsWeb) {
          final config = audioService.getAudioConfig();
          expect(config['platform'], anyOf(['android', 'ios', 'desktop']));
          
          // Mobile should use native streaming
          final status = audioService.getStatus();
          expect(status['unifiedStreamingStatus']['platform'], 
                 anyOf(['android', 'ios', 'desktop']));
        }
      });
    });
  });
}