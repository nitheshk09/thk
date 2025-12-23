import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chatbot_service.dart';
import '../services/translation_service.dart';
import '../services/localization_service.dart';
import '../services/api_client.dart';
import '../widgets/translated_text.dart';
import '../widgets/topic_visuals.dart';
import 'topic_detail_screen.dart';

// Helper class for search results with module/video match
class _SearchResult {
  final CourseTopic topic;
  final String? matchingModuleTitle;
  final String? matchingVideoTitle;
  final bool isModuleDescriptionMatch;
  final String? matchedDescription;
  final String searchQuery;
  _SearchResult({
    required this.topic, 
    this.matchingModuleTitle,
    this.matchingVideoTitle,
    this.isModuleDescriptionMatch = false,
    this.matchedDescription,
    this.searchQuery = '',
  });
}

// Helper function to build highlighted text with matched terms in bold
Widget _buildHighlightedText(String text, String searchQuery) {
  if (searchQuery.isEmpty) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF4B5563),
        fontStyle: FontStyle.italic,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = searchQuery.toLowerCase();
  final matches = <TextSpan>[];
  
  int start = 0;
  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index == -1) {
      if (start < text.length) {
        matches.add(TextSpan(text: text.substring(start)));
      }
      break;
    }
    
    if (index > start) {
      matches.add(TextSpan(text: text.substring(start, index)));
    }
    
    matches.add(TextSpan(
      text: text.substring(index, index + lowerQuery.length),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
        backgroundColor: Color(0xFFFEF08A),
      ),
    ));
    
    start = index + lowerQuery.length;
  }
  
  return RichText(
    text: TextSpan(
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF4B5563),
        fontStyle: FontStyle.italic,
      ),
      children: matches,
    ),
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  );
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with WidgetsBindingObserver {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatbotService _chatbotService = ChatbotService();
  final TranslationService _translationService = TranslationService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final LocalizationService _localizationService = LocalizationService();
  final ThinkCyberApi _api = ThinkCyberApi();
  
  bool _isListening = false;
  bool _isLoading = false;
  String _currentLanguage = 'en';
  String _voiceSearchLanguage = 'en'; // Separate language for voice search, defaults to English
  bool _showSearch = false;
  bool _isSearching = false;
  String _searchQuery = '';
  List<_SearchResult> _searchResults = [];
  List<CourseTopic> _topics = [];

  @override
  void initState() {
    super.initState();
    print('🚀 ChatbotScreen initState called');
    WidgetsBinding.instance.addObserver(this);
    
    // Lock screen orientation to portrait for better chat experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    _initializeSpeech();
    _currentLanguage = _localizationService.languageCode;
    _addWelcomeMessage();
    print('📞 Calling _initializeChatbot');
    _initializeChatbot();
    
    // Listen to language changes
    _localizationService.addListener(_onLanguageChanged);
  }

  Future<void> _initializeChatbot() async {
    // Initialize chatbot with topics data for enhanced search
    try {
      print('🔵 _initializeChatbot started');
      
      print('🔵 Calling chatbotService.initializeTopics()...');
      await _chatbotService.initializeTopics();
      print('✅ chatbotService.initializeTopics() completed');
      
      print('🔵 Calling _loadTopics()...');
      await _loadTopics(); // Load topics for search
      print('✅ _loadTopics() completed');
      
    } catch (e, stackTrace) {
      print('❌ Chatbot initialization failed: $e');
      print('Stack: $stackTrace');
    }
  }

  Future<void> _loadTopics() async {
    try {
      print('🔄 Starting to load topics for search...');
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getInt('thinkcyber_user_id');
      print('📋 User ID: $storedUserId');
      
      final response = await _api.fetchTopics(userId: storedUserId);
      print('📦 API Response received with ${response.topics.length} topics');
      
      if (mounted) {
        setState(() {
          _topics = response.topics;
        });
        print('✅ Loaded ${_topics.length} topics for search');
        if (_topics.isNotEmpty) {
          print('📚 Sample topics: ${_topics.take(3).map((t) => t.title).join(", ")}...');
        } else {
          print('⚠️ Topics list is empty after loading!');
        }
      } else {
        print('⚠️ Widget not mounted, cannot set topics');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading topics: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Extract description snippet around the match
  String _extractDescriptionSnippet(String description, String searchQuery) {
    final lowerDesc = description.toLowerCase();
    final queryLower = searchQuery.toLowerCase();
    final matchIndex = lowerDesc.indexOf(queryLower);
    
    if (matchIndex == -1) return description.length > 100 ? '${description.substring(0, 100)}...' : description;
    
    final start = (matchIndex - 50).clamp(0, description.length);
    final end = (matchIndex + queryLower.length + 50).clamp(0, description.length);
    
    String snippet = description.substring(start, end);
    
    if (start > 0) snippet = '...$snippet';
    if (end < description.length) snippet = '$snippet...';
    
    return snippet;
  }

  // Create highlighted text with matched terms in bold
  Widget _buildHighlightedText(String text, String searchQuery) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF4B5563),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final matches = <TextSpan>[];
    
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          matches.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      
      if (index > start) {
        matches.add(TextSpan(text: text.substring(start, index)));
      }
      
      matches.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937),
          backgroundColor: Color(0xFFFEF08A),
        ),
      ));
      
      start = index + searchQuery.length;
    }
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF4B5563),
          fontStyle: FontStyle.italic,
        ),
        children: matches,
      ),
    );
  }

  Future<void> _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      _isSearching = _searchQuery.isNotEmpty;
    });
    
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    print('🔍 Searching for: "$_searchQuery" in ${_topics.length} topics');
    List<_SearchResult> results = [];
    
    for (final topic in _topics) {
      String? matchingModuleTitle;
      String? matchingVideoTitle;
      bool topicMatches = false;
      bool isDescriptionMatch = false;
      String? matchedDescriptionText;
      
      // Check topic-level matches
      if (topic.title.toLowerCase().contains(_searchQuery) ||
          topic.categoryName.toLowerCase().contains(_searchQuery) ||
          (topic.subcategoryName?.toLowerCase().contains(_searchQuery) ?? false) ||
          (topic.description?.toLowerCase().contains(_searchQuery) ?? false)) {
        topicMatches = true;
      }
      
      // If no topic match, search in modules and videos
      if (!topicMatches) {
        try {
          final detailResp = await _api.fetchTopicDetail(topic.id);
          final modules = detailResp.topic.modules;
          
          for (final module in modules) {
            if (module.title.toLowerCase().contains(_searchQuery)) {
              matchingModuleTitle = module.title;
              break;
            }
            
            if (module.description.toLowerCase().contains(_searchQuery)) {
              matchingModuleTitle = module.title;
              isDescriptionMatch = true;
              matchedDescriptionText = _extractDescriptionSnippet(module.description, _searchQuery);
              break;
            }
            
            for (final video in module.videos) {
              if (video.title.toLowerCase().contains(_searchQuery)) {
                matchingModuleTitle = module.title;
                matchingVideoTitle = video.title;
                break;
              }
            }
            if (matchingModuleTitle != null) break;
          }
        } catch (e) {
          print('Error fetching details for topic ${topic.title}: $e');
        }
      }
      
      if (topicMatches || matchingModuleTitle != null) {
        results.add(_SearchResult(
          topic: topic,
          matchingModuleTitle: matchingModuleTitle,
          matchingVideoTitle: matchingVideoTitle,
          isModuleDescriptionMatch: isDescriptionMatch,
          matchedDescription: matchedDescriptionText,
          searchQuery: _searchQuery,
        ));
      }
    }
    
    print('✅ Found ${results.length} results for "$_searchQuery"');
    
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  Future<void> _searchCoursesForQuery(String query) async {
    print('📊 Search called with query: "$query", topics loaded: ${_topics.length}');
    
    if (_topics.isEmpty || query.trim().isEmpty) {
      print('⚠️ Skipping search: topics=${_topics.length}, query="${query.trim()}"');
      return;
    }
    
    final searchQuery = query.toLowerCase().trim();
    print('🔍 Searching courses for: "$searchQuery"');
    
    List<_SearchResult> results = [];
    
    for (final topic in _topics) {
      String? matchingModuleTitle;
      String? matchingVideoTitle;
      bool topicMatches = false;
      bool isDescriptionMatch = false;
      String? matchedDescriptionText;
      
      // Always search in modules and videos first (more specific)
      try {
        final detailResp = await _api.fetchTopicDetail(topic.id);
        final modules = detailResp.topic.modules;
        
        for (final module in modules) {
          // Check module title match
          if (module.title.toLowerCase().contains(searchQuery)) {
            matchingModuleTitle = module.title;
            break;
          }
          
          // Check module description match
          if (module.description.toLowerCase().contains(searchQuery)) {
            matchingModuleTitle = module.title;
            isDescriptionMatch = true;
            matchedDescriptionText = _extractDescriptionSnippet(module.description, searchQuery);
            break;
          }
          
          // Check video titles
          for (final video in module.videos) {
            if (video.title.toLowerCase().contains(searchQuery)) {
              matchingModuleTitle = module.title;
              matchingVideoTitle = video.title;
              break;
            }
          }
          if (matchingModuleTitle != null) break;
        }
      } catch (e) {
        print('Error searching topic ${topic.title}: $e');
      }
      
      // If no module/video match, check topic-level matches
      if (matchingModuleTitle == null) {
        if (topic.title.toLowerCase().contains(searchQuery) ||
            topic.categoryName.toLowerCase().contains(searchQuery) ||
            (topic.subcategoryName?.toLowerCase().contains(searchQuery) ?? false) ||
            (topic.description?.toLowerCase().contains(searchQuery) ?? false)) {
          topicMatches = true;
        }
      }
      
      // Add result if any match found
      if (topicMatches || matchingModuleTitle != null) {
        results.add(_SearchResult(
          topic: topic,
          matchingModuleTitle: matchingModuleTitle,
          matchingVideoTitle: matchingVideoTitle,
          isModuleDescriptionMatch: isDescriptionMatch,
          matchedDescription: matchedDescriptionText,
          searchQuery: searchQuery,
        ));
      }
    }
    
    print('✅ Found ${results.length} course matches');
    
    // Add search results as bot messages
    if (results.isNotEmpty && mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'I found ${results.length} relevant course${results.length > 1 ? "s" : ""} for you:',
          isUser: false,
          timestamp: DateTime.now(),
          searchResults: results,
        ));
      });
      _scrollToBottom();
    }
  }
  
  void _navigateToTopic(CourseTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicDetailScreen(topic: topic),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    // Empty state - no search query yet
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Search topics, modules, or descriptions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Type keywords to find courses',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // No results found
    if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final topic = result.topic;
        final matchingModuleTitle = result.matchingModuleTitle;
        final matchingVideoTitle = result.matchingVideoTitle;
        final isModuleDescMatch = result.isModuleDescriptionMatch;
        final matchedDescription = result.matchedDescription;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _navigateToTopic(topic),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: TopicImage(
                        imageUrl: topic.thumbnailUrl,
                        title: topic.title,
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main Title
                        if (matchingModuleTitle != null)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: matchingVideoTitle != null 
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  matchingVideoTitle != null 
                                      ? Icons.play_circle_outline 
                                      : Icons.article_outlined,
                                  size: 14,
                                  color: matchingVideoTitle != null 
                                      ? const Color(0xFFD97706) 
                                      : const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  matchingVideoTitle ?? matchingModuleTitle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          TranslatedText(
                            topic.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        
                        const SizedBox(height: 6),
                        
                        // Topic Title (when showing module/video match)
                        if (matchingModuleTitle != null)
                          Row(
                            children: [
                              Icon(
                                Icons.topic_outlined,
                                size: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TranslatedText(
                                  topic.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        
                        // Match Type Badge
                        if (matchingModuleTitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: matchingVideoTitle != null
                                        ? const Color(0xFFFEF3C7)
                                        : isModuleDescMatch
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: matchingVideoTitle != null
                                          ? const Color(0xFFEAB308)
                                          : isModuleDescMatch
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF3B82F6),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    matchingVideoTitle != null
                                        ? 'Video Match'
                                        : isModuleDescMatch
                                            ? 'Description Match'
                                            : 'Module Match',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: matchingVideoTitle != null
                                          ? const Color(0xFFD97706)
                                          : isModuleDescMatch
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Description Snippet
                        if (matchedDescription != null && matchedDescription.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.format_quote,
                                      size: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Matched Content:',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildHighlightedText(matchedDescription, _searchQuery),
                              ],
                            ),
                          ),
                        
                        // Category (for topic-level matches)
                        if (matchingModuleTitle == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.category_outlined,
                                  size: 12,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                const SizedBox(width: 4),
                                TranslatedText(
                                  topic.categoryName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Arrow Icon
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: const Color(0xFFD1D5DB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Restore normal orientation when leaving chatbot
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    WidgetsBinding.instance.removeObserver(this);
    _localizationService.removeListener(_onLanguageChanged);
    _textController.dispose();
    _scrollController.dispose();
    _translationService.stop();
    _api.dispose();
    // Properly stop speech recognition
    if (_isListening) {
      _speechToText.stop();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Stop speech recognition when app goes to background to prevent busy state
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isListening) {
        _stopListening();
      }
    }
  }

  // Called when language changes
  void _onLanguageChanged() {
    setState(() {
      _currentLanguage = _localizationService.languageCode;
      // Don't automatically change voice search language - keep it as English by default
      // Users can manually change it if needed
    });
    print('🌐 Chatbot language changed to: $_currentLanguage');
    print('🎤 Voice search language remains: $_voiceSearchLanguage');
  }

  Future<void> _initializeSpeech() async {
    await _translationService.initializeTts();
    
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        await _speechToText.initialize(
          onError: (error) {
            print('Speech recognition error: $error');
            if (mounted) {
              setState(() => _isListening = false);
            }
          },
          onStatus: (status) {
            print('Speech recognition status: $status');
            if (mounted) {
              if (status == 'done' || status == 'notListening') {
                setState(() => _isListening = false);
              }
            }
          },
        );
      } catch (e) {
        print('Failed to initialize speech recognition: $e');
      }
    }
  }

  void _addWelcomeMessage() {
    final welcomeText = _currentLanguage == 'hi'
        ? '''नमस्ते! मैं आपका साइबर सुरक्षा सहायक हूं। 🤖

मैं आपकी मदद कर सकता हूं:
• साइबर सुरक्षा विषयों की खोज करने में
• विस्तृत जानकारी प्रदान करने में  
• सुरक्षा प्रश्नों के उत्तर देने में

आप हिंदी, तेलुगु या अंग्रेजी में पूछ सकते हैं। कैसे मदद कर सकता हूं?'''
        : _currentLanguage == 'te'
        ? '''హలో! నేను మీ సైబర్ సెక్యూరిటీ అసిస్టెంట్‌ని. 🤖

నేను మీకు సహాయం చేయగలను:
• సైబర్ సెక్యూరిటీ విషయాలను వెతకడంలో
• వివరణాత్మక సమాచారం అందించడంలో
• భద్రతా ప్రశ్నలకు జవాబులు ఇవ్వడంలో

మీరు తెలుగు, హిందీ లేదా ఇంగ్లీషులో అడగవచ్చు. ఎలా సహాయం చేయగలను?'''
        : '''Hello! I'm your Cyber Security Assistant. 🤖

I can help you with:
• Searching cyber security topics
• Providing detailed information
• Answering security questions

You can ask in English, Hindi, or Telugu. I have access to comprehensive cyber security knowledge. How can I help you today?''';

    setState(() {
      _messages.add(ChatMessage(
        text: welcomeText,
        isUser: false,
        timestamp: DateTime.now(),
        language: _currentLanguage,
      ));
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();
    
    // Resume chatbot if it was stopped
    if (_chatbotService.isStopped) {
      _chatbotService.resume();
    }
    
    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // First, search for relevant courses in background
      print('🎯 About to search courses for: "$text"');
      await _searchCoursesForQuery(text);
      print('✅ Course search completed');
      
      // Check if search results were added (last message is from bot with searchResults)
      final hasSearchResults = _messages.isNotEmpty && 
                               !_messages.last.isUser && 
                               _messages.last.searchResults != null &&
                               _messages.last.searchResults!.isNotEmpty;
      
      // Detect the language of user input
      final detectedLang = _translationService.detectLanguage(text);
      
      // Only add chatbot response if no search results were found
      if (!hasSearchResults) {
        // Get chatbot response directly in detected language
        final directResponse = _chatbotService.getResponse(text, detectedLang);
        
        // Add bot response - ALWAYS reset loading state first
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              text: directResponse,
              isUser: false,
              timestamp: DateTime.now(),
              language: detectedLang, // Store the language for reference
            ));
            _isLoading = false; // Reset loading immediately after getting response
          });

          _scrollToBottom();
        }
        
        // Speak the response in the detected language
        try {
          final ttsLangCode = _translationService.getTtsLanguageCode(detectedLang);
          
          // Add timeout to TTS to prevent hanging
          await _translationService.speak(directResponse, ttsLangCode)
              .timeout(const Duration(seconds: 10));
        } catch (ttsError) {
          // Silent TTS error handling
        }
      } else {
        // Search results were shown, just reset loading state
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      
    } catch (e) {
      print('❌ Error processing message: $e');
      
      // ALWAYS reset loading state in case of error
      if (mounted) {
        // Fallback: use current app language
        final response = _chatbotService.getResponse(text, _currentLanguage);
        
        setState(() {
          _messages.add(ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            language: _currentLanguage,
          ));
          _isLoading = false; // Ensure loading is reset
        });

        _scrollToBottom();
      }

      // Try TTS with error handling
      try {
        final ttsLangCode = _translationService.getTtsLanguageCode(_currentLanguage);
        await _translationService.speak(
          _chatbotService.getResponse(text, _currentLanguage), 
          ttsLangCode
        ).timeout(const Duration(seconds: 10));
      } catch (ttsError) {
        // Silent TTS error handling
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechToText.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Speech recognition not available')),
      );
      return;
    }

    // Check if already listening to prevent error_busy
    if (_speechToText.isListening) {
      print('Speech recognition already listening, stopping first');
      await _speechToText.stop();
      await Future.delayed(const Duration(milliseconds: 100)); // Small delay to ensure it stops
    }

    await _translationService.stop(); // Stop any ongoing speech

    try {
      setState(() => _isListening = true);

      // Use dedicated voice search language (defaults to English)
      String localeId = _translationService.getTtsLanguageCode(_voiceSearchLanguage);
      
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult && mounted) {
            _handleSubmitted(result.recognizedWords);
            setState(() => _isListening = false);
          }
        },
        localeId: localeId,
        partialResults: false, // Only get final results to avoid issues
        cancelOnError: true, // Cancel on error to reset state
        listenMode: stt.ListenMode.confirmation, // More reliable mode
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      if (mounted) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech recognition error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    } finally {
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  void _showVoiceLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice Search Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose the language for voice recognition:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            
            _buildVoiceLanguageOption('English', 'en', '🇺🇸'),
            const SizedBox(height: 12),
            _buildVoiceLanguageOption('हिन्दी', 'hi', '🇮🇳'),
            const SizedBox(height: 12),
            _buildVoiceLanguageOption('తెలుగు', 'te', '🇮🇳'),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Stop all ongoing processes (chatbot, TTS, speech recognition)
  Future<void> _stopAllProcesses() async {
    try {
      // Stop chatbot service
      _chatbotService.stop();
      
      // Stop TTS
      await _translationService.stop();
      
      // Stop speech recognition
      if (_isListening) {
        await _stopListening();
      }
      
      // Reset loading state
      setState(() {
        _isLoading = false;
      });
      
      // Show feedback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const TranslatedText('All processes stopped'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error stopping processes: $e');
    }
  }

  /// Resume the chatbot
  void _resumeChatbot() {
    _chatbotService.resume();
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const TranslatedText('Chatbot resumed'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildVoiceLanguageOption(String language, String code, String flag) {
    final isSelected = _voiceSearchLanguage == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _voiceSearchLanguage = code;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice search language set to $language'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                language,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Use shorter title for narrow screens
            final isNarrow = constraints.maxWidth < 300;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: TranslatedText(
                    isNarrow ? 'Cyber Assistant' : 'Cyber Security Assistant',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // Voice language selector - compact version
          GestureDetector(
            onTap: _showVoiceLanguageSelector,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.language,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _voiceSearchLanguage.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          if (_showSearch)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  print('⌨️ Search input changed: "$value"');
                  _onSearchChanged(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search topics, modules, descriptions...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          
          // Search Results or Chat messages
          Expanded(
            child: _showSearch
                ? _buildSearchResults(theme)
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            TranslatedText(
                              'Start a conversation',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _ChatBubble(message: _messages[index]);
                        },
                      ),
          ),

          // Loading indicator
          if (_isLoading && !_chatbotService.isStopped)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TranslatedText(
                    'Thinking...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(Tap stop to cancel)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  // Voice input button
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? theme.colorScheme.error : theme.colorScheme.primary,
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                    tooltip: _isListening ? 'Stop listening' : 'Voice input',
                  ),
                  // Stop/Resume button beside microphone  
                  IconButton(
                    icon: Icon(
                      _chatbotService.isStopped ? Icons.play_circle_outline 
                        : (_isLoading || _isListening) ? Icons.stop_circle 
                        : Icons.pause_circle_outline,
                      color: (_isLoading || _isListening) ? Colors.red 
                        : _chatbotService.isStopped ? Colors.green 
                        : theme.colorScheme.primary,
                    ),
                    onPressed: _isLoading || _isListening ? _stopAllProcesses 
                      : (_chatbotService.isStopped ? _resumeChatbot : _stopAllProcesses),
                    tooltip: _isLoading || _isListening ? 'Stop all' 
                      : (_chatbotService.isStopped ? 'Resume' : 'Pause'),
                  ),

                  // Text input
                  Expanded(
                    child: _ChatTextField(
                      controller: _textController,
                      onSubmitted: _handleSubmitted,
                      enabled: !_isLoading && !_isListening,
                      theme: theme,
                      isStopped: _chatbotService.isStopped,
                    ),
                  ),

                  // Send button
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: (_isLoading || _isListening)
                          ? theme.colorScheme.onSurface.withOpacity(0.3)
                          : _chatbotService.isStopped
                            ? Colors.orange
                            : theme.colorScheme.primary,
                    ),
                    onPressed: (_isLoading || _isListening)
                        ? null
                        : _chatbotService.isStopped
                          ? () {
                              _chatbotService.resume();
                              _handleSubmitted(_textController.text);
                            }
                          : () => _handleSubmitted(_textController.text),
                    tooltip: _chatbotService.isStopped 
                        ? 'Tap to resume and send'
                        : _isLoading || _isListening
                          ? 'Please wait...'
                          : 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? language;
  final List<_SearchResult>? searchResults;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.language,
    this.searchResults,
  });
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.smart_toy,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16).copyWith(
                  topLeft: message.isUser ? const Radius.circular(16) : Radius.zero,
                  topRight: message.isUser ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language indicator for bot messages
                  if (!message.isUser && message.language != null && message.language != 'en')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.language == 'hi' ? 'हिंदी' : 
                          message.language == 'te' ? 'తెలుగు' : 'EN',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: message.isUser
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  // Display search results as clickable cards
                  if (message.searchResults != null && message.searchResults!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: message.searchResults!.take(5).map((result) {
                          return _CourseResultCard(
                            result: result,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TopicDetailScreen(topic: result.topic),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.person,
                size: 20,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatTextField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final bool enabled;
  final ThemeData theme;
  final bool isStopped;

  const _ChatTextField({
    required this.controller,
    required this.onSubmitted,
    required this.enabled,
    required this.theme,
    this.isStopped = false,
  });

  @override
  State<_ChatTextField> createState() => _ChatTextFieldState();
}

class _ChatTextFieldState extends State<_ChatTextField> {
  final LocalizationService _localizationService = LocalizationService();
  String _hintText = 'Ask your question...';

  @override
  void initState() {
    super.initState();
    _updateHintText();
    _localizationService.addListener(_updateHintText);
  }

  @override
  void dispose() {
    _localizationService.removeListener(_updateHintText);
    super.dispose();
  }

  Future<void> _updateHintText() async {
    final translationService = TranslationService();
    final translated = await translationService.translate(
      'Ask your question...',
      'en',
      _localizationService.languageCode,
    );
    if (mounted) {
      setState(() => _hintText = translated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        hintText: widget.isStopped 
          ? 'Chatbot is paused - you can type but need to resume to send' 
          : _hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: widget.isStopped 
            ? BorderSide(color: Colors.orange.withOpacity(0.5))
            : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: widget.isStopped 
            ? BorderSide(color: Colors.orange.withOpacity(0.3))
            : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: widget.isStopped 
            ? BorderSide(color: Colors.orange, width: 2)
            : BorderSide(color: widget.theme.colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: widget.isStopped 
          ? Colors.orange.withOpacity(0.05)
          : widget.theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        prefixIcon: widget.isStopped 
          ? Icon(
              Icons.pause_circle_outline, 
              color: Colors.orange,
            ) 
          : null,
      ),
      textInputAction: TextInputAction.send,
      onSubmitted: widget.isStopped 
        ? null 
        : (widget.enabled ? widget.onSubmitted : null),
      enabled: widget.enabled,
    );
  }
}

// Course result card widget with clean, efficient layout
class _CourseResultCard extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _CourseResultCard({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final matchingModuleTitle = result.matchingModuleTitle;
    final matchingVideoTitle = result.matchingVideoTitle;
    final isModuleDescMatch = result.isModuleDescriptionMatch;
    final matchedDescription = result.matchedDescription;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row - Image + Title + Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: TopicImage(
                          imageUrl: result.topic.thumbnailUrl,
                          title: result.topic.title,
                          width: 56,
                          height: 56,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Title and Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Topic Title
                          TranslatedText(
                            result.topic.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Category
                          Text(
                            result.topic.categoryName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Arrow
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: const Color(0xFFD1D5DB),
                    ),
                  ],
                ),
                
                // Module/Video Match Info
                if (matchingModuleTitle != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Match Type Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: matchingVideoTitle != null
                                    ? const Color(0xFFFEF3C7)
                                    : isModuleDescMatch
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    matchingVideoTitle != null
                                        ? Icons.play_circle_outline
                                        : isModuleDescMatch
                                            ? Icons.description_outlined
                                            : Icons.article_outlined,
                                    size: 10,
                                    color: matchingVideoTitle != null
                                        ? const Color(0xFFD97706)
                                        : isModuleDescMatch
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    matchingVideoTitle != null
                                        ? 'Video'
                                        : isModuleDescMatch
                                            ? 'Description'
                                            : 'Module',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: matchingVideoTitle != null
                                          ? const Color(0xFFD97706)
                                          : isModuleDescMatch
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Module/Video Title
                        Text(
                          matchingVideoTitle ?? matchingModuleTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Description Snippet (if found)
                if (matchedDescription != null && matchedDescription.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 12,
                              color: const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Found in description:',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildHighlightedText(matchedDescription, result.searchQuery),
                      ],
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
}
