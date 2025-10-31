import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/app_config.dart';
import 'network_service.dart';

class DeepgramService {
  WebSocketChannel? _channel;
  StreamController<String>? _transcriptController;
  bool _isConnected = false;

  Stream<String> get transcriptStream => _transcriptController?.stream ?? const Stream.empty();
  bool get isConnected => _isConnected;

  Future<void> startRealTimeTranscription({
    bool diarization = false,
    String language = AppConfig.defaultLanguage,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🎤 [DeepgramService] Starting real-time transcription...');
        debugPrint('🔧 [DeepgramService] Language: $language, Diarization: $diarization');
      }

      // Check if API key is configured
      if (!AppConfig.isDeepgramConfigured) {
        if (kDebugMode) {
          debugPrint('❌ [DeepgramService] API key not configured!');
        }
        throw Exception('Deepgram API key not configured. Please update AppConfig.deepgramApiKey');
      }

      if (kDebugMode) {
        debugPrint('✅ [DeepgramService] API key configured: ${AppConfig.deepgramApiKey.substring(0, 8)}...');
      }

      // Check network connectivity before attempting connection
      if (kDebugMode) {
        debugPrint('🔍 [DeepgramService] Checking network connectivity...');
      }
      
      final networkDiagnostics = await NetworkService.getNetworkDiagnostics();
      if (kDebugMode) {
        debugPrint('📊 [DeepgramService] Network diagnostics: $networkDiagnostics');
      }
      
      // For web platforms, skip general internet check due to CORS restrictions
      // and rely on Deepgram-specific connectivity
      if (!kIsWeb && networkDiagnostics['internet_available'] != true) {
        _handleError('No internet connection available');
        return;
      }
      
      if (networkDiagnostics['deepgram_reachable'] != true) {
        _handleError('Cannot reach Deepgram API. Please check your network connection and try again.');
        return;
      }

      _transcriptController = StreamController<String>.broadcast();
      
      // Build query parameters for Deepgram Nova-2 model
      final queryParams = {
        'model': AppConfig.deepgramModel,
        'language': language,
        'encoding': 'linear16',
        'sample_rate': AppConfig.sampleRate.toString(),
        'channels': AppConfig.channels.toString(),
        'punctuate': 'true',
        'smart_format': 'true',
        'interim_results': 'true',
        'endpointing': '300',
        if (diarization) 'diarize': 'true',
      };

      final uri = Uri.parse('${AppConfig.deepgramBaseUrl}?${_buildQueryString(queryParams)}');
      
      if (kDebugMode) {
        debugPrint('🌐 [DeepgramService] Connecting to: ${uri.toString()}');
        debugPrint('🔑 [DeepgramService] Using protocols: [token, ${AppConfig.deepgramApiKey.substring(0, 8)}...]');
      }
      
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['token', AppConfig.deepgramApiKey],
      );

      _isConnected = true;

      // Listen to WebSocket messages
      _channel!.stream.listen(
        (data) {
          if (kDebugMode) {
            debugPrint('📨 [DeepgramService] Received WebSocket message: ${data.toString().substring(0, data.toString().length > 100 ? 100 : data.toString().length)}...');
          }
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ [DeepgramService] WebSocket error: $error');
          }
          _handleError(error);
        },
        onDone: () {
          _isConnected = false;
          if (kDebugMode) {
            debugPrint('🔌 [DeepgramService] WebSocket connection closed');
          }
        },
      );

      if (kDebugMode) {
        debugPrint('✅ [DeepgramService] Connected to Deepgram WebSocket successfully!');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DeepgramService] Failed to connect to Deepgram: $e');
        debugPrint('🔍 [DeepgramService] Error type: ${e.runtimeType}');
      }
      _handleError(e);
    }
  }

  void sendAudioData(List<int> audioData) {
    if (_isConnected && _channel != null) {
      try {
        if (kDebugMode) {
          debugPrint('🎵 [DeepgramService] Sending audio data: ${audioData.length} bytes');
        }
        _channel!.sink.add(audioData);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [DeepgramService] Error sending audio data: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ [DeepgramService] Cannot send audio data - not connected (connected: $_isConnected, channel: ${_channel != null})');
      }
    }
  }

  Future<void> stopTranscription() async {
    try {
      if (_channel != null) {
        // Send close message to Deepgram
        _channel!.sink.add(jsonEncode({'type': 'CloseStream'}));
        await _channel!.sink.close(status.normalClosure);
        _channel = null;
      }
      
      _isConnected = false;
      await _transcriptController?.close();
      _transcriptController = null;
      
      if (kDebugMode) {
        debugPrint('Deepgram connection closed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error closing Deepgram connection: $e');
      }
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final Map<String, dynamic> message = jsonDecode(data);
      
      if (message['type'] == 'Results') {
        final results = message['channel']?['alternatives'];
        if (results != null && results.isNotEmpty) {
          final transcript = results[0]['transcript'] as String?;
          final isFinal = message['is_final'] as bool? ?? false;
          
          if (transcript != null && transcript.isNotEmpty) {
            _transcriptController?.add(transcript);
            
            if (kDebugMode) {
              debugPrint('Transcript (${isFinal ? 'final' : 'interim'}): $transcript');
            }
          }
        }
      } else if (message['type'] == 'Metadata') {
        if (kDebugMode) {
          debugPrint('Deepgram metadata: ${message['transaction_key']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing WebSocket message: $e');
      }
    }
  }

  void _handleError(dynamic error) {
    if (kDebugMode) {
      debugPrint('🚨 [DeepgramService] Handling error: $error');
      debugPrint('🔍 [DeepgramService] Error details: ${error.toString()}');
    }
    _isConnected = false;
    _transcriptController?.addError(error);
    
    if (kDebugMode) {
      debugPrint('📡 [DeepgramService] Transcript stream error: $error');
    }
  }

  String _buildQueryString(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  // Alternative method for file-based transcription (non-real-time)
  Future<String> transcribeAudioFile(File audioFile) async {
    try {
      final uri = Uri.parse('https://api.deepgram.com/v1/listen?model=${AppConfig.deepgramModel}&smart_format=true&punctuate=true');
      
      final request = await HttpClient().postUrl(uri);
      request.headers.set('Authorization', 'Token ${AppConfig.deepgramApiKey}');
      request.headers.set('Content-Type', 'audio/wav');
      
      final audioBytes = await audioFile.readAsBytes();
      request.add(audioBytes);
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(responseBody);
        final transcript = result['results']?['channels']?[0]?['alternatives']?[0]?['transcript'] as String?;
        return transcript ?? '';
      } else {
        throw Exception('Deepgram API error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error transcribing audio file: $e');
      }
      throw Exception('Failed to transcribe audio: $e');
    }
  }

  void dispose() {
    stopTranscription();
  }
}