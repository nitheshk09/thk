import 'package:flutter/material.dart';

class Course {
  final int id;
  final String title;
  final String description;
  final String difficulty;
  final bool isFree;
  final double price;
  final int durationMinutes;
  final String thumbnailUrl;
  final String categoryName;
  final int enrollmentCount;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.isFree,
    required this.price,
    required this.durationMinutes,
    required this.thumbnailUrl,
    required this.categoryName,
    required this.enrollmentCount,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      difficulty: json['difficulty'],
      isFree: json['isFree'],
      price: (json['price'] ?? 0).toDouble(),
      durationMinutes: json['durationMinutes'] ?? 0,
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      categoryName: json['categoryName'] ?? '',
      enrollmentCount: json['enrollmentCount'] ?? 0,
    );
  }
}

class AllCoursesScreen extends StatefulWidget {
  const AllCoursesScreen({Key? key}) : super(key: key);

  @override
  State<AllCoursesScreen> createState() => _AllCoursesScreenState();
}

class _AllCoursesScreenState extends State<AllCoursesScreen> {
  bool isFreeSelected = true;
  List<Course> allCourses = [];
  List<Course> filteredCourses = [];

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  void loadCourses() {

    final jsonData = {
      "success": true,
      "data": [
        {
          "id": 65,
          "title": "Cybersecurity Essentials",
          "description": "Cybersecurity refers to the practices, technologies, and processes used to protect computers, networks, data, and systems",
          "difficulty": "beginner",
          "isFree": true,
          "price": 0,
          "durationMinutes": 180,
          "thumbnailUrl": "",
          "categoryName": "cybersecurity fundamentals",
          "enrollmentCount": 27
        },
        // Add more courses from your JSON
      ]
    };

    setState(() {
      allCourses = (jsonData['data'] as List)
          .map((courseJson) => Course.fromJson(courseJson))
          .toList();
      filterCourses();
    });
  }

  void filterCourses() {
    setState(() {
      if (isFreeSelected) {
        filteredCourses = allCourses.where((course) => course.isFree).toList();
      } else {
        filteredCourses = allCourses.where((course) => !course.isFree).toList();
      }
    });
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  List<Color> _getCardGradient(int index) {
    final gradients = [
      [Color(0xFFFFD4B2), Color(0xFFFFEBD7)],
      [Color(0xFFB8C5F2), Color(0xFFD4DCFA)],
      [Color(0xFFB8E6D5), Color(0xFFD4F4E7)],
      [Color(0xFFFFB8B8), Color(0xFFFFD7D7)],
      [Color(0xFFCBB8F2), Color(0xFFE5D4FA)],
      [Color(0xFFFFE4B8), Color(0xFFFFF0D4)],
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Course',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isFreeSelected = true;
                        filterCourses();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isFreeSelected
                            ? Color(0xFFFF6B6B)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Free',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isFreeSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isFreeSelected = false;
                        filterCourses();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !isFreeSelected
                            ? Color(0xFFFF6B6B)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Paid',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !isFreeSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Course Grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: filteredCourses.length,
              itemBuilder: (context, index) {
                final course = filteredCourses[index];
                return CourseCard(
                  course: course,
                  gradient: _getCardGradient(index),
                  difficultyColor: _getDifficultyColor(course.difficulty),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFFFF6B6B),
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  final Course course;
  final List<Color> gradient;
  final Color difficultyColor;

  const CourseCard({
    Key? key,
    required this.course,
    required this.gradient,
    required this.difficultyColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Favorite Icon
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 18,
                color: Color(0xFFFF6B6B),
              ),
            ),
          ),

          // Price Tag
          Positioned(
            bottom: 80,
            right: 12,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: course.isFree ? Colors.green : Color(0xFF5B4FE0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                course.isFree ? 'Free' : '\$${course.price.toInt()}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  course.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'By ${course.categoryName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF6B6B),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${course.enrollmentCount} Tutorial',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    SizedBox(width: 2),
                    Text(
                      '4.5',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}