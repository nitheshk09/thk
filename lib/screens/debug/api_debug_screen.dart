// lib/screens/debug/api_debug_screen.dart

import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import '../../utils/api_test_helper.dart';

class ApiDebugScreen extends StatefulWidget {
  const ApiDebugScreen({super.key});

  @override
  State<ApiDebugScreen> createState() => _ApiDebugScreenState();
}

class _ApiDebugScreenState extends State<ApiDebugScreen> {
  String _testResults = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _showConfiguration();
  }

  void _showConfiguration() {
    setState(() {
      _testResults = '''
🔧 API CONFIGURATION DEBUG SCREEN
═══════════════════════════════════════════════════════

🌍 Environment: ${ApiConfig.environmentName}
🔗 Base URL: ${ApiConfig.baseUrl}
⏱️  Timeout: ${ApiConfig.timeout.inSeconds} seconds
📝 Logging: ${ApiConfig.isLoggingEnabled ? 'Enabled ✅' : 'Disabled ❌'}
🔒 Production: ${ApiConfig.isProduction ? 'Yes ⚠️' : 'No ✅'}

📍 SAMPLE ENDPOINTS:
────────────────────────────────────────────────────────
Auth Signup: ${ApiConfig.buildUrl(ApiConfig.authSignup)}
Topics List: ${ApiConfig.buildUrl(ApiConfig.topicsList)}
Topics with User: ${ApiConfig.buildUrl(ApiConfig.topicsListWithUser(123))}
Topic Detail: ${ApiConfig.buildUrl(ApiConfig.topicsDetailWithId(5, userId: 123))}
User Enrollments: ${ApiConfig.buildUrl(ApiConfig.enrollmentsUserEnrollmentsWithId(789))}

🔐 HEADERS:
────────────────────────────────────────────────────────
${ApiConfig.defaultHeaders.entries.map((e) => '${e.key}: ${e.value}').join('\n')}

🌏 THIRD-PARTY APIs:
────────────────────────────────────────────────────────
Google Translate: ${ApiConfig.buildGoogleTranslateUrl('test', 'en', 'hi')}
Stripe Key: ${ApiConfig.stripePublishableKey}

═══════════════════════════════════════════════════════
''';
    });
  }

  Future<void> _testApiCall() async {
    setState(() {
      _isLoading = true;
      _testResults += '\n\n🧪 TESTING LIVE API CALL...\n';
      _testResults += '────────────────────────────────────────────────────────\n';
    });

    final api = ThinkCyberApi();
    
    try {
      _addToResults('🚀 Making API call to: ${ApiConfig.buildUrl(ApiConfig.topicsList)}');
      
      final response = await api.fetchTopics();
      
      if (response.success) {
        _addToResults('✅ API call successful!');
        _addToResults('📊 Topics received: ${response.topics.length}');
        if (response.topics.isNotEmpty) {
          _addToResults('🎯 First topic: "${response.topics.first.title}"');
        }
      } else {
        _addToResults('⚠️  API response received but success=false');
      }
      
    } catch (e) {
      _addToResults('❌ API call failed: $e');
      _addToResults('   Check console logs for detailed error information');
      _addToResults('   This confirms the URL being called: ${ApiConfig.baseUrl}');
    } finally {
      api.dispose();
      setState(() {
        _isLoading = false;
      });
    }
    
    _addToResults('────────────────────────────────────────────────────────');
    _addToResults('✅ Test completed! Check console for detailed logs.');
  }

  void _addToResults(String message) {
    setState(() {
      _testResults += '$message\n';
    });
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
    });
    _showConfiguration();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debug'),
        backgroundColor: Colors.blue.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearResults,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
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
                        : const Icon(Icons.cloud_sync),
                    label: Text(_isLoading ? 'Testing...' : 'Test API Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // Print to console as well
                    ApiTestHelper.printCurrentConfiguration();
                    ApiTestHelper.showAllEndpoints();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Configuration logged to console'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.terminal),
                  label: const Text('Log to Console'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Results display
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _testResults,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ),
          
          // Quick info bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade900,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current Base URL: ${ApiConfig.baseUrl}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Text(
                  ApiConfig.environmentName,
                  style: TextStyle(
                    color: ApiConfig.isProduction ? Colors.red : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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