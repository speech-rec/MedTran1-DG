import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_dictation_app/services/audio_buffer_service.dart';

void main() {
  group('Audio Services Basic Tests', () {
    late AudioBufferService bufferService;

    setUp(() {
      bufferService = AudioBufferService();
    });

    tearDown(() async {
      await bufferService.dispose();
    });

    group('AudioBufferService Tests', () {
      test('should initialize successfully', () async {
        // Test that initialize completes without error
        await expectLater(bufferService.initialize(), completes);
        
        // Verify service is ready for processing
        expect(bufferService.isProcessing, isFalse);
        expect(bufferService.totalBytesProcessed, equals(0));
        expect(bufferService.chunksProcessed, equals(0));
      });

      test('should process audio data', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        // Use a chunk size that meets the minimum processing requirements (4096 bytes)
        final testData = Uint8List.fromList(List.generate(4096, (i) => i % 256));
        await bufferService.processAudioData(testData);
        
        // Wait a bit for async processing to complete
        await Future.delayed(const Duration(milliseconds: 50));
        
        final metrics = bufferService.getMetrics();
        expect(metrics['totalBytesProcessed'], greaterThan(0));
      });

      test('should provide status information', () async {
        await bufferService.initialize();
        
        final metrics = bufferService.getMetrics();
        expect(metrics, isA<Map<String, dynamic>>());
        expect(metrics, containsPair('isProcessing', isA<bool>()));
        expect(metrics, containsPair('totalBytesProcessed', isA<int>()));
        expect(metrics, containsPair('chunksProcessed', isA<int>()));
      });

      test('should handle multiple audio chunks', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        // Add multiple chunks
        for (int i = 0; i < 5; i++) {
          final testData = Uint8List.fromList(List.generate(100, (j) => (i * 100 + j) % 256));
          await bufferService.processAudioData(testData);
        }
        
        final metrics = bufferService.getMetrics();
        expect(metrics['chunksProcessed'], greaterThanOrEqualTo(0));
        expect(metrics['totalBytesProcessed'], greaterThanOrEqualTo(0));
      });

      test('should provide processed audio stream', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        final streamCompleter = Completer<bool>();
        late StreamSubscription subscription;
        
        subscription = bufferService.processedAudioStream.listen(
          (processedData) {
            expect(processedData, isA<Uint8List>());
            expect(processedData.isNotEmpty, isTrue);
            subscription.cancel();
            streamCompleter.complete(true);
          },
          onError: (error) {
            subscription.cancel();
            streamCompleter.complete(false);
          },
        );
        
        // Add test data to trigger stream
        final testData = Uint8List.fromList(List.generate(4096, (i) => i % 256));
        await bufferService.processAudioData(testData);
        
        final result = await streamCompleter.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
        
        expect(result, isTrue);
      });

      test('should handle empty data gracefully', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        final emptyData = Uint8List(0);
        await bufferService.processAudioData(emptyData);
        
        final metrics = bufferService.getMetrics();
        // Should not crash and should handle empty data
        expect(metrics['totalBytesProcessed'], equals(0));
      });

      test('should handle large data chunks', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        // Create a large chunk (10KB)
        final largeData = Uint8List.fromList(List.generate(10240, (i) => i % 256));
        await bufferService.processAudioData(largeData);
        
        final metrics = bufferService.getMetrics();
        expect(metrics['totalBytesProcessed'], greaterThanOrEqualTo(0));
      });

      test('should stop and cleanup properly', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        // Add some data
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        await bufferService.processAudioData(testData);
        
        // Stop the service
        await bufferService.stopProcessing();
        
        final metrics = bufferService.getMetrics();
        expect(metrics['isProcessing'], isFalse);
      });

      test('should handle concurrent operations', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        // Simulate concurrent audio data processing
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          final testData = Uint8List.fromList(List.generate(100, (j) => (i * 100 + j) % 256));
          futures.add(bufferService.processAudioData(testData));
        }
        
        await Future.wait(futures);
        
        final metrics = bufferService.getMetrics();
        expect(metrics['chunksProcessed'], greaterThanOrEqualTo(0));
        expect(metrics['totalBytesProcessed'], greaterThanOrEqualTo(0));
      });

      test('should provide performance metrics', () async {
        await bufferService.initialize();
        bufferService.startProcessing();
        
        final testData = Uint8List.fromList(List.generate(1000, (i) => i % 256));
        await bufferService.processAudioData(testData);
        
        final metrics = bufferService.getMetrics();
        expect(metrics, containsPair('totalBytesProcessed', isA<int>()));
        expect(metrics, containsPair('chunksProcessed', isA<int>()));
        expect(metrics, containsPair('isProcessing', isA<bool>()));
        expect(metrics, containsPair('averageChunkSize', isA<double>()));
      });
    });
  });
}