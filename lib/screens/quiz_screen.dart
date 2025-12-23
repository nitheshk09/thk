import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/translated_text.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.onNavigateHome});

  final VoidCallback? onNavigateHome;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion> _currentQuestions = [];
  int _currentQuestionIndex = 0;
  List<int> _userAnswers = [];
  bool _quizCompleted = false;
  int _score = 0;
  bool _showResult = false;

  final List<QuizQuestion> _allQuestions = [
    // Cybersecurity Basics
    QuizQuestion(
      question: "What is phishing?",
      options: ["A type of fishing", "A fraudulent attempt to obtain sensitive information", "A security software", "A firewall technique"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What does VPN stand for?",
      options: ["Virtual Private Network", "Very Protected Network", "Verified Privacy Network", "Visual Private Node"],
      correctAnswer: 0,
      topic: "Network Security",
    ),
    QuizQuestion(
      question: "What is malware?",
      options: ["Anti-virus software", "Malicious software designed to harm", "Email filter", "Data backup tool"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What is two-factor authentication (2FA)?",
      options: ["Using two passwords", "An extra layer of security requiring two verification methods", "Two antivirus programs", "Two firewalls"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What is a firewall?",
      options: ["A virus", "A security system that monitors network traffic", "An email client", "A web browser"],
      correctAnswer: 1,
      topic: "Network Security",
    ),
    QuizQuestion(
      question: "What is encryption?",
      options: ["Deleting data", "Converting data into code to prevent unauthorized access", "Backing up files", "Installing updates"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What is a strong password characteristic?",
      options: ["Using only lowercase letters", "Combining upper/lowercase letters, numbers, and symbols", "Using your name", "Using 'password123'"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What is ransomware?",
      options: ["Free software", "Malware that encrypts files and demands payment", "A security update", "A backup tool"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What should you do if you receive a suspicious email?",
      options: ["Click all links to investigate", "Do not click links or download attachments", "Forward to everyone", "Reply with personal information"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What is social engineering?",
      options: ["Building social networks", "Manipulating people to divulge confidential information", "A programming language", "A type of firewall"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What does HTTPS indicate?",
      options: ["High-speed connection", "Secure encrypted connection", "Hypertext protocol", "High transfer protocol"],
      correctAnswer: 1,
      topic: "Network Security",
    ),
    QuizQuestion(
      question: "What is a DDoS attack?",
      options: ["Data backup", "Distributed Denial of Service attack", "Digital download service", "Data encryption"],
      correctAnswer: 1,
      topic: "Network Security",
    ),
    QuizQuestion(
      question: "What is the purpose of antivirus software?",
      options: ["Speed up computer", "Detect and remove malicious software", "Create backups", "Manage passwords"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What is a zero-day vulnerability?",
      options: ["An old security flaw", "A security flaw unknown to software vendors", "A patched vulnerability", "A minor bug"],
      correctAnswer: 1,
      topic: "Cybersecurity Fundamentals",
    ),
    QuizQuestion(
      question: "What is the best practice for public Wi-Fi?",
      options: ["Always trust public networks", "Use VPN and avoid sensitive transactions", "Share passwords on public Wi-Fi", "Disable firewall"],
      correctAnswer: 1,
      topic: "Network Security",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startNewQuiz();
  }

  void _startNewQuiz() {
    setState(() {
      _currentQuestions = _getRandomQuestions();
      _currentQuestionIndex = 0;
      _userAnswers = List.filled(10, -1);
      _quizCompleted = false;
      _score = 0;
      _showResult = false;
    });
  }

  List<QuizQuestion> _getRandomQuestions() {
    final shuffled = List<QuizQuestion>.from(_allQuestions);
    shuffled.shuffle();
    return shuffled.take(10).toList();
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _completeQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _completeQuiz() {
    int correctAnswers = 0;
    for (int i = 0; i < _currentQuestions.length; i++) {
      if (_userAnswers[i] == _currentQuestions[i].correctAnswer) {
        correctAnswers++;
      }
    }
    
    setState(() {
      _score = correctAnswers;
      _quizCompleted = true;
      _showResult = true;
    });
  }

  bool get _isPassed => (_score / _currentQuestions.length) >= 0.8;

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const TranslatedText('Quiz Challenge', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2E7DFF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildQuestionCard(),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2E7DFF),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(
                'Question ${_currentQuestionIndex + 1} of ${_currentQuestions.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              TranslatedText(
                _currentQuestions[_currentQuestionIndex].topic,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _currentQuestions.length,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final question = _currentQuestions[_currentQuestionIndex];
    
    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TranslatedText(
              question.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            ...question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _userAnswers[_currentQuestionIndex] == index;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildOptionButton(option, index, isSelected),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7DFF) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF2E7DFF) : const Color(0xFFE5E7EB),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF2E7DFF).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : const Color(0xFFE5E7EB),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF2E7DFF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TranslatedText(
                option,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), // Extra bottom padding to avoid FAB
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousQuestion,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const TranslatedText('Previous'),
              ),
            ),
          if (_currentQuestionIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentQuestionIndex > 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _userAnswers[_currentQuestionIndex] != -1
                  ? (_currentQuestionIndex == _currentQuestions.length - 1 ? _completeQuiz : _nextQuestion)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: TranslatedText(
                _currentQuestionIndex == _currentQuestions.length - 1 ? 'Finish Quiz' : 'Next Question',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final percentage = (_score / _currentQuestions.length * 100).round();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(
                _isPassed ? Icons.celebration : Icons.refresh,
                size: 80,
                color: _isPassed ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 24),
              TranslatedText(
                _isPassed ? 'Congratulations!' : 'Keep Learning!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              TranslatedText(
                _isPassed 
                    ? 'You passed the quiz with flying colors!'
                    : 'You need 80% to pass. Don\'t give up!',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const TranslatedText('Score:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('$_score/${_currentQuestions.length}', style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const TranslatedText('Percentage:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('$percentage%', style: TextStyle(
                          fontSize: 18,
                          color: _isPassed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const TranslatedText('Result:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isPassed ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TranslatedText(
                            _isPassed ? 'PASSED' : 'FAILED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startNewQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7DFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const TranslatedText('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        if (widget.onNavigateHome != null) {
                          widget.onNavigateHome!();
                        } else {
                          // Fallback: just restart the quiz if no navigation callback
                          _startNewQuiz();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const TranslatedText('Back to Home'),
                    ),
                  ),
                  const SizedBox(height: 80), // Extra space to avoid FAB overlap
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String topic;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.topic,
  });
}