import 'dart:async';
import 'dart:io' show Platform, NetworkInterface;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class NetworkService {
  static Future<bool> checkInternetConnection() async {
    try {
      if (kDebugMode) {
        debugPrint('🌐 [NetworkService] Checking internet connectivity...');
      }
      
      // Use HTTP request instead of InternetAddress.lookup for web compatibility
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'User-Agent': 'MedTran-Flutter-App'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ [NetworkService] Internet connection available');
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [NetworkService] No internet connection: $e');
      }
    }
    return false;
  }

  static Future<bool> checkDeepgramConnectivity() async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 [NetworkService] Checking Deepgram API connectivity...');
      }
      
      // Use HTTP request instead of InternetAddress.lookup for web compatibility
      final response = await http.get(
        Uri.parse('https://api.deepgram.com'),
        headers: {'User-Agent': 'MedTran-Flutter-App'},
      ).timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        debugPrint('✅ [NetworkService] Deepgram HTTP connection successful. Status: ${response.statusCode}');
      }
      
      return response.statusCode >= 200 && response.statusCode < 500; // Accept any non-server error
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [NetworkService] Deepgram connectivity failed: $e');
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> getNetworkDiagnostics() async {
    final diagnostics = <String, dynamic>{};
    
    try {
      // Check general internet connectivity
      diagnostics['internet_available'] = await checkInternetConnection();
      
      // Check Deepgram specific connectivity
      diagnostics['deepgram_reachable'] = await checkDeepgramConnectivity();
      
      // Get network interface information (only available on non-web platforms)
      if (!kIsWeb) {
        try {
          // Import dart:io conditionally for non-web platforms
          final interfaces = await _getNetworkInterfaces();
          diagnostics['network_interfaces'] = interfaces;
        } catch (e) {
          diagnostics['network_interfaces_error'] = 'Not available on web platform';
        }
      } else {
        diagnostics['network_interfaces'] = 'Not available on web platform';
      }
      
      if (kDebugMode) {
        debugPrint('📊 [NetworkService] Network diagnostics: $diagnostics');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [NetworkService] Error getting network diagnostics: $e');
      }
      diagnostics['error'] = e.toString();
    }
    
    return diagnostics;
  }

  static Future<List<Map<String, dynamic>>> _getNetworkInterfaces() async {
    if (kIsWeb) {
      return [];
    }
    
    try {
      // This will only work on non-web platforms
      final interfaces = await NetworkInterface.list();
      return interfaces.map((interface) => {
        'name': interface.name,
        'addresses': interface.addresses.map((addr) => addr.address).toList(),
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> performConnectivityTest() async {
    final testResults = <String, dynamic>{};
    
    if (kDebugMode) {
      debugPrint('🧪 [NetworkService] Starting comprehensive connectivity test...');
    }
    
    try {
      // Test 1: Basic internet connectivity
      testResults['basic_internet'] = await checkInternetConnection();
      
      // Test 2: DNS resolution for multiple hosts (web-compatible HTTP tests)
      final dnsTests = <String, bool>{};
      final testHosts = ['https://www.google.com', 'https://api.deepgram.com', 'https://8.8.8.8'];
      
      for (final host in testHosts) {
        try {
          final response = await http.get(
            Uri.parse(host),
            headers: {'User-Agent': 'MedTran-Flutter-App-Test'},
          ).timeout(const Duration(seconds: 10));
          
          dnsTests[host] = response.statusCode >= 200 && response.statusCode < 500;
          if (kDebugMode) {
            debugPrint('🔍 [NetworkService] HTTP test for $host: ${dnsTests[host] == true ? 'SUCCESS' : 'FAILED'} (${response.statusCode})');
          }
        } catch (e) {
          dnsTests[host] = false;
          if (kDebugMode) {
            debugPrint('❌ [NetworkService] HTTP test for $host failed: $e');
          }
        }
      }
      testResults['dns_tests'] = dnsTests;
      
      // Test 3: HTTP connectivity tests
      final httpTests = <String, Map<String, dynamic>>{};
      final httpTestUrls = [
        'https://www.google.com',
        'https://api.deepgram.com',
        'https://httpbin.org/get'
      ];
      
      for (final url in httpTestUrls) {
        try {
          final stopwatch = Stopwatch()..start();
          final response = await http.get(
            Uri.parse(url),
            headers: {'User-Agent': 'MedTran-Flutter-App-Test'},
          ).timeout(const Duration(seconds: 10));
          stopwatch.stop();
          
          httpTests[url] = {
            'success': true,
            'status_code': response.statusCode,
            'response_time_ms': stopwatch.elapsedMilliseconds,
          };
          
          if (kDebugMode) {
            debugPrint('✅ [NetworkService] HTTP test for $url: ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)');
          }
        } catch (e) {
          httpTests[url] = {
            'success': false,
            'error': e.toString(),
          };
          if (kDebugMode) {
            debugPrint('❌ [NetworkService] HTTP test for $url failed: $e');
          }
        }
      }
      testResults['http_tests'] = httpTests;
      
      // Test 4: WebSocket connectivity test
      try {
        if (kDebugMode) {
          debugPrint('🔌 [NetworkService] Testing WebSocket connectivity...');
        }
        
        final wsUri = Uri.parse('wss://echo.websocket.org');
        final channel = WebSocketChannel.connect(wsUri);
        
        final completer = Completer<bool>();
        Timer(const Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });
        
        channel.stream.listen(
          (data) {
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
        );
        
        channel.sink.add('test');
        final wsSuccess = await completer.future;
        await channel.sink.close();
        
        testResults['websocket_test'] = {
          'success': wsSuccess,
          'test_url': 'wss://echo.websocket.org'
        };
        
        if (kDebugMode) {
          debugPrint('🔌 [NetworkService] WebSocket test: ${wsSuccess ? 'SUCCESS' : 'FAILED'}');
        }
      } catch (e) {
        testResults['websocket_test'] = {
          'success': false,
          'error': e.toString(),
        };
        if (kDebugMode) {
          debugPrint('❌ [NetworkService] WebSocket test failed: $e');
        }
      }
      
    } catch (e) {
      testResults['test_error'] = e.toString();
      if (kDebugMode) {
        debugPrint('❌ [NetworkService] Connectivity test error: $e');
      }
    }
    
    if (kDebugMode) {
      debugPrint('🧪 [NetworkService] Connectivity test completed: $testResults');
    }
    
    return testResults;
  }
}