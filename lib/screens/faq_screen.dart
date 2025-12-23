import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/localization_service.dart';
import '../widgets/translated_text.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final ThinkCyberApi _api = ThinkCyberApi();
  List<FAQ> _faqs = [];
  bool _loading = true;
  String? _error;
  final Set<int> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _loadFAQs();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final localization = LocalizationService();
      final languageCode = localization.languageCode;

      final response = await _api.fetchHomepage(languageCode: languageCode);
      if (!mounted) return;

      setState(() {
        _faqs = response.data.faqs..sort((a, b) => a.order.compareTo(b.order));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load FAQs. Please try again.';
        _loading = false;
      });
      debugPrint('Error loading FAQs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('FAQs'),
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFFF5F7FA),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFAQs,
                          child: const TranslatedText('Retry'),
                        ),
                      ],
                    ),
                  )
                : _faqs.isEmpty
                    ? const Center(
                        child: TranslatedText('No FAQs available'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFAQs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _faqs.length,
                          itemBuilder: (context, index) {
                            final faq = _faqs[index];
                            final isExpanded = _expandedItems.contains(index);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  faq.question,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                trailing: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: const Color(0xFF2E7DFF),
                                ),
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    if (expanded) {
                                      _expandedItems.add(index);
                                    } else {
                                      _expandedItems.remove(index);
                                    }
                                  });
                                },
                                children: [
                                  Container(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      bottom: 16,
                                    ),
                                    child: Text(
                                      faq.answer,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280),
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
