import 'api_client.dart';
import 'enhanced_search_service.dart';

// Data classes for enhanced search functionality
class SearchResult {
  final bool found;
  final String response;
  final List<TopicDetail> relatedTopics;

  SearchResult({
    required this.found,
    required this.response,
    required this.relatedTopics,
  });
}

class ContentMatch {
  final TopicDetail topic;
  final int relevanceScore;
  final List<String> matchedContent;

  ContentMatch({
    required this.topic,
    required this.relevanceScore,
    required this.matchedContent,
  });
}

class BasicTopicMatch {
  final CourseTopic topic;
  final int relevanceScore;
  final List<String> matchedContent;

  BasicTopicMatch({
    required this.topic,
    required this.relevanceScore,
    required this.matchedContent,
  });
}

/// Enhanced chatbot service with topic search capabilities
class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  final ThinkCyberApi _api = ThinkCyberApi();
  final EnhancedSearchService _searchService = EnhancedSearchService();
  List<CourseTopic> _topics = [];
  List<TopicDetail> _topicDetails = [];
  bool _topicsLoaded = false;
  bool _detailsLoaded = false;
  
  // Stop functionality
  bool _isStopped = false;
  
  /// Stop all ongoing chatbot operations
  void stop() {
    print('🛑 Chatbot service stopped by user');
    _isStopped = true;
  }
  
  /// Resume chatbot operations
  void resume() {
    print('▶️ Chatbot service resumed');
    _isStopped = false;
  }
  
  /// Check if chatbot is stopped
  bool get isStopped => _isStopped;
  
  /// Get stopped message in appropriate language
  String _getStoppedMessage(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return '⏸️ **चैटबॉट रोक दिया गया है**\n\nचैटबॉट को फिर से शुरू करने के लिए कृपया फिर से शुरू बटन दबाएं।';
      case 'te':
        return '⏸️ **చాట్‌బాట్ ఆపివేయబడింది**\n\nచాట్‌బాట్‌ను మళ్లీ ప్రారంభించడానికి దయచేసి రీస్టార్ట్ బటన్‌ను నొక్కండి।';
      default:
        return '⏸️ **Chatbot Stopped**\n\nThe chatbot has been stopped. Please press the resume button to continue the conversation.';
    }
  }

  /// Initialize topics data and their detailed content for search functionality
  Future<void> initializeTopics() async {
    if (_topicsLoaded && _detailsLoaded) return;
    
    try {
      print('🔄 Initializing chatbot topics...');
      
      // First load all topics
      if (!_topicsLoaded) {
        final response = await _api.fetchTopics(userId: 1)
            .timeout(const Duration(seconds: 15));
        
        _topics = response.topics;
        _topicsLoaded = true;
        print('✅ Chatbot topics loaded successfully: ${_topics.length} topics');
      }
      
      // Then load detailed content for each topic
      if (!_detailsLoaded && _topics.isNotEmpty) {
        print('🔄 Loading detailed content for all topics...');
        _topicDetails = [];
        int successCount = 0;
        int failCount = 0;
        
        for (int i = 0; i < _topics.length; i++) {
          try {
            final topic = _topics[i];
            print('🔄 Loading details for topic ${i + 1}/${_topics.length}: ${topic.title} (ID: ${topic.id})');
            
            final detailResponse = await _api.fetchTopicDetail(topic.id, userId: 1)
                .timeout(const Duration(seconds: 15));
            
            if (detailResponse.success && detailResponse.topic != null) {
              _topicDetails.add(detailResponse.topic!);
              successCount++;
              print('✅ ${topic.title}: ${detailResponse.topic!.modules.length} modules');
            } else {
              failCount++;
              print('❌ ${topic.title}: failed');
              print('   - topic != null: ${detailResponse.topic != null}');
            }
            
            // Small delay to prevent overwhelming the API
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            failCount++;
            print('❌ ${_topics[i].title}: ${e.runtimeType.toString()}');
          }
        }
        
        _detailsLoaded = true;
        print('✅ Topic details loading completed: ${successCount} success, ${failCount} failed, ${_topicDetails.length} total detailed topics');
      }
      
      // Initialize enhanced search service if we have data
      if (_topics.isNotEmpty || _topicDetails.isNotEmpty) {
        try {
          await _searchService.initialize();
          print('🎯 Enhanced search service initialized for chatbot');
        } catch (e) {
          print('⚠️ Enhanced search service initialization failed: $e');
        }
      }
      
    } catch (e) {
      print('❌ Failed to load topics for chatbot: $e');
      _topics = [];
      _topicDetails = [];
      _topicsLoaded = false;
      _detailsLoaded = false;
      // Don't throw error - chatbot should work even without API topics
    }
  }

  /// Search for topics based on user query
  List<CourseTopic> searchTopics(String query) {
    if (_topics.isEmpty || query.trim().isEmpty) return [];

    final searchQuery = query.toLowerCase().trim();

    return _topics.where((topic) {
      return topic.title.toLowerCase().contains(searchQuery)
          || topic.categoryName.toLowerCase().contains(searchQuery)
          || (topic.subcategoryName?.toLowerCase().contains(searchQuery) ?? false)
          || topic.description.toLowerCase().contains(searchQuery)
          || topic.difficulty.toLowerCase().contains(searchQuery);
    }).take(5).toList(); // Limit to top 5 results
  }

  /// Search through detailed topic content for comprehensive answers using enhanced search
  SearchResult searchDetailedContent(String query) {
    print('🔍 Enhanced search: "$query" (${_topicDetails.length} details, ${_topics.length} topics)');
    
    if (query.trim().isEmpty) {
      print('❌ Empty query');
      return SearchResult(found: false, response: '', relatedTopics: []);
    }
    
    // Use enhanced search service if available
    if (_searchService.isReady) {
      return _performEnhancedSearch(query);
    }
    
    // Fallback to original search logic
    print('⚠️ Enhanced search not ready, using fallback search...');
    
    // Debug: Show available topic titles for comparison
    if (_topicDetails.isNotEmpty) {
      print('📚 Available topics: ${_topicDetails.take(5).map((t) => t.title).join(', ')}...');
    }

    // If no detailed content available, try enhanced basic search
    if (_topicDetails.isEmpty) {
      print('⚠️ No detailed content available, trying enhanced basic search...');
      return _searchBasicTopicsEnhanced(query);
    }

    final searchQuery = query.toLowerCase().trim();
    final searchTerms = _extractSearchKeywords(searchQuery);
    
    print('🔍 Search terms: $searchTerms');

    List<ContentMatch> matches = [];

    // Search through all detailed topics
    for (final topicDetail in _topicDetails) {
      int relevanceScore = 0;
      List<String> matchedContent = [];

      // Check title and description
      if (_containsAnyKeyword(topicDetail.title.toLowerCase(), searchTerms)) {
        relevanceScore += 10;
        matchedContent.add('Title: ${topicDetail.title}');
      }

      if (_containsAnyKeyword(topicDetail.description.toLowerCase(), searchTerms)) {
        relevanceScore += 8;
        matchedContent.add('Description: ${_extractRelevantText(topicDetail.description, searchTerms)}');
      }

      // Search through modules
      if (topicDetail.modules.isNotEmpty) {
        for (final module in topicDetail.modules) {
          if (_containsAnyKeyword(module.title.toLowerCase(), searchTerms)) {
            relevanceScore += 6;
            matchedContent.add('Module: ${module.title}');
          }

          if (_containsAnyKeyword(module.description.toLowerCase(), searchTerms)) {
            relevanceScore += 4;
            matchedContent.add('Module Content: ${_extractRelevantText(module.description, searchTerms)}');
          }

          // Search through module videos if available
          if (module.videos.isNotEmpty) {
            for (final video in module.videos) {
              if (_containsAnyKeyword(video.title.toLowerCase(), searchTerms)) {
                relevanceScore += 3;
                matchedContent.add('Video: ${video.title}');
              }
            }
          }
        }
      }

      if (relevanceScore > 0) {
        matches.add(ContentMatch(
          topic: topicDetail,
          relevanceScore: relevanceScore,
          matchedContent: matchedContent.take(3).toList(), // Limit to top 3 matches per topic
        ));
      }
    }

    // Sort by relevance score and take top results
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    final topMatches = matches.take(2).toList(); // Top 2 most relevant topics

    if (topMatches.isEmpty) {
      return SearchResult(found: false, response: '', relatedTopics: []);
    }

    // Build comprehensive response from matched content
    final response = _buildDetailedResponse(topMatches, searchQuery);
    final relatedTopics = topMatches.map((match) => match.topic).toList();

    return SearchResult(
      found: true,
      response: response,
      relatedTopics: relatedTopics,
    );
  }

  /// Extract relevant keywords from search query
  List<String> _extractSearchKeywords(String query) {
    // Remove common stop words but preserve important symbols like &
    final stopWords = ['what', 'is', 'the', 'how', 'can', 'you', 'tell', 'me', 'about', 'explain', 'show', 'find', 'search', 'and', 'or', 'of', 'to', 'in', 'for', 'with'];
    
    // First, add the complete original query (most important for exact matches)
    final keywords = <String>[];
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isNotEmpty) {
      keywords.add(cleanQuery);
    }
    
    // Extract individual words while preserving & and other meaningful chars
    final words = query.split(RegExp(r'\s+'))
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
    
    // Add meaningful individual words
    for (final word in words) {
      // Clean word but preserve & and common tech symbols
      final cleanWord = word.replaceAll(RegExp(r'[^\w&\-\+]'), '');
      if (cleanWord.isNotEmpty && !keywords.contains(cleanWord)) {
        keywords.add(cleanWord);
      }
    }
    
    // Add common variations for threat modeling
    if (cleanQuery.contains('threat') && cleanQuery.contains('model')) {
      keywords.addAll(['threat-modeling', 'threatmodeling', 'threat_modeling']);
    }
    
    // Add common variations for testing
    if (cleanQuery.contains('test')) {
      keywords.addAll(['testing', 'tests']);
    }
    
    print('🔍 Extracted keywords: $keywords');
    return keywords;
  }

  /// Check if text contains any of the keywords
  bool _containsAnyKeyword(String text, List<String> keywords) {
    final lowerText = text.toLowerCase();
    
    // Check for exact matches first (highest priority)
    for (final keyword in keywords) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }
    
    // Check for fuzzy matches for complex terms
    for (final keyword in keywords) {
      // Handle special cases like "threat modeling & testing"
      if (keyword.contains('&')) {
        final parts = keyword.split('&').map((p) => p.trim()).toList();
        if (parts.every((part) => lowerText.contains(part))) {
          return true;
        }
      }
      
      // Handle hyphenated terms
      if (keyword.contains('-')) {
        final noDash = keyword.replaceAll('-', ' ');
        if (lowerText.contains(noDash)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Extract relevant text snippet around matched keywords
  String _extractRelevantText(String text, List<String> keywords, {int maxLength = 150}) {
    for (final keyword in keywords) {
      final index = text.toLowerCase().indexOf(keyword);
      if (index != -1) {
        final start = (index - 50).clamp(0, text.length);
        final end = (index + maxLength).clamp(0, text.length);
        String snippet = text.substring(start, end);
        
        if (start > 0) snippet = '...$snippet';
        if (end < text.length) snippet = '$snippet...';
        
        return snippet.trim();
      }
    }
    
    // If no specific keyword match, return first part of text
    return text.length > maxLength 
        ? '${text.substring(0, maxLength)}...' 
        : text;
  }

  /// Build detailed response from matched content
  String _buildDetailedResponse(List<ContentMatch> matches, String originalQuery) {
    final buffer = StringBuffer();
    
    // Add main answer from the most relevant match
    final topMatch = matches.first;
    
    // Add topic title and description
    buffer.writeln('📚 **${topMatch.topic.title}**\n');
    buffer.writeln('📂 **Category:** ${topMatch.topic.categoryName}');
    buffer.writeln('⚡ **Difficulty:** ${topMatch.topic.difficulty}');
    buffer.writeln('⏱️ **Duration:** ${topMatch.topic.durationMinutes} minutes\n');
    
    if (topMatch.topic.description.isNotEmpty) {
      buffer.writeln('📝 **Description:**');
      buffer.writeln('${topMatch.topic.description}\n');
    }
    
    // Add learning objectives if available
    if (topMatch.topic.learningObjectives.isNotEmpty) {
      buffer.writeln('🎯 **Learning Objectives:**');
      buffer.writeln('${topMatch.topic.learningObjectives}\n');
    }
    
    // Add modules information in clean list format
    if (topMatch.topic.modules.isNotEmpty) {
      buffer.writeln('📖 **Course Modules:**');
      for (int i = 0; i < topMatch.topic.modules.length; i++) {
        final module = topMatch.topic.modules[i];
        buffer.writeln('${i + 1}. **${module.title}**');
        if (module.description.isNotEmpty) {
          buffer.writeln('   ${module.description}');
        }
        if (module.videos.isNotEmpty) {
          buffer.writeln('   📹 ${module.videos.length} video${module.videos.length > 1 ? 's' : ''}');
        }
        buffer.writeln();
      }
    }
    
    // Add related topics if there are more matches
    if (matches.length > 1) {
      buffer.writeln('🔗 **Related Topics:**');
      for (int i = 1; i < matches.length && i < 3; i++) {
        buffer.writeln('• ${matches[i].topic.title}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('💡 **Would you like to know more about any specific module?**');
    
    return buffer.toString();
  }

  /// Get response based on user query (enhanced with topic search)
  String getResponse(String userQuery, String languageCode) {
    // Check if chatbot is stopped
    if (_isStopped) {
      return _getStoppedMessage(languageCode);
    }
    
    try {
      final query = userQuery.toLowerCase().trim();
      
      // Handle empty queries
      if (query.isEmpty) {
        return _getResponses(languageCode)['help']!;
      }

      // Define responses for each language
      final responses = _getResponses(languageCode);

    // Check for greetings
    if (_containsAny(query, ['hello', 'hi', 'hey', 'namaste', 'नमस्ते', 'హలో'])) {
      return responses['greeting']!;
    }

    // Check for help
    if (_containsAny(query, ['help', 'assist', 'support', 'मदद', 'సహాయం'])) {
      return responses['help']!;
    }

    // Check for category-based searches FIRST (before detailed search)
    if (_containsAny(query, ['category', 'categories', 'श्रेणी', 'వర్గం']) || 
        _containsAny(query, ['show categories', 'list categories', 'display categories'])) {
      return _buildCategoryResponse(languageCode);
    }

    // Special handling for complex topic names like "threat modeling & testing"
    if (query.contains('threat') && (query.contains('model') || query.contains('test'))) {
      print('🎯 Special handling for threat modeling query: "$query"');
      // Force search for threat-related topics
      final threatResult = searchDetailedContent('threat modeling testing compliance privacy');
      if (threatResult.found) {
        return threatResult.response;
      }
    }

    // Check for difficulty-based searches
    if (_containsAny(query, ['beginner', 'easy', 'basic', 'शुरुआती', 'आसान', 'ప్రారంభ', 'సులువు'])) {
      return _buildDifficultyResponse('beginner', languageCode);
    }

    if (_containsAny(query, ['intermediate', 'medium', 'मध्यम', 'మధ్యస్థ'])) {
      return _buildDifficultyResponse('intermediate', languageCode);
    }

    if (_containsAny(query, ['advanced', 'expert', 'hard', 'difficult', 'उन्नत', 'कठिन', 'అధునాతన', 'కష్టం'])) {
      return _buildDifficultyResponse('advanced', languageCode);
    }

    // Check for recommendation requests
    if (_containsAny(query, ['recommend', 'suggest', 'what should', 'सुझाव', 'सिफारिश', 'సిఫార్సు', 'సూచన'])) {
      return _buildRecommendationResponse(languageCode);
    }

    // Check for module-specific requests
    if (_containsAny(query, ['modules', 'module', 'lessons', 'chapters', 'मॉड्यूल', 'పాఠాలు']) ||
        _containsAny(query, ['modules for', 'show modules', 'list modules'])) {
      return _handleModuleRequest(query, languageCode);
    }

    // Check for enrollment requests
    if (_containsAny(query, ['enroll', 'enrollment', 'register', 'join', 'दाखिला', 'నమోదు']) ||
        _containsAny(query, ['enroll in', 'how to enroll', 'registration'])) {
      return _handleEnrollmentRequest(query, languageCode);
    }

    // Check for specific cybersecurity topics (built-in responses)
    if (_containsAny(query, ['phishing', 'फिशिंग', 'ఫిషింగ్'])) {
      return responses['phishing']!;
    }

    if (_containsAny(query, ['malware', 'virus', 'मैलवेयर', 'మాల్వేర్'])) {
      return responses['malware']!;
    }

    if (_containsAny(query, ['password', 'पासवर्ड', 'పాస్‌వర్డ్'])) {
      return responses['password']!;
    }

    if (_containsAny(query, ['vpn', 'वीपीएन', 'వీపీఎన్'])) {
      return responses['vpn']!;
    }

    if (_containsAny(query, ['encryption', 'एन्क्रिप्शन', 'ఎన్క్రిప్షన్'])) {
      return responses['encryption']!;
    }

    if (_containsAny(query, ['firewall', 'फ़ायरवॉल', 'ఫైర్‌వాల్'])) {
      return responses['firewall']!;
    }

    // Now check for explicit search requests or content-related queries
    if (_containsAny(query, ['search', 'find', 'look for', 'show me', 'tell me about', 'about', 'explain', 'what is', 'how to', 'खोजें', 'खोज', 'చూపించు', 'వెతుకు', 'के बारे में', 'గురించి', 'क्या है', 'कैसे', 'ఎలా', 'ఏమిటి']) 
        || _isContentQuery(query)) {
      
      // First try detailed content search
      final detailedResult = searchDetailedContent(userQuery);
      if (detailedResult.found) {
        return _translateResponse(detailedResult.response, languageCode);
      }
      
      // Fallback to basic topic search
      final searchTerms = _extractSearchTerms(query);
      if (searchTerms.isNotEmpty) {
        final foundTopics = searchTopics(searchTerms);
        if (foundTopics.isNotEmpty) {
          return _buildTopicSearchResponse(foundTopics, languageCode);
        }
      }
      
      // If no results found, return a polite "not found" message
      return _buildNotFoundResponse(userQuery, languageCode);
    }

    // Enhanced topic search for any other queries - search detailed content first
    final detailedResult = searchDetailedContent(userQuery);
    if (detailedResult.found) {
      return _translateResponse(detailedResult.response, languageCode);
    }

    // Fallback to basic topic search
    final foundTopics = searchTopics(userQuery);
    if (foundTopics.isNotEmpty) {
      return _buildTopicSearchResponse(foundTopics, languageCode);
    }

    // Check for list/show requests
    if (_containsAny(query, ['list', 'show', 'display', 'सूची', 'दिखाएं', 'జాబితా', 'చూపించు'])) {
      if (_containsAny(query, ['all', 'topics', 'सभी', 'विषय', 'అన్ని', 'టాపిక్'])) {
        return _buildAllTopicsResponse(languageCode);
      }
    }

    // Check for general cyber security queries
    if (_containsAny(query, ['cyber security', 'cybersecurity', 'cyber', 'security', 'साइबर सुरक्षा', 'साइबर', 'सुरक्षा', 'సైబర్ సెక్యూరిటీ', 'సైబర్', 'సెక్యూరిటీ'])) {
      return _buildCyberSecurityInfoResponse(query, languageCode);
    }

    // Check for course questions
    if (_containsAny(query, ['course', 'courses', 'learn', 'study', 'कोर्स', 'కోర్సు'])) {
      return responses['course']!;
    }

    // Check for quiz questions
    if (_containsAny(query, ['quiz', 'test', 'exam', 'क्विज', 'క్విజ్'])) {
      return responses['quiz']!;
    }

    // Check for goodbye
    if (_containsAny(query, ['bye', 'goodbye', 'see you', 'अलविदा', 'వీడ్కోలు'])) {
      return responses['goodbye']!;
    }

    // Default response
    return responses['default']!;
    
    } catch (e) {
      print('❌ Error in chatbot getResponse: $e');
      // Emergency fallback - always return a response
      switch (languageCode) {
        case 'hi':
          return 'क्षमा करें, मुझे कुछ तकनीकी समस्या हो रही है। कृपया फिर से प्रयास करें।';
        case 'te':
          return 'క్షమించండి, నాకు కొంత టెక్నికల్ సమస్య ఉంది. దయచేసి మళ్లీ ప్రయత్నించండి.';
        default:
          return 'Sorry, I\'m experiencing some technical issues. Please try again.';
      }
    }
  }

  /// Build response for topic search results
  String _buildTopicSearchResponse(List<CourseTopic> topics, String languageCode) {
    final topicList = topics.map((topic) => '• ${topic.title} (${topic.categoryName})').join('\n');
    
    switch (languageCode) {
      case 'hi':
        return 'मैंने आपकी खोज के लिए ${topics.length} विषय पाए हैं:\n\n$topicList\n\nक्या आप किसी विशिष्ट विषय के बारे में अधिक जानना चाहते हैं?';
      case 'te':
        return 'మీ శోధన కోసం నేను ${topics.length} టాపిక్‌లను కనుగొన్నాను:\n\n$topicList\n\nమీరు ఏదైనా నిర్దిష్ట టాపిక్ గురించి మరింత తెలుసుకోవాలనుకుంటున్నారా?';
      default:
        return 'I found ${topics.length} topics matching your search:\n\n$topicList\n\nWould you like to know more about any specific topic?';
    }
  }

  /// Build response for category information
  String _buildCategoryResponse(String languageCode) {
    if (_topics.isEmpty) {
      return _getResponses(languageCode)['course']!;
    }

    final categories = _topics.map((t) => t.categoryName).toSet().toList()..sort();
    final categoryList = categories.map((cat) => '• $cat').join('\n');

    switch (languageCode) {
      case 'hi':
        return 'उपलब्ध श्रेणियां हैं:\n\n$categoryList\n\nकिसी भी श्रेणी के नाम से खोजें या उसके बारे में पूछें!';
      case 'te':
        return 'అందుబాటులో ఉన్న వర్గాలు:\n\n$categoryList\n\nఏదైనా వర్గం పేరుతో శోధించండి లేదా దాని గురించి అడగండి!';
      default:
        return 'Available categories are:\n\n$categoryList\n\nSearch by any category name or ask about it!';
    }
  }

  /// Build response for difficulty-based searches
  String _buildDifficultyResponse(String difficulty, String languageCode) {
    final filteredTopics = _topics.where((topic) => 
      topic.difficulty.toLowerCase().contains(difficulty.toLowerCase())).take(5).toList();

    if (filteredTopics.isEmpty) {
      switch (languageCode) {
        case 'hi':
          return 'मुझे $difficulty स्तर के लिए कोई विषय नहीं मिला। कृपया अन्य कठिनाई स्तर आज़माएं।';
        case 'te':
          return '$difficulty స్థాయి కోసం నాకు ఏ టాపిక్‌లు కనుగొనబడలేदు. దయచేసి ఇతర కష్టతా స్థాయిని ప్రయత్నించండి।';
        default:
          return 'I couldn\'t find any topics for $difficulty level. Please try other difficulty levels.';
      }
    }

    final topicList = filteredTopics.map((topic) => '• ${topic.title} (${topic.categoryName})').join('\n');
    
    switch (languageCode) {
      case 'hi':
        return '$difficulty स्तर के विषय:\n\n$topicList\n\nकोई विशिष्ट विषय चुनें या अधिक जानकारी के लिए पूछें!';
      case 'te':
        return '$difficulty స్థాయి టాపిక్‌లు:\n\n$topicList\n\nఏదైనా నిర్దిష్ట టాపిక్‌ను ఎంచుకోండి లేదా మరింత సమాచారం కోసం అడగండి!';
      default:
        return '$difficulty level topics:\n\n$topicList\n\nChoose any specific topic or ask for more information!';
    }
  }

  /// Build recommendation response
  String _buildRecommendationResponse(String languageCode) {
    if (_topics.isEmpty) {
      return _getResponses(languageCode)['course']!;
    }

    // Get featured or beginner-friendly topics
    final recommended = _topics.where((topic) => 
      topic.isFeatured || topic.difficulty.toLowerCase().contains('beginner')).take(3).toList();

    if (recommended.isEmpty) {
      // Fallback to first 3 topics if no featured/beginner topics
      recommended.addAll(_topics.take(3));
    }

    final topicList = recommended.map((topic) => '• ${topic.title} (${topic.categoryName}) - ${topic.difficulty}').join('\n');
    
    switch (languageCode) {
      case 'hi':
        return 'मैं इन विषयों की सिफारिश करता हूं:\n\n$topicList\n\nइन्हें शुरू करने के लिए बेहतरीन हैं!';
      case 'te':
        return 'నేను ఈ టాపిక్‌లను సిఫార్సు చేస్తున్नాను:\n\n$topicList\n\nవీటితో ప్రారంభించడం చాలా మంచిది!';
      default:
        return 'I recommend these topics:\n\n$topicList\n\nThese are great to get started with!';
    }
  }

  /// Perform enhanced search using the enhanced search service (async wrapper)
  Future<SearchResult> _performEnhancedSearchAsync(String query) async {
    try {
      // Use the enhanced search service for comprehensive results
      final results = await _searchService.search(query, config: const SearchConfig(
        maxResults: 10,
        fuzzyMatchEnabled: true,
        semanticSearchEnabled: true,
        includeContentSnippets: true,
      ));
      
      if (results.isEmpty) {
        return SearchResult(found: false, response: '', relatedTopics: []);
      }
      
      // Convert enhanced results to chatbot response
      final response = _buildEnhancedSearchResponse(results, query);
      final relatedTopics = results
          .where((r) => r.topic != null)
          .map((r) => _convertToTopicDetail(r.topic!))
          .where((t) => t != null)
          .cast<TopicDetail>()
          .toList();
          
      return SearchResult(
        found: true,
        response: response,
        relatedTopics: relatedTopics,
      );
      
    } catch (e) {
      print('❌ Enhanced search failed: $e');
      return _searchBasicTopicsEnhanced(query);
    }
  }

  /// Synchronous enhanced search with fallback
  SearchResult _performEnhancedSearch(String query) {
    // Try enhanced search synchronously if possible, otherwise use fallback
    try {
      // For immediate response, use enhanced basic search which is more comprehensive
      // than the original basic search but still synchronous
      return _searchBasicTopicsEnhanced(query);
    } catch (e) {
      print('❌ Enhanced search failed: $e');
      return SearchResult(found: false, response: '', relatedTopics: []);
    }
  }
  
  /// Build response from enhanced search results
  String _buildEnhancedSearchResponse(List<EnhancedSearchResult> results, String query) {
    final buffer = StringBuffer();
    
    final topResult = results.first;
    
    // Add main answer from the most relevant match
    buffer.writeln('🎯 **${topResult.title}**\n');
    
    if (topResult.contentSnippet != null && topResult.contentSnippet!.isNotEmpty) {
      buffer.writeln('${topResult.contentSnippet}\n');
    } else {
      buffer.writeln('${topResult.description}\n');
    }
    
    // Add match information
    if (topResult.matches.isNotEmpty) {
      buffer.writeln('🔍 **Key Points:**');
      for (final match in topResult.matches.take(3)) {
        final context = '${match.contextBefore}**${match.matchedText}**${match.contextAfter}';
        buffer.writeln('• ${context.trim()}');
      }
      buffer.writeln();
    }
    
    // Add related topics if available
    if (results.length > 1) {
      buffer.writeln('🔗 **Related Topics:**');
      for (int i = 1; i < results.length && i <= 3; i++) {
        final result = results[i];
        buffer.writeln('• ${result.title} (${result.type})');
      }
      buffer.writeln();
    }
    
    // Add metadata information
    if (topResult.metadata.isNotEmpty) {
      final category = topResult.metadata['category'];
      final difficulty = topResult.metadata['difficulty'];
      
      if (category != null || difficulty != null) {
        buffer.writeln('📋 **Details:**');
        if (category != null) buffer.writeln('• Category: $category');
        if (difficulty != null) buffer.writeln('• Level: $difficulty');
        buffer.writeln();
      }
    }
    
    buffer.writeln('💡 **Need more specific information?** Ask me about any particular aspect!');
    
    return buffer.toString();
  }
  
  /// Convert CourseTopic to TopicDetail for compatibility
  TopicDetail? _convertToTopicDetail(CourseTopic topic) {
    // Find matching topic detail if available
    try {
      return _topicDetails.firstWhere((detail) => detail.id == topic.id);
    } catch (e) {
      // Create basic TopicDetail from CourseTopic
      return TopicDetail(
        id: topic.id,
        title: topic.title,
        description: topic.description,
        categoryId: 0,
        categoryName: topic.categoryName,
        subcategoryId: null,
        subcategoryName: topic.subcategoryName,
        difficulty: topic.difficulty,
        status: topic.status,
        isFree: topic.isFree,
        price: topic.price,
        durationMinutes: 0,
        thumbnailUrl: topic.thumbnailUrl,
        isFeatured: topic.isFeatured,
        isPaid: topic.isPaid,
        isEnrolled: topic.isEnrolled,
        paymentStatus: null,
        learningObjectives: '',
        targetAudience: [],
        prerequisites: '',
        modules: [],
      );
    }
  }

  /// Enhanced search through basic topics when detailed content is not available
  SearchResult _searchBasicTopicsEnhanced(String query) {
    final searchTerms = _extractSearchKeywords(query);
    print('🔍 Enhanced basic search with terms: $searchTerms');
    
    List<BasicTopicMatch> matches = [];
    
    for (final topic in _topics) {
      int relevanceScore = 0;
      List<String> matchedContent = [];
      
      // Check title
      if (_containsAnyKeyword(topic.title.toLowerCase(), searchTerms)) {
        relevanceScore += 10;
        matchedContent.add('Title Match: ${topic.title}');
        print('✅ Title match in: ${topic.title}');
      }
      
      // Check description
      if (_containsAnyKeyword(topic.description.toLowerCase(), searchTerms)) {
        relevanceScore += 8;
        matchedContent.add('Description: ${_extractRelevantText(topic.description, searchTerms)}');
        print('✅ Description match in: ${topic.title}');
      }
      
      // Check category
      if (_containsAnyKeyword(topic.categoryName.toLowerCase(), searchTerms)) {
        relevanceScore += 6;
        matchedContent.add('Category: ${topic.categoryName}');
        print('✅ Category match in: ${topic.categoryName}');
      }
      
      if (relevanceScore > 0) {
        matches.add(BasicTopicMatch(
          topic: topic,
          relevanceScore: relevanceScore,
          matchedContent: matchedContent,
        ));
      }
    }
    
    // Sort by relevance
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    final topMatches = matches.take(2).toList();
    
    if (topMatches.isEmpty) {
      return SearchResult(found: false, response: '', relatedTopics: []);
    }
    
    // Build response from basic topic info
    final response = _buildBasicTopicResponse(topMatches, query);
    return SearchResult(
      found: true,
      response: response,
      relatedTopics: [], // No detailed topics available
    );
  }

  /// Build response from basic topic matches
  String _buildBasicTopicResponse(List<BasicTopicMatch> matches, String originalQuery) {
    final buffer = StringBuffer();
    
    final topMatch = matches.first;
    
    // Add topic information
    buffer.writeln('📚 **${topMatch.topic.title}**\n');
    buffer.writeln('📂 **Category:** ${topMatch.topic.categoryName}');
    
    if (topMatch.topic.subcategoryName != null && topMatch.topic.subcategoryName!.isNotEmpty) {
      buffer.writeln('📁 **Subcategory:** ${topMatch.topic.subcategoryName}');
    }
    
    buffer.writeln('⚡ **Difficulty:** ${topMatch.topic.difficulty}\n');
    
    // Add description
    if (topMatch.topic.description.isNotEmpty) {
      buffer.writeln('📝 **Description:**');
      buffer.writeln('${topMatch.topic.description}\n');
    }
    
    // Add related topics
    if (matches.length > 1) {
      buffer.writeln('🔗 **Related Topics:**');
      for (int i = 1; i < matches.length && i < 3; i++) {
        buffer.writeln('• ${matches[i].topic.title}');
      }
      buffer.writeln();
    }
    
    buffer.writeln('💡 **Ask "modules for ${topMatch.topic.title}" to see the course modules**');
    
    return buffer.toString();
  }

  /// Handle module-specific requests
  String _handleModuleRequest(String query, String languageCode) {
    // Extract topic name from query
    final topicName = _extractTopicNameFromQuery(query);
    
    if (topicName.isNotEmpty) {
      // Find matching topic
      final matchingTopic = _topics.where((topic) => 
        topic.title.toLowerCase().contains(topicName.toLowerCase())).firstOrNull;
      
      if (matchingTopic != null) {
        // Try to get detailed modules for this specific topic
        return _getModulesForTopic(matchingTopic, languageCode);
      }
    }
    
    // If no specific topic found, show general module info
    return _buildGeneralModuleResponse(languageCode);
  }

  /// Get modules for a specific topic (try detailed first, then fallback)
  String _getModulesForTopic(CourseTopic topic, String languageCode) {
    // First check if we already have detailed info for this topic
    final detailedTopic = _topicDetails.where((detail) => detail.id == topic.id).firstOrNull;
    
    if (detailedTopic != null && detailedTopic.modules.isNotEmpty) {
      // We have detailed module info, show it
      return _buildDetailedModuleResponse(detailedTopic, languageCode);
    }
    
    // No detailed info available, try to load it now
    _loadTopicDetailAsync(topic.id);
    
    // Return basic info for now
    return _buildModuleInfoResponse(topic, languageCode);
  }

  /// Load topic detail asynchronously (for future requests)
  Future<void> _loadTopicDetailAsync(int topicId) async {
    try {
      print('🔄 Loading details for topic ID: $topicId on-demand');
      final detailResponse = await _api.fetchTopicDetail(topicId, userId: 1)
          .timeout(const Duration(seconds: 10));
      
      if (detailResponse.success && detailResponse.topic != null) {
        // Check if we already have this topic
        if (!_topicDetails.any((t) => t.id == topicId)) {
          _topicDetails.add(detailResponse.topic!);
          print('✅ On-demand loaded details for topic ID: $topicId - Modules: ${detailResponse.topic!.modules.length}');
        }
      }
    } catch (e) {
      print('❌ Failed to load topic details on-demand for ID: $topicId - $e');
    }
  }

  /// Build detailed module response when we have module information
  String _buildDetailedModuleResponse(TopicDetail topic, String languageCode) {
    final buffer = StringBuffer();
    
    // Format price with rupee symbol
    String getPriceText() {
      if (topic.isFree || topic.price == 0) {
        return languageCode == 'hi' ? 'निःशुल्क' : languageCode == 'te' ? 'ఉచితం' : 'Free';
      } else {
        final price = topic.price;
        if (price % 1 == 0) {
          return '₹${price.toInt()}';
        } else {
          return '₹${price.toStringAsFixed(2)}';
        }
      }
    }
    
    switch (languageCode) {
      case 'hi':
        buffer.writeln('📚 **${topic.title}**\n');
        buffer.writeln('📂 **Category:** ${topic.categoryName}');
        buffer.writeln('⚡ **Difficulty:** ${topic.difficulty}');
        buffer.writeln('⏱️ **Duration:** ${topic.durationMinutes} minutes');
        buffer.writeln('💰 **Price:** ${getPriceText()}\n');
        
        if (topic.description.isNotEmpty) {
          buffer.writeln('📝 **विवरण:**');
          buffer.writeln('${topic.description}\n');
        }
        
        if (topic.modules.isNotEmpty) {
          buffer.writeln('📖 **कोर्स मॉड्यूल (${topic.modules.length}):**');
          for (int i = 0; i < topic.modules.length; i++) {
            final module = topic.modules[i];
            buffer.writeln('${i + 1}. **${module.title}**');
            if (module.description.isNotEmpty) {
              buffer.writeln('   ${module.description}');
            }
            if (module.videos.isNotEmpty) {
              buffer.writeln('   📹 ${module.videos.length} वीडियो${module.videos.length > 1 ? 'स' : ''}');
            }
            buffer.writeln();
          }
        }
        break;
        
      case 'te':
        buffer.writeln('📚 **${topic.title}**\n');
        buffer.writeln('📂 **Category:** ${topic.categoryName}');
        buffer.writeln('⚡ **Difficulty:** ${topic.difficulty}');
        buffer.writeln('⏱️ **Duration:** ${topic.durationMinutes} minutes');
        buffer.writeln('💰 **Price:** ${getPriceText()}\n');
        
        if (topic.description.isNotEmpty) {
          buffer.writeln('📝 **వివరణ:**');
          buffer.writeln('${topic.description}\n');
        }
        
        if (topic.modules.isNotEmpty) {
          buffer.writeln('📖 **కోర్స్ మాడ్యూల్స్ (${topic.modules.length}):**');
          for (int i = 0; i < topic.modules.length; i++) {
            final module = topic.modules[i];
            buffer.writeln('${i + 1}. **${module.title}**');
            if (module.description.isNotEmpty) {
              buffer.writeln('   ${module.description}');
            }
            if (module.videos.isNotEmpty) {
              buffer.writeln('   📹 ${module.videos.length} వీడియో${module.videos.length > 1 ? 'లు' : ''}');
            }
            buffer.writeln();
          }
        }
        break;
        
      default:
        buffer.writeln('📚 **${topic.title}**\n');
        buffer.writeln('📂 **Category:** ${topic.categoryName}');
        buffer.writeln('⚡ **Difficulty:** ${topic.difficulty}');
        buffer.writeln('⏱️ **Duration:** ${topic.durationMinutes} minutes');
        buffer.writeln('💰 **Price:** ${getPriceText()}\n');
        
        if (topic.description.isNotEmpty) {
          buffer.writeln('📝 **Description:**');
          buffer.writeln('${topic.description}\n');
        }
        
        if (topic.modules.isNotEmpty) {
          buffer.writeln('📖 **Course Modules (${topic.modules.length}):**');
          for (int i = 0; i < topic.modules.length; i++) {
            final module = topic.modules[i];
            buffer.writeln('${i + 1}. **${module.title}**');
            if (module.description.isNotEmpty) {
              buffer.writeln('   ${module.description}');
            }
            if (module.videos.isNotEmpty) {
              buffer.writeln('   📹 ${module.videos.length} video${module.videos.length > 1 ? 's' : ''}');
            }
            buffer.writeln();
          }
        } else {
          buffer.writeln('⚠️ **Module details are being loaded. Please try again in a moment.**\n');
        }
        break;
    }
    
    buffer.writeln('💡 **Would you like to know more about any specific module?**');
    return buffer.toString();
  }

  /// Handle enrollment requests
  String _handleEnrollmentRequest(String query, String languageCode) {
    final topicName = _extractTopicNameFromQuery(query);
    
    if (topicName.isNotEmpty) {
      final matchingTopic = _topics.where((topic) => 
        topic.title.toLowerCase().contains(topicName.toLowerCase())).firstOrNull;
      
      if (matchingTopic != null) {
        return _buildEnrollmentInfoResponse(matchingTopic, languageCode);
      }
    }
    
    return _buildGeneralEnrollmentResponse(languageCode);
  }

  /// Extract topic name from user query
  String _extractTopicNameFromQuery(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Check for patterns like "modules for [topic]" or "enroll in [topic]"
    final patterns = [
      RegExp(r'modules for (.+)', caseSensitive: false),
      RegExp(r'enroll in (.+)', caseSensitive: false),
      RegExp(r'about (.+)', caseSensitive: false),
      RegExp(r'tell me about (.+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    
    // Enhanced fallback: check for topic matches with fuzzy matching
    for (final topic in _topics) {
      final topicTitle = topic.title.toLowerCase();
      
      // Exact match
      if (lowerQuery.contains(topicTitle)) {
        return topic.title;
      }
      
      // Fuzzy match for complex topics like "threat modeling & testing"
      if (topicTitle.contains('&')) {
        final parts = topicTitle.split('&').map((p) => p.trim()).toList();
        if (parts.every((part) => lowerQuery.contains(part))) {
          return topic.title;
        }
      }
      
      // Handle common variations (- vs space, etc.)
      final normalized = topicTitle.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
      if (lowerQuery.contains(normalized)) {
        return topic.title;
      }
      
      // Word-by-word matching for multi-word topics
      final topicWords = topicTitle.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
      final queryWords = lowerQuery.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
      
      int matches = 0;
      for (final topicWord in topicWords) {
        if (queryWords.any((qw) => qw.contains(topicWord) || topicWord.contains(qw))) {
          matches++;
        }
      }
      
      // If most words match, consider it a match
      if (matches >= (topicWords.length * 0.6)) {
        return topic.title;
      }
    }
    
    return '';
  }

  /// Build module information response for a specific topic
  String _buildModuleInfoResponse(CourseTopic topic, String languageCode) {
    // Format price with rupee symbol
    String getPriceText() {
      if (topic.isFree || topic.price == 0) {
        return languageCode == 'hi' ? 'निःशुल्क' : languageCode == 'te' ? 'ఉచితం' : 'Free';
      } else {
        final price = topic.price;
        if (price % 1 == 0) {
          return '₹${price.toInt()}';
        } else {
          return '₹${price.toStringAsFixed(2)}';
        }
      }
    }
    
    switch (languageCode) {
      case 'hi':
        return '''📚 **${topic.title}**

📂 **Category:** ${topic.categoryName}
⚡ **Difficulty:** ${topic.difficulty}
💰 **Price:** ${getPriceText()}

📝 **Description:**
${topic.description}

⚠️ **Detailed module list requires enrollment access.**

💡 **To see full modules, you need to enroll in this course.**''';

      case 'te':
        return '''📚 **${topic.title}**

📂 **Category:** ${topic.categoryName}
⚡ **Difficulty:** ${topic.difficulty}
💰 **Price:** ${getPriceText()}

📝 **Description:**
${topic.description}

⚠️ **పూర్తి మాడ్యూల జాబితా కోసం నమోదు అవసరం.**

💡 **పూర్తి మాడ్యూల్స్ చూడటానికి ఈ కోర్సులో నమోదు చేసుకోవాలి.**''';

      default:
        return '''📚 **${topic.title}**

📂 **Category:** ${topic.categoryName}
⚡ **Difficulty:** ${topic.difficulty}
💰 **Price:** ${getPriceText()}

📝 **Description:**
${topic.description}

⚠️ **Detailed module list requires enrollment access.**

💡 **To see the full list of modules and their content, you need to enroll in this course.**''';
    }
  }

  /// Build enrollment information response
  String _buildEnrollmentInfoResponse(CourseTopic topic, String languageCode) {
    // Format price with rupee symbol
    String getPriceText() {
      if (topic.isFree || topic.price == 0) {
        return languageCode == 'hi' ? 'निःशुल्क' : languageCode == 'te' ? 'ఉచితం' : 'Free';
      } else {
        final price = topic.price;
        if (price % 1 == 0) {
          return '₹${price.toInt()}';
        } else {
          return '₹${price.toStringAsFixed(2)}';
        }
      }
    }
    
    switch (languageCode) {
      case 'hi':
        return '''📝 **${topic.title}** में नामांकन:

📂 **Category:** ${topic.categoryName}
⚡ **Difficulty:** ${topic.difficulty}
💰 **Price:** ${getPriceText()}

📝 **Description:**
${topic.description}

💡 **To enroll in this course, please visit the main app and search for this topic.**''';

      case 'te':
        return '''📝 **${topic.title}** నమోదు:

📂 **Category:** ${topic.categoryName}
⚡ **Difficulty:** ${topic.difficulty}
💰 **Price:** ${getPriceText()}

📝 **Description:**
${topic.description}

💡 **ఈ కోర్సులో నమోదు చేయడానికి, దయచేసి మెయిన్ యాప్‌ను సందర్శించి ఈ టాపిక్‌ను వెతకండి.**''';

      default:
        return '''📝 **Enrollment for ${topic.title}**

📚 **Category:** ${topic.categoryName}
⚡ **Difficulty:** ${topic.difficulty}

📝 **Description:**
${topic.description}

💡 **To enroll in this course, please visit the main app and search for this topic.**

🎯 **What You'll Get:**
• Access to all course modules
• Interactive learning content
• Progress tracking
• Completion certificates''';
    }
  }

  /// Build general module response
  String _buildGeneralModuleResponse(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return '''📚 **Module की जानकारी:**

कोई specific topic के modules देखने के लिए:
• "modules for [topic name]" कहें
• जैसे: "modules for App Developer"

उपलब्ध topics देखने के लिए "show categories" कहें।''';

      case 'te':
        return '''📚 **మాడ్యూల సమాచారం:**

ఏదైనా నిర్దిష్ట టాపిక్ మాడ్యూల्स చూడటానికి:
• "modules for [topic name]" అని అడగండి
• ఉదాహరణ: "modules for App Developer"

అందుబాటులో ఉన్న టాపిక్‌లను చూడటానికి "show categories" అని చెప్పండి।''';

      default:
        return '''📚 **Module Information:**

To see modules for a specific topic:
• Ask "modules for [topic name]"
• Example: "modules for App Developer"

Say "show categories" to see all available topics first.''';
    }
  }

  /// Build general enrollment response
  String _buildGeneralEnrollmentResponse(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return '''📝 **नामांकन की जानकारी:**

किसी topic में enroll करने के लिए:
• "enroll in [topic name]" कहें
• जैसे: "enroll in App Developer"

पहले उपलब्ध topics देखने के लिए "show categories" कहें।''';

      case 'te':
        return '''📝 **నమోదు సమాచారం:**

ఏదైనా టాపిక్‌లో నమోదు చేయడానికి:
• "enroll in [topic name]" అని అడగండి
• ఉదాహరణ: "enroll in App Developer"

ముందుగా అందుబాటులో ఉన్న టాపిక్‌లను చూడటానికి "show categories" అని చెప్పండి।''';

      default:
        return '''📝 **Enrollment Information:**

To enroll in a specific topic:
• Ask "enroll in [topic name]"
• Example: "enroll in App Developer"

First, say "show categories" to see all available topics.''';
    }
  }

  /// Check if query contains any of the keywords
  bool _containsAny(String query, List<String> keywords) {
    return keywords.any((keyword) => query.contains(keyword.toLowerCase()));
  }

  /// Check if the query is likely asking for content/information
  bool _isContentQuery(String query) {
    final contentIndicators = [
      // Question words
      'what', 'how', 'why', 'when', 'where', 'which', 'who',
      // Cyber security terms
      'phishing', 'malware', 'password', 'security', 'cyber', 'encryption', 'firewall', 'vpn',
      'attack', 'threat', 'virus', 'spam', 'hacker', 'breach', 'protection', 'safe', 'secure',
      'incident', 'response', 'forensics', 'vulnerability', 'penetration', 'testing', 'social',
      'engineering', 'authentication', 'authorization', 'network', 'wireless', 'mobile',
      'cloud', 'endpoint', 'antivirus', 'backup', 'recovery', 'compliance', 'privacy',
      'gdpr', 'risk', 'management', 'awareness', 'training', 'policy', 'procedure',
      // Learning terms
      'learn', 'understand', 'know', 'information', 'details', 'help', 'guide', 'tutorial',
      'course', 'module', 'lesson', 'training', 'certification', 'skills', 'knowledge',
      // Hindi equivalents
      'क्या', 'कैसे', 'क्यों', 'कब', 'कहाँ', 'कौन', 'सुरक्षा', 'साइबर', 'मैलवेयर', 'पासवर्ड',
      // Telugu equivalents
      'ఏమిటి', 'ఎలా', 'ఎందుకు', 'ఎప్పుడు', 'ఎక్కడ', 'ఎవరు', 'సెక్యూరిటీ', 'సైబర్', 'మాల్వేర్', 'పాస్వర్డ్'
    ];
    
    return contentIndicators.any((indicator) => query.contains(indicator));
  }

  /// Build response when no content is found
  String _buildNotFoundResponse(String query, String languageCode) {
    switch (languageCode) {
      case 'hi':
        return '''मुझे "$query" के बारे में विशिष्ट जानकारी नहीं मिली। 😔

कृपया इन तरीकों से पूछें:
• "फ़िशिंग के बारे में बताएं"
• "पासवर्ड सुरक्षा"
• "मैलवेयर क्या है"
• "साइबर सुरक्षा टिप्स"

या "श्रेणियां दिखाएं" कहें सभी उपलब्ध विषय देखने के लिए। मैं फिर से खोजने में आपकी मदद करूंगा! 🔍''';

      case 'te':
        return '''నాకు "$query" గురించి నిర్దిష్ట సమాచారం కనుగొనబడలేदు। 😔

దయచేసి ఈ విధంగా అడగండి:
• "ఫిషింగ్ గురించి చెప్పండి"
• "పాస్‌వర్డ్ సెక్యూరిటీ"
• "మాల్వేర్ అంటే ఏమిటి"
• "సైబర్ సెక్యూరిటీ టిప్స్"

లేదా "వర్గాలు చూపించండి" అని అడగండి అందుబాటులో ఉన్న అన్ని విషయాలను చూడటానికి. నేను మళ్లీ వెతకడంలో మీకు సహాయం చేస్తాను! 🔍''';

      default:
        return '''I couldn't find specific information about "$query". 😔

Please try asking like this:
• "Tell me about phishing"
• "Password security"
• "What is malware"
• "Cyber security tips"

Or say "show categories" to see all available topics. I'll be happy to help you search again! 🔍''';
    }
  }

  /// Translate response to target language (basic implementation)
  String _translateResponse(String response, String targetLanguage) {
    if (targetLanguage == 'en') {
      return response;
    }
    
    // For now, return English response with a note about language
    // In a full implementation, you could integrate with translation service
    switch (targetLanguage) {
      case 'hi':
        return '$response\n\n(मूल उत्तर अंग्रेजी में है - हिंदी अनुवाद जल्द आएगा)';
      case 'te':
        return '$response\n\n(అసలు సమాధానం ఆంగ్లంలో ఉంది - తెలుగు అనువాదం త్వరలో వస్తుంది)';
      default:
        return response;
    }
  }

  /// Extract search terms from search queries
  String _extractSearchTerms(String query) {
    // Remove common search words and extract the actual search terms
    final searchWords = ['search', 'find', 'look for', 'show me', 'tell me about', 'about', 'what is', 'explain', 'खोजें', 'खोज', 'చూపించు', 'వెతుకు', 'के बारे में', 'గురించి', 'बताएं', 'చెప్పండి'];
    String result = query.toLowerCase();
    
    for (final word in searchWords) {
      result = result.replaceAll(word.toLowerCase(), '').trim();
    }
    
    // Remove common filler words
    final fillerWords = ['the', 'a', 'an', 'is', 'are', 'what', 'how', 'me', 'में', 'ల', 'లో', 'को', 'ను'];
    for (final word in fillerWords) {
      result = result.replaceAll(' $word ', ' ').trim();
    }
    
    return result.trim();
  }

  /// Get responses for the specified language
  Map<String, String> _getResponses(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return {
          'greeting': 'नमस्ते! मैं आपका साइबर सुरक्षा सहायक हूं। मैं आपकी कैसे मदद कर सकता हूं?',
          'help': 'मैं आपकी मदद कर सकता हूं:\n• विषय खोजें (जैसे "फ़िशिंग खोजें")\n• श्रेणियां देखें\n• कठिनाई स्तर के अनुसार फ़िल्टर करें\n• सिफारिशें प्राप्त करें\n• साइबर सुरक्षा प्रश्न पूछें\n\nबस पूछें "श्रेणियां दिखाएं" या "शुरुआती विषय"!',
          'phishing': 'फ़िशिंग एक साइबर हमला है जहां हमलावर आपकी व्यक्तिगत जानकारी चुराने के लिए खुद को वैध इकाई के रूप में दिखाते हैं। हमेशा ईमेल भेजने वाले को सत्यापित करें और संदिग्ध लिंक पर क्लिक न करें।',
          'malware': 'मैलवेयर दुर्भावनापूर्ण सॉफ़्टवेयर है जो आपके डिवाइस को नुकसान पहुंचाता है। एंटीवायरस सॉफ़्टवेयर अपडेट रखें, केवल विश्वसनीय स्रोतों से सॉफ़्टवेयर डाउनलोड करें, और संदिग्ध अटैचमेंट खोलने से बचें।',
          'password': 'मजबूत पासवर्ड बनाएं: 12+ अक्षर, अपरकेस, लोअरकेस, संख्या और विशेष वर्ण का मिश्रण। प्रत्येक खाते के लिए अद्वितीय पासवर्ड का उपयोग करें और पासवर्ड मैनेजर का उपयोग करने पर विचार करें।',
          'vpn': 'वीपीएन (वर्चुअल प्राइवेट नेटवर्क) आपके इंटरनेट कनेक्शन को एन्क्रिप्ट करता है और आपके ऑनलाइन डेटा और गोपनीयता की सुरक्षा करता है, खासकर सार्वजनिक वाई-फाई पर।',
          'encryption': 'एन्क्रिप्शन आपके डेटा को कोड में परिवर्तित करता है ताकि केवल अधिकृत पार्टियां ही इसे पढ़ सकें। यह संवेदनशील जानकारी की सुरक्षा के लिए आवश्यक है।',
          'firewall': 'फ़ायरवॉल आपके नेटवर्क और इंटरनेट के बीच एक बाधा के रूप में कार्य करता है, अवांछित ट्रैफ़िक को फ़िल्टर करता है और साइबर खतरों से बचाता है।',
          'course': 'हमारे प्लेटफ़ॉर्म पर फ़िशिंग अटैक, मैलवेयर, पासवर्ड सुरक्षा, वीपीएन और अधिक पर पाठ्यक्रम उपलब्ध हैं। "होम" स्क्रीन पर जाएं और सीखना शुरू करें!',
          'quiz': 'अपने साइबर सुरक्षा ज्ञान का परीक्षण करें! "क्विज़" टैब पर जाएं और चुनौतियां पूरी करें। प्रत्येक क्विज़ में 10 प्रश्न होते हैं।',
          'goodbye': 'अलविदा! सुरक्षित रहें और साइबर सुरक्षित रहें! 👋',
          'default': 'मुझे समझने में परेशानी हो रही है। आप ये कर सकते हैं:\n• "फ़िशिंग खोजें" - विषय खोजने के लिए\n• "श्रेणियां" - सभी श्रेणियां देखने के लिए\n• "शुरुआती विषय" - आसान विषयों के लिए\n• "सिफारिश करें" - सुझाव के लिए',
        };

      case 'te':
        return {
          'greeting': 'హలో! నేను మీ సైబర్ సెక్యూరిటీ అసిస్టెంట్‌ని. నేను మీకు ఎలా సహాయం చేయగలను?',
          'help': 'నేను మీకు సహాయం చేయగలను:\n• టాపిక్‌లను వెతకండి (ఉదా: "ఫిషింగ్ వెతుకు")\n• వర్గాలను చూడండి\n• కష్టతా స్థాయి ప్రకారం ఫిల్టర్ చేయండి\n• సిఫార్సులను పొందండి\n• సైబర్ సెక్యూరిటీ ప్రశ్నలు అడగండి\n\n"వర్గాలు చూపించు" లేదా "ప్రారంభ టాపిక్‌లు" అని అడగండి!',
          'phishing': 'ఫిషింగ్ అనేది దాడి చేసేవారు మీ వ్యక్తిగత సమాచారాన్ని దొంగిలించడానికి చట్టబద్ధ సంస్థగా నటించే సైబర్ దాడి. ఎల్లప్పుడూ పంపినవారిని ధృవీకరించండి మరియు అనుమానాస్పద లింక్‌లపై క్లిక్ చేయవద్దు.',
          'malware': 'మాల్వేర్ అనేది మీ పరికరాన్ని దెబ్బతీసే హానికరమైన సాఫ్ట్‌వేర్. యాంటీవైరస్‌ను అప్‌డేట్‌గా ఉంచండి, విశ్వసనీయ మూలాల నుండి మాత్రమే సాఫ్ట్‌వేర్‌ను డౌన్‌లోడ్ చేయండి మరియు అనుమానాస్పద అటాచ్‌మెంట్‌లను తెరవకండి.',
          'password': 'బలమైన పాస్‌వర్డ్‌లను సృష్టించండి: 12+ అక్షరాలు, అప్పర్‌కేస్, లోయర్‌కేస్, సంఖ్యలు మరియు ప్రత్యేక అక్షరాల మిశ్రమం. ప్రతి ఖాతాకు ప్రత్యేక పాస్‌వర్డ్‌ను ఉపయోగించండి మరియు పాస్‌వర్డ్ మేనేజర్‌ను ఉపయోగించడాన్ని పరిగణించండి.',
          'vpn': 'VPN (వర్చువల్ ప్రైవేట్ నెట్‌వర్క్) మీ ఇంటర్నెట్ కనెక్షన్‌ను ఎన్‌క్రిప్ట్ చేస్తుంది మరియు మీ ఆన్‌లైన్ డేటా మరియు గోప్యతను రక్షిస్తుంది, ముఖ్యంగా పబ్లిక్ Wi-Fiలో.',
          'encryption': 'ఎన్‌క్రిప్షన్ మీ డేటాను కోడ్‌గా మారుస్తుంది కాబట్టి అధికారం ఉన్న పార్టీలు మాత్రమే దాన్ని చదవగలరు. సున్నితమైన సమాచారాన్ని రక్షించడానికి ఇది అవసరం.',
          'firewall': 'ఫైర్‌వాల్ మీ నెట్‌వర్క్ మరియు ఇంటర్నెట్ మధ్య అవరోధంగా పనిచేస్తుంది, అవాంఛిత ట్రాఫిక్‌ను ఫిల్టర్ చేస్తుంది మరియు సైబర్ బెదిరింపుల నుండి రక్షిస్తుంది.',
          'course': 'మా ప్లాట్‌ఫారమ్‌లో ఫిషింగ్ అటాక్స్, మాల్వేర్, పాస్‌వర్డ్ సెక్యూరిటీ, VPN మరియు మరిన్ని కోర్సులు అందుబాటులో ఉన్నాయి. "Home" స్క్రీన్‌కు వెళ్లి నేర్చుకోవడం ప్రారంభించండి!',
          'quiz': 'మీ సైబర్ సెక్యూరిటీ పరిజ్ఞానాన్ని పరీక్షించండి! "Quiz" ట్యాబ్‌కు వెళ్లి సవాళ్లను పూర్తి చేయండి. ప్రతి క్విజ్‌లో 10 ప్రశ్నలు ఉంటాయి.',
          'goodbye': 'వీడ్కోలు! సురక్షితంగా మరియు సైబర్ సురక్షితంగా ఉండండి! 👋',
          'default': 'నేను అర్థం చేసుకోవడంలో ఇబ్బంది పడుతున్నాను. మీరు ఇవి చేయవచ్చు:\n• "ఫిషింగ్ వెతుకు" - టాపిక్‌ల కోసం\n• "వర్గాలు" - అన్ని వర్గాలను చూడడానికి\n• "ప్రారంభ టాపిక్‌లు" - సులువు టాపిక్‌ల కోసం\n• "సిఫార్సు చేయండి" - సూచనల కోసం',
        };

      default: // English
        return {
          'greeting': 'Hello! I\'m your Cyber Security Assistant. How can I help you today?',
          'help': 'I can help you with:\n• Search topics (e.g., "search phishing")\n• View categories\n• Filter by difficulty level\n• Get recommendations\n• Ask cyber security questions\n\nJust ask "show categories" or "beginner topics"!',
          'phishing': 'Phishing is a cyber attack where attackers pretend to be a legitimate entity to steal your personal information. Always verify the sender and don\'t click on suspicious links.',
          'malware': 'Malware is malicious software that harms your device. Keep your antivirus updated, only download software from trusted sources, and avoid opening suspicious attachments.',
          'password': 'Create strong passwords: 12+ characters, mix of uppercase, lowercase, numbers, and special characters. Use unique passwords for each account and consider using a password manager.',
          'vpn': 'A VPN (Virtual Private Network) encrypts your internet connection and protects your online data and privacy, especially on public Wi-Fi.',
          'encryption': 'Encryption converts your data into code so only authorized parties can read it. It\'s essential for protecting sensitive information.',
          'firewall': 'A firewall acts as a barrier between your network and the internet, filtering unwanted traffic and protecting against cyber threats.',
          'course': 'We have courses on Phishing Attacks, Malware, Password Security, VPN, and more available on our platform. Go to the "Home" screen and start learning!',
          'quiz': 'Test your cyber security knowledge! Go to the "Quiz" tab and complete the challenges. Each quiz has 10 questions.',
          'goodbye': 'Goodbye! Stay safe and stay cyber secure! 👋',
          'default': 'I\'m having trouble understanding. You can try:\n• "search phishing" - to find topics\n• "categories" - to see all categories\n• "beginner topics" - for easy topics\n• "recommend" - for suggestions',
        };
    }
  }

  /// Build response showing all available topics
  String _buildAllTopicsResponse(String languageCode) {
    if (_topics.isEmpty) {
      return _getResponses(languageCode)['course']!;
    }

    final totalTopics = _topics.length;
    final sampleTopics = _topics.take(5).toList();
    final topicList = sampleTopics.map((topic) => '• ${topic.title} (${topic.categoryName})').join('\n');
    
    switch (languageCode) {
      case 'hi':
        return 'कुल $totalTopics विषय उपलब्ध हैं। यहां कुछ उदाहरण हैं:\n\n$topicList\n\n${totalTopics > 5 ? "और भी अधिक विषय हैं! " : ""}किसी विशिष्ट विषय या श्रेणी के लिए खोजें।';
      case 'te':
        return 'మొత్తం $totalTopics టాపిక్‌లు అందుబాటులో ఉన్నాయి. ఇక్కడ కొన్ని ఉదాహరణలు:\n\n$topicList\n\n${totalTopics > 5 ? "ఇంకా చాలా టాపిక్‌లు ఉన్నాయి! " : ""}ఏదైనా నిర్దిష్ట టాపిక్ లేదా వర్గం కోసం వెతకండి।';
      default:
        return 'There are $totalTopics topics available. Here are some examples:\n\n$topicList\n\n${totalTopics > 5 ? "Many more topics available! " : ""}Search for any specific topic or category.';
    }
  }

  /// Build general cyber security information response
  String _buildCyberSecurityInfoResponse(String query, String languageCode) {
    // If we have topics loaded, show available cyber security topics
    if (_topics.isNotEmpty) {
      final cyberTopics = _topics.where((topic) => 
        topic.title.toLowerCase().contains('cyber') ||
        topic.title.toLowerCase().contains('security') ||
        topic.categoryName.toLowerCase().contains('cyber') ||
        topic.categoryName.toLowerCase().contains('security') ||
        topic.description.toLowerCase().contains('cyber') ||
        topic.description.toLowerCase().contains('security')).take(5).toList();

      if (cyberTopics.isNotEmpty) {
        return _buildTopicSearchResponse(cyberTopics, languageCode);
      }
    }

    // Provide general cyber security information if no specific topics found
    switch (languageCode) {
      case 'hi':
        return '''साइबर सुरक्षा के मुख्य क्षेत्र:

🛡️ **फ़िशिंग सुरक्षा** - धोखाधड़ी ईमेल से बचाव
🦠 **मैलवेयर सुरक्षा** - वायरस और स्पाइवेयर से सुरक्षा
🔐 **पासवर्ड सुरक्षा** - मजबूत पासवर्ड बनाना
🌐 **नेटवर्क सुरक्षा** - वाई-फाई और इंटरनेट सुरक्षा
🔒 **डेटा एन्क्रिप्शन** - जानकारी को सुरक्षित रखना

इन विषयों के बारे में और जानने के लिए, होम स्क्रीन पर उपलब्ध कोर्स देखें!''';

      case 'te':
        return '''సైబర్ సెక్యూరిటీ ముఖ్య రంగాలు:

🛡️ **ఫిషింగ్ సెక్యూరిటీ** - మోసపూరిత ఇమెయిల్‌ల నుండి రక్షణ
🦠 **మాల్వేర్ సెక్యూరిటీ** - వైరస్ మరియు స్పైవేర్ నుండి రక్షణ
🔐 **పాస్‌వర్డ్ సెక్యూరిటీ** - బలమైన పాస్‌వర్డ్‌లను సృష్టించడం
🌐 **నెట్‌వర్క్ సెక్యూరిటీ** - వై-ఫై మరియు ఇంటర్నెట్ రక్షణ
🔒 **డేటా ఎన్క్రిప్షన్** - సమాచారాన్ని సురక్షితంగా ఉంచడం

ఈ విషయాల గురించి మరింత తెలుసుకోవడానికి, హోమ్ స్క్రీన్‌లో అందుబాటులో ఉన్న కోర్సులను చూడండి!''';

      default:
        return '''Cyber Security Main Areas:

🛡️ **Phishing Protection** - Defense against fraudulent emails
🦠 **Malware Security** - Protection from viruses and spyware
🔐 **Password Security** - Creating strong passwords
🌐 **Network Security** - Wi-Fi and internet protection
🔒 **Data Encryption** - Keeping information secure

To learn more about these topics, check the courses available on the Home screen!''';
    }
  }
}
