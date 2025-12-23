// lib/screens/api_debug_screen.dart

import 'package:flutter/material.dart';
import '../utils/api_test_helper.dart';
import '../services/api_client.dart';
import '../config/api_config.dart';

/// Debug screen for testing API configuration
class ApiDebugScreen extends StatefulWidget {
  const ApiDebugScreen({super.key});

  @override
  State<ApiDebugScreen> createState() => _ApiDebugScreenState();
}

class _ApiDebugScreenState extends State<ApiDebugScreen> {
  String _logOutput = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _showCurrentConfiguration();
  }

  void _addLog(String message) {
    setState(() {
      _logOutput += '$message\n';
    });
  }

  void _clearLog() {
    setState(() {
      _logOutput = '';
    });
  }

  void _showCurrentConfiguration() {
    _clearLog();
    _addLog('🔧 API Configuration Debug Screen');
    _addLog('════════════════════════════════════════');
    _addLog('🌍 Environment: ${ApiConfig.environmentName}');
    _addLog('🔗 Base URL: ${ApiConfig.baseUrl}');
    _addLog('⏱️ Timeout: ${ApiConfig.timeout.inSeconds}s');
    _addLog('📝 Logging: ${ApiConfig.isLoggingEnabled ? 'Enabled' : 'Disabled'}');
    _addLog('════════════════════════════════════════');
    _addLog('');
    _addLog('Sample Endpoints:');
    _addLog('• Auth: ${ApiConfig.buildUrl(ApiConfig.Auth.signup)}');
    _addLog('• Topics: ${ApiConfig.buildUrl(ApiConfig.Topics.list)}');
    _addLog('• Enrollments: ${ApiConfig.buildUrl(ApiConfig.Enrollments.mobileEnroll)}');
    _addLog('');
    _addLog('Tap "Test API Call" to verify the configuration works.');
  }

  Future<void> _testApiCall() async {
    setState(() {
      _isLoading = true;
    });

    _addLog('🧪 Testing API call...');
    _addLog('📤 Making request to: ${ApiConfig.buildUrl(ApiConfig.Topics.list)}');
    
    final api = ThinkCyberApi();
    
    try {
      final response = await api.fetchTopics(userId: 999);
      
      if (response.success) {
        _addLog('✅ Success! Received ${response.topics.length} topics');
        _addLog('📊 Response data looks valid');
      } else {
        _addLog('⚠️ API returned success=false');
        _addLog('   This might indicate authentication or permission issues');
      }
      
    } catch (e) {
      _addLog('❌ API call failed: $e');
      _addLog('');
      if (e.toString().contains('SocketException') || e.toString().contains('NetworkException')) {
        _addLog('🌐 Network Error Details:');
        _addLog('   • Check if the URL is accessible');
        _addLog('   • Verify DNS resolution');
        _addLog('   • Check firewall/proxy settings');
      } else if (e.toString().contains('404')) {
        _addLog('🔍 404 Error Details:');
        _addLog('   • The endpoint might not exist on the new server');
        _addLog('   • Check if the API structure matches');
      } else if (e.toString().contains('timeout')) {
        _addLog('⏱️ Timeout Error Details:');
        _addLog('   • Server might be slow or unresponsive');
        _addLog('   • Consider increasing timeout duration');
      }
    } finally {
      api.dispose();
      setState(() {
        _isLoading = false;
      });
    }
    
    _addLog('');
    _addLog('Check the debug console for detailed request/response logs!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debug'),
        backgroundColor: const Color(0xFF0D6EFD),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearLog,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testApiCall,
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isLoading ? 'Testing...' : 'Test API Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D6EFD),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showCurrentConfiguration,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Config'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ApiConfig.isDevelopment 
                        ? Colors.green[50]
                        : ApiConfig.isStaging
                            ? Colors.orange[50]
                            : Colors.red[50],
                    border: Border.all(
                      color: ApiConfig.isDevelopment 
                          ? Colors.green
                          : ApiConfig.isStaging
                              ? Colors.orange
                              : Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: ApiConfig.isDevelopment 
                            ? Colors.green
                            : ApiConfig.isStaging
                                ? Colors.orange
                                : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current Environment: ${ApiConfig.environmentName}\nBase URL: ${ApiConfig.baseUrl}',
                          style: TextStyle(
                            fontSize: 12,
                            color: ApiConfig.isDevelopment 
                                ? Colors.green[800]
                                : ApiConfig.isStaging
                                    ? Colors.orange[800]
                                    : Colors.red[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Log Output
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _logOutput.isEmpty ? 'No output yet...' : _logOutput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.green,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 How to use this debug screen:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D6EFD),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Check the current configuration above\n'
                  '2. Tap "Test API Call" to verify your new URL works\n'
                  '3. Check the debug console for detailed request logs\n'
                  '4. Look for the "Full URL" in the logs to confirm the right URL is being used',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Console Logging: ${ApiConfig.isLoggingEnabled ? 'Enabled ✅' : 'Disabled ❌'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ApiConfig.isLoggingEnabled ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to add to any screen for quick access to API debug
class ApiDebugButton extends StatelessWidget {
  const ApiDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in development environment
    if (!ApiConfig.isDevelopment) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ApiDebugScreen(),
          ),
        );
      },
      icon: const Icon(Icons.bug_report),
      label: const Text('API Debug'),
      backgroundColor: const Color(0xFF0D6EFD),
      foregroundColor: Colors.white,
    );
  }
}