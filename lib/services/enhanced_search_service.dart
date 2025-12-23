import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Enhanced search result with detailed match information
class EnhancedSearchResult {
  final String id;
  final String title;
  final String description;
  final String type; // 'topic', 'module', 'video', 'content'
  final double relevanceScore;
  final List<SearchMatch> matches;
  final Map<String, dynamic> metadata;
  final CourseTopic? topic;
  final TopicModule? module;
  final TopicVideo? video;
  final String? contentSnippet;

  EnhancedSearchResult({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.relevanceScore,
    required this.matches,
    required this.metadata,
    this.topic,
    this.module,
    this.video,
    this.contentSnippet,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'relevanceScore': relevanceScore,
    'matches': matches.map((m) => m.toJson()).toList(),
    'metadata': metadata,
    'contentSnippet': contentSnippet,
  };
}

/// Individual match information
class SearchMatch {
  final String field;
  final String matchedText;
  final double confidence;
  final int startIndex;
  final int endIndex;
  final String contextBefore;
  final String contextAfter;

  SearchMatch({
    required this.field,
    required this.matchedText,
    required this.confidence,
    required this.startIndex,
    required this.endIndex,
    required this.contextBefore,
    required this.contextAfter,
  });

  Map<String, dynamic> toJson() => {
    'field': field,
    'matchedText': matchedText,
    'confidence': confidence,
    'startIndex': startIndex,
    'endIndex': endIndex,
    'contextBefore': contextBefore,
    'contextAfter': contextAfter,
  };
}

/// Search configuration options
class SearchConfig {
  final bool fuzzyMatchEnabled;
  final double fuzzyThreshold;
  final bool semanticSearchEnabled;
  final int maxResults;
  final List<String> searchFields;
  final Map<String, double> fieldWeights;
  final bool includeContentSnippets;
  final int snippetLength;
  final bool highlightMatches;

  const SearchConfig({
    this.fuzzyMatchEnabled = true,
    this.fuzzyThreshold = 0.6,
    this.semanticSearchEnabled = true,
    this.maxResults = 50,
    this.searchFields = const ['title', 'description', 'content', 'tags', 'category'],
    this.fieldWeights = const {
      'title': 3.0,
      'description': 2.0,
      'content': 1.0,
      'tags': 2.5,
      'category': 1.5,
    },
    this.includeContentSnippets = true,
    this.snippetLength = 200,
    this.highlightMatches = true,
  });
}

/// Comprehensive search service with advanced capabilities
class EnhancedSearchService {
  static final EnhancedSearchService _instance = EnhancedSearchService._internal();
  factory EnhancedSearchService() => _instance;
  EnhancedSearchService._internal();

  final ThinkCyberApi _api = ThinkCyberApi();
  
  // Cached data
  List<CourseTopic> _topics = [];
  List<TopicDetail> _topicDetails = [];
  Map<String, List<String>> _searchIndex = {};
  Map<String, double> _termFrequency = {};
  bool _isInitialized = false;
  
  // Search statistics
  Map<String, int> _searchStats = {};
  Map<String, List<String>> _popularSearches = {};

  /// Initialize the search service with data
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔍 Initializing Enhanced Search Service...');
      
      // Load topics
      final topicResponse = await _api.fetchTopics();
      _topics = topicResponse.topics;
      print('📚 Loaded ${_topics.length} topics');

      // Load detailed content
      _topicDetails = [];
      int successCount = 0;
      int failCount = 0;

      for (final topic in _topics) {
        try {
          final detailResponse = await _api.fetchTopicDetail(topic.id);
          _topicDetails.add(detailResponse.topic);
          successCount++;
        } catch (e) {
          failCount++;
          print('❌ Failed to load details for topic ${topic.title}: $e');
        }
      }

      print('✅ Loaded $successCount detailed topics, $failCount failed');

      // Build search index
      await _buildSearchIndex();
      
