import 'package:flutter/material.dart';
import '../services/network_service.dart';

class NetworkTestScreen extends StatefulWidget {
  const NetworkTestScreen({super.key});

  @override
  State<NetworkTestScreen> createState() => _NetworkTestScreenState();
}

class _NetworkTestScreenState extends State<NetworkTestScreen> {
  Map<String, dynamic>? _testResults;
  bool _isRunningTest = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Connectivity Test'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A90E2),
              Color(0xFF357ABD),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network Connectivity Diagnostics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This test will check internet connectivity, DNS resolution, HTTP connections, and WebSocket functionality.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isRunningTest ? null : _runConnectivityTest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isRunningTest
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Running Test...'),
                                    ],
                                  )
                                : const Text('Run Connectivity Test'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_testResults != null) ...[
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Test Results',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildTestResults(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runConnectivityTest() async {
    setState(() {
      _isRunningTest = true;
      _testResults = null;
    });

    try {
      final results = await NetworkService.performConnectivityTest();
      setState(() {
        _testResults = results;
      });
    } catch (e) {
      setState(() {
        _testResults = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  Widget _buildTestResults() {
    if (_testResults == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTestSection('Basic Internet', _testResults!['basic_internet']),
        const SizedBox(height: 16),
        _buildDnsTestSection(),
        const SizedBox(height: 16),
        _buildHttpTestSection(),
        const SizedBox(height: 16),
        _buildWebSocketTestSection(),
        if (_testResults!.containsKey('test_error')) ...[
          const SizedBox(height: 16),
          _buildErrorSection(),
        ],
      ],
    );
  }

  Widget _buildTestSection(String title, dynamic result) {
    final isSuccess = result == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        border: Border.all(
          color: isSuccess ? Colors.green : Colors.red,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            isSuccess ? 'PASS' : 'FAIL',
            style: TextStyle(
              color: isSuccess ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDnsTestSection() {
    final dnsTests = _testResults!['dns_tests'] as Map<String, dynamic>?;
    if (dnsTests == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DNS Resolution Tests',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...dnsTests.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildTestSection(entry.key, entry.value),
            )),
      ],
    );
  }

  Widget _buildHttpTestSection() {
    final httpTests = _testResults!['http_tests'] as Map<String, dynamic>?;
    if (httpTests == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HTTP Connection Tests',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...httpTests.entries.map((entry) {
          final testData = entry.value as Map<String, dynamic>;
          final isSuccess = testData['success'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                border: Border.all(
                  color: isSuccess ? Colors.green : Colors.red,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle : Icons.error,
                        color: isSuccess ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        isSuccess ? 'PASS' : 'FAIL',
                        style: TextStyle(
                          color: isSuccess ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (isSuccess) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${testData['status_code']} | Time: ${testData['response_time_ms']}ms',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'Error: ${testData['error']}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWebSocketTestSection() {
    final wsTest = _testResults!['websocket_test'] as Map<String, dynamic>?;
    if (wsTest == null) return const SizedBox.shrink();

    final isSuccess = wsTest['success'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WebSocket Test',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            border: Border.all(
              color: isSuccess ? Colors.green : Colors.red,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'WebSocket Echo Test',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    isSuccess ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      color: isSuccess ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'URL: ${wsTest['test_url']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (!isSuccess && wsTest.containsKey('error')) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${wsTest['error']}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Test Error',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _testResults!['test_error'].toString(),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}