      _isInitialized = true;
      print('🎯 Enhanced Search Service initialized successfully');
      
    } catch (e) {
      print('❌ Failed to initialize Enhanced Search Service: $e');
      throw Exception('Search service initialization failed: $e');
    }
  }

  /// Build inverted index for faster searching
  Future<void> _buildSearchIndex() async {
    print('🔨 Building search index...');
    _searchIndex.clear();
    _termFrequency.clear();

    // Process topics
    for (final topic in _topics) {
      _indexDocument('topic_${topic.id}', [
        topic.title,
        topic.description,
        topic.categoryName,
        topic.subcategoryName ?? '',
        topic.difficulty,
      ]);
    }

    // Process detailed content
    for (final detail in _topicDetails) {
      _indexDocument('detail_${detail.id}', [
        detail.title,
        detail.description,
        detail.learningObjectives,
        detail.prerequisites,
      ]);

      // Index modules
      for (int i = 0; i < detail.modules.length; i++) {
        final module = detail.modules[i];
        _indexDocument('module_${detail.id}_$i', [
          module.title,
          module.description,
        ]);

        // Index videos
        for (int j = 0; j < module.videos.length; j++) {
          final video = module.videos[j];
          _indexDocument('video_${detail.id}_${i}_$j', [
            video.title,
          ]);
        }
      }
    }

    print('✅ Search index built with ${_searchIndex.length} terms');
  }

  /// Add document to search index
  void _indexDocument(String docId, List<String> texts) {
    final allText = texts.join(' ').toLowerCase();
    final words = _extractWords(allText);
    
    for (final word in words) {
      if (word.length < 2) continue; // Skip very short words
      
      _searchIndex.putIfAbsent(word, () => []).add(docId);
      _termFrequency[word] = (_termFrequency[word] ?? 0) + 1;
    }
  }

  /// Extract meaningful words from text
  List<String> _extractWords(String text) {
    // Remove special characters and split
    final cleaned = text.replaceAll(RegExp(r'[^\w\s]'), ' ');
    final words = cleaned.split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    
    // Add n-grams for better phrase matching
    final result = <String>[];
    result.addAll(words);
    
    // Add 2-grams
    for (int i = 0; i < words.length - 1; i++) {
      result.add('${words[i]} ${words[i + 1]}');
    }
    
    // Add 3-grams for important phrases
    for (int i = 0; i < words.length - 2; i++) {
      result.add('${words[i]} ${words[i + 1]} ${words[i + 2]}');
    }
    
    return result;
  }

  /// Perform comprehensive search
  Future<List<EnhancedSearchResult>> search(
    String query, {
    SearchConfig config = const SearchConfig(),
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (query.trim().isEmpty) {
      return [];
    }

    // Track search statistics
    _trackSearch(query);

    final normalizedQuery = query.toLowerCase().trim();
    print('🔍 Enhanced search for: "$normalizedQuery"');

    final results = <EnhancedSearchResult>[];

    // 1. Exact matches (highest priority)
    results.addAll(await _findExactMatches(normalizedQuery, config));

    // 2. Partial matches
    results.addAll(await _findPartialMatches(normalizedQuery, config));

    // 3. Fuzzy matches
    if (config.fuzzyMatchEnabled) {
      results.addAll(await _findFuzzyMatches(normalizedQuery, config));
    }

    // 4. Semantic matches
    if (config.semanticSearchEnabled) {
      results.addAll(await _findSemanticMatches(normalizedQuery, config));
    }

    // Remove duplicates and sort by relevance
    final uniqueResults = _deduplicateResults(results);
    uniqueResults.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    final finalResults = uniqueResults.take(config.maxResults).toList();
    print('✅ Found ${finalResults.length} enhanced search results');
    
    return finalResults;
  }

  /// Find exact matches
  Future<List<EnhancedSearchResult>> _findExactMatches(
    String query,
    SearchConfig config,
  ) async {
    final results = <EnhancedSearchResult>[];
    
    // Search in topics
    for (final topic in _topics) {
      final matches = _findMatches(topic, query, config);
      if (matches.isNotEmpty) {
        final relevanceScore = _calculateRelevanceScore(matches, config, baseScore: 100);
        
        results.add(EnhancedSearchResult(
          id: 'topic_${topic.id}',
          title: topic.title,
          description: topic.description,
          type: 'topic',
          relevanceScore: relevanceScore,
          matches: matches,
          metadata: {
            'category': topic.categoryName,
            'subcategory': topic.subcategoryName,
            'difficulty': topic.difficulty,
            'isFeatured': topic.isFeatured,
            'price': topic.price,
          },
          topic: topic,
          contentSnippet: _generateSnippet(topic.description, query, config.snippetLength),
        ));
      }
    }

    // Search in detailed content
    for (final detail in _topicDetails) {
      final matches = _findDetailMatches(detail, query, config);
      if (matches.isNotEmpty) {
        final relevanceScore = _calculateRelevanceScore(matches, config, baseScore: 95);
        
        results.add(EnhancedSearchResult(
          id: 'detail_${detail.id}',
          title: detail.title,
          description: detail.description,
          type: 'content',
          relevanceScore: relevanceScore,
          matches: matches,
          metadata: {
            'objectives': detail.learningObjectives,
            'prerequisites': detail.prerequisites,
            'moduleCount': detail.modules.length,
          },
          contentSnippet: _generateSnippet(detail.description, query, config.snippetLength),
        ));
      }

      // Search in modules
      for (int i = 0; i < detail.modules.length; i++) {
        final module = detail.modules[i];
        final moduleMatches = _findModuleMatches(module, query, config);
        if (moduleMatches.isNotEmpty) {
          final relevanceScore = _calculateRelevanceScore(moduleMatches, config, baseScore: 90);
          
          results.add(EnhancedSearchResult(
            id: 'module_${detail.id}_$i',
            title: module.title,
            description: module.description,
            type: 'module',
            relevanceScore: relevanceScore,
            matches: moduleMatches,
            metadata: {
              'parentTopic': detail.title,
              'videoCount': module.videos.length,
            },
            module: module,
                        contentSnippet: _generateSnippet(module.description, query, config.snippetLength),
          ));
        }

        // Search in videos
        for (int j = 0; j < module.videos.length; j++) {
          final video = module.videos[j];
          final videoMatches = _findVideoMatches(video, query, config);
          if (videoMatches.isNotEmpty) {
            final relevanceScore = _calculateRelevanceScore(videoMatches, config, baseScore: 85);
            
            results.add(EnhancedSearchResult(
              id: 'video_${detail.id}_${i}_$j',
              title: video.title,
              description: video.title,
              type: 'video',
              relevanceScore: relevanceScore,
              matches: videoMatches,
              metadata: {
                'parentTopic': detail.title,
                'parentModule': module.title,
              },
              video: video,
              contentSnippet: _generateSnippet(video.title, query, config.snippetLength),
            ));
          }
        }
      }
    }

    return results;
  }

  /// Find partial matches using contains logic
  Future<List<EnhancedSearchResult>> _findPartialMatches(
    String query,
    SearchConfig config,
  ) async {
    final results = <EnhancedSearchResult>[];
    final queryWords = _extractWords(query);

    for (final topic in _topics) {
      double partialScore = 0;
      final matches = <SearchMatch>[];

      // Check each field
      for (final field in config.searchFields) {
        final fieldValue = _getFieldValue(topic, field);
        if (fieldValue.isEmpty) continue;

        final fieldWords = _extractWords(fieldValue.toLowerCase());
        int matchingWords = 0;

        for (final queryWord in queryWords) {
          if (fieldWords.any((fw) => fw.contains(queryWord) || queryWord.contains(fw))) {
            matchingWords++;
            
            // Find the actual match position
            final index = fieldValue.toLowerCase().indexOf(queryWord);
            if (index >= 0) {
              matches.add(SearchMatch(
                field: field,
                matchedText: queryWord,
                confidence: 0.7,
                startIndex: index,
                endIndex: index + queryWord.length,
                contextBefore: _getContext(fieldValue, index, -30),
                contextAfter: _getContext(fieldValue, index + queryWord.length, 30),
              ));
            }
          }
        }

        if (matchingWords > 0) {
          final fieldWeight = config.fieldWeights[field] ?? 1.0;
          partialScore += (matchingWords / queryWords.length) * fieldWeight * 60;
        }
      }

      if (matches.isNotEmpty && partialScore > 10) {
        results.add(EnhancedSearchResult(
          id: 'partial_topic_${topic.id}',
          title: topic.title,
          description: topic.description,
          type: 'topic',
          relevanceScore: partialScore,
          matches: matches,
          metadata: {
            'category': topic.categoryName,
            'matchType': 'partial',
          },
          topic: topic,
          contentSnippet: _generateSnippet(topic.description, query, config.snippetLength),
        ));
      }
    }

    return results;
  }

  /// Find fuzzy matches using Levenshtein distance
  Future<List<EnhancedSearchResult>> _findFuzzyMatches(
    String query,
    SearchConfig config,
  ) async {
    final results = <EnhancedSearchResult>[];
    final queryWords = _extractWords(query);

    for (final topic in _topics) {
      double fuzzyScore = 0;
      final matches = <SearchMatch>[];

      final titleWords = _extractWords(topic.title.toLowerCase());
      
      for (final queryWord in queryWords) {
        if (queryWord.length < 3) continue; // Skip short words for fuzzy matching
        
        for (final titleWord in titleWords) {
          if (titleWord.length < 3) continue;
          
          final similarity = _calculateSimilarity(queryWord, titleWord);
          if (similarity >= config.fuzzyThreshold) {
            fuzzyScore += similarity * 40;
            
            matches.add(SearchMatch(
              field: 'title',
              matchedText: titleWord,
              confidence: similarity,
              startIndex: topic.title.toLowerCase().indexOf(titleWord),
              endIndex: topic.title.toLowerCase().indexOf(titleWord) + titleWord.length,
              contextBefore: '',
              contextAfter: '',
            ));
          }
        }
      }

      if (matches.isNotEmpty && fuzzyScore > 20) {
        results.add(EnhancedSearchResult(
          id: 'fuzzy_topic_${topic.id}',
          title: topic.title,
          description: topic.description,
          type: 'topic',
          relevanceScore: fuzzyScore,
          matches: matches,
          metadata: {
            'category': topic.categoryName,
            'matchType': 'fuzzy',
          },
          topic: topic,
          contentSnippet: _generateSnippet(topic.description, query, config.snippetLength),
        ));
      }
    }

    return results;
  }

  /// Find semantic matches using keyword relationships
  Future<List<EnhancedSearchResult>> _findSemanticMatches(
    String query,
    SearchConfig config,
  ) async {
    final results = <EnhancedSearchResult>[];
    
    // Cybersecurity semantic mappings
    final semanticMap = {
      'hacking': ['ethical hacking', 'penetration testing', 'security testing', 'vulnerability assessment'],
      'phishing': ['social engineering', 'email security', 'fraud prevention', 'cyber attacks'],
      'malware': ['virus', 'trojans', 'ransomware', 'security threats', 'antivirus'],
      'network': ['networking', 'firewall', 'vpn', 'network security', 'protocols'],
      'password': ['authentication', 'credentials', 'access control', 'identity management'],
      'encryption': ['cryptography', 'data protection', 'secure communication', 'privacy'],
      'security': ['cybersecurity', 'information security', 'cyber defense', 'protection'],
      'threat': ['risk', 'vulnerability', 'attack', 'breach', 'incident'],
      'privacy': ['data protection', 'confidentiality', 'gdpr', 'compliance'],
      'firewall': ['network security', 'access control', 'traffic filtering', 'perimeter defense'],
    };

    final queryWords = _extractWords(query.toLowerCase());
    final semanticTerms = <String>[];

    for (final word in queryWords) {
      if (semanticMap.containsKey(word)) {
        semanticTerms.addAll(semanticMap[word]!);
      }
    }

    if (semanticTerms.isEmpty) return results;

    for (final topic in _topics) {
      double semanticScore = 0;
      final matches = <SearchMatch>[];

      for (final term in semanticTerms) {
        final allText = '${topic.title} ${topic.description} ${topic.categoryName}'.toLowerCase();
        
        if (allText.contains(term)) {
          semanticScore += 25;
          
          final index = allText.indexOf(term);
          matches.add(SearchMatch(
            field: 'semantic',
            matchedText: term,
            confidence: 0.6,
            startIndex: index,
            endIndex: index + term.length,
            contextBefore: _getContext(allText, index, -20),
            contextAfter: _getContext(allText, index + term.length, 20),
          ));
        }
      }

      if (matches.isNotEmpty && semanticScore > 15) {
        results.add(EnhancedSearchResult(
          id: 'semantic_topic_${topic.id}',
          title: topic.title,
          description: topic.description,
          type: 'topic',
          relevanceScore: semanticScore,
          matches: matches,
          metadata: {
            'category': topic.categoryName,
            'matchType': 'semantic',
          },
          topic: topic,
          contentSnippet: _generateSnippet(topic.description, query, config.snippetLength),
        ));
      }
    }

    return results;
  }

  /// Helper methods for finding matches in different content types
  List<SearchMatch> _findMatches(CourseTopic topic, String query, SearchConfig config) {
    final matches = <SearchMatch>[];
    
    final fields = {
      'title': topic.title,
      'description': topic.description,
      'category': topic.categoryName,
      'subcategory': topic.subcategoryName ?? '',
      'difficulty': topic.difficulty,
    };

    for (final entry in fields.entries) {
      final fieldValue = entry.value.toLowerCase();
      if (fieldValue.contains(query)) {
        final index = fieldValue.indexOf(query);
        matches.add(SearchMatch(
          field: entry.key,
          matchedText: query,
          confidence: 1.0,
          startIndex: index,
          endIndex: index + query.length,
          contextBefore: _getContext(entry.value, index, -30),
          contextAfter: _getContext(entry.value, index + query.length, 30),
        ));
      }
    }

    return matches;
  }

  List<SearchMatch> _findDetailMatches(TopicDetail detail, String query, SearchConfig config) {
    final matches = <SearchMatch>[];
    
    final fields = {
      'title': detail.title,
      'description': detail.description,
      'objectives': detail.learningObjectives,
      'prerequisites': detail.prerequisites,
    };

    for (final entry in fields.entries) {
      final fieldValue = entry.value.toLowerCase();
      if (fieldValue.contains(query)) {
        final index = fieldValue.indexOf(query);
        matches.add(SearchMatch(
          field: entry.key,
          matchedText: query,
          confidence: 1.0,
          startIndex: index,
          endIndex: index + query.length,
          contextBefore: _getContext(entry.value, index, -40),
          contextAfter: _getContext(entry.value, index + query.length, 40),
        ));
      }
    }

    return matches;
  }

  List<SearchMatch> _findModuleMatches(TopicModule module, String query, SearchConfig config) {
    final matches = <SearchMatch>[];
    
    final fields = {
      'title': module.title,
      'description': module.description,
    };

    for (final entry in fields.entries) {
      final fieldValue = entry.value.toLowerCase();
      if (fieldValue.contains(query)) {
        final index = fieldValue.indexOf(query);
        matches.add(SearchMatch(
          field: entry.key,
          matchedText: query,
          confidence: 1.0,
          startIndex: index,
          endIndex: index + query.length,
          contextBefore: _getContext(entry.value, index, -50),
          contextAfter: _getContext(entry.value, index + query.length, 50),
        ));
      }
    }

    return matches;
  }

  List<SearchMatch> _findVideoMatches(TopicVideo video, String query, SearchConfig config) {
    final matches = <SearchMatch>[];
    
    final fields = {
      'title': video.title,
    };

    for (final entry in fields.entries) {
      final fieldValue = entry.value.toLowerCase();
      if (fieldValue.contains(query)) {
        final index = fieldValue.indexOf(query);
        matches.add(SearchMatch(
          field: entry.key,
          matchedText: query,
          confidence: 1.0,
          startIndex: index,
          endIndex: index + query.length,
          contextBefore: _getContext(entry.value, index, -60),
          contextAfter: _getContext(entry.value, index + query.length, 60),
        ));
      }
    }

    return matches;
  }

  /// Calculate relevance score based on matches
  double _calculateRelevanceScore(List<SearchMatch> matches, SearchConfig config, {double baseScore = 50}) {
    double score = baseScore;
    
    for (final match in matches) {
      final fieldWeight = config.fieldWeights[match.field] ?? 1.0;
      score += match.confidence * fieldWeight * 20;
    }
    
    // Bonus for multiple matches
    if (matches.length > 1) {
      score *= 1.2;
    }
    
    return score.clamp(0, 200);
  }

  /// Calculate text similarity using Levenshtein distance
  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    final distance = _levenshteinDistance(a, b);
    final maxLen = max(a.length, b.length);
    return 1.0 - (distance / maxLen);
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String a, String b) {
    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[a.length][b.length];
  }

  /// Get field value from topic
  String _getFieldValue(CourseTopic topic, String field) {
    switch (field) {
      case 'title': return topic.title;
      case 'description': return topic.description;
      case 'category': return topic.categoryName;
      case 'subcategory': return topic.subcategoryName ?? '';
      case 'difficulty': return topic.difficulty;
      default: return '';
    }
  }

  /// Get context around a match
  String _getContext(String text, int position, int length) {
    if (length < 0) {
      final start = max(0, position + length);
      return text.substring(start, position);
    } else {
      final end = min(text.length, position + length);
      return text.substring(position, end);
    }
  }

  /// Generate content snippet with highlighted matches
  String _generateSnippet(String content, String query, int maxLength) {
    if (content.isEmpty) return '';
    
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    final index = lowerContent.indexOf(lowerQuery);
    if (index == -1) {
      return content.length > maxLength 
          ? '${content.substring(0, maxLength)}...'
          : content;
    }
    
    final start = max(0, index - (maxLength ~/ 3));
    final end = min(content.length, start + maxLength);
    
    String snippet = content.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';
    
    return snippet;
  }

  /// Remove duplicate results
  List<EnhancedSearchResult> _deduplicateResults(List<EnhancedSearchResult> results) {
    final seen = <String>{};
    return results.where((result) => seen.add(result.id)).toList();
  }

  /// Track search for analytics
  void _trackSearch(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    _searchStats[normalizedQuery] = (_searchStats[normalizedQuery] ?? 0) + 1;
    
    // Track popular searches by category
    final category = _detectSearchCategory(normalizedQuery);
    _popularSearches.putIfAbsent(category, () => []).add(normalizedQuery);
  }

  /// Detect search category for analytics
  String _detectSearchCategory(String query) {
    final cybersecurityTerms = ['security', 'cyber', 'hacking', 'malware', 'phishing', 'encryption'];
    final networkTerms = ['network', 'firewall', 'vpn', 'protocol', 'routing'];
    final programmingTerms = ['development', 'coding', 'programming', 'app', 'software'];
    
    if (cybersecurityTerms.any((term) => query.contains(term))) return 'cybersecurity';
    if (networkTerms.any((term) => query.contains(term))) return 'networking';
    if (programmingTerms.any((term) => query.contains(term))) return 'development';
    
    return 'general';
  }

  /// Get search analytics
  Map<String, dynamic> getSearchAnalytics() {
    return {
      'totalSearches': _searchStats.values.fold(0, (a, b) => a + b),
      'uniqueQueries': _searchStats.length,
      'popularQueries': _searchStats.entries
          .where((e) => e.value > 1)
          .map((e) => {'query': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int)),
      'categoricalSearches': _popularSearches.map((k, v) => MapEntry(k, v.length)),
      'indexSize': _searchIndex.length,
      'documentsIndexed': _topics.length + _topicDetails.length,
    };
  }

  /// Reset search service (for testing/development)
  void reset() {
    _topics.clear();
    _topicDetails.clear();
    _searchIndex.clear();
    _termFrequency.clear();
    _searchStats.clear();
    _popularSearches.clear();
    _isInitialized = false;
  }

  /// Check if service is ready
  bool get isReady => _isInitialized;
  
  /// Get indexed content count
  int get indexedContentCount => _topics.length + _topicDetails.length;
  
  /// Get search statistics
  Map<String, int> get searchStatistics => Map.from(_searchStats);
}