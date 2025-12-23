import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

// Color palette
const _deepBlue = Color(0xFF008FE8);
const _primaryWhite = Color(0xFFFFFFFF);
const _textWhite = Color(0xFFFFFFFF);
const _textLight = Color(0xFFE8F5FF);

// Onboarding Screen
class OnboardingScreen extends StatefulWidget {
const OnboardingScreen({super.key});

@override
State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
late final PageController _pageController;
int _index = 0;

@override
void initState() {
super.initState();
_pageController = PageController(viewportFraction: 1.0);
}

final List<_OnboardingPage> _pages = const [
_OnboardingPage(
imagePath1: 'Asset/p1.png',
imagePath2: 'Asset/p2.png',
imagePath3: null,
layoutType: 1,
title: 'For teachers',
subtitle:
'Reimagine teaching with engaging stories that spark curiosity both in class and at home',
),
_OnboardingPage(
imagePath1: 'Asset/p1.png',
imagePath2: 'Asset/p2.png',
imagePath3: 'Asset/p3.png',
layoutType: 2,
title: 'For parents',
subtitle:
'Create a world of learning with stories rooted in educator expertise or your personal journey',
),
_OnboardingPage(
imagePath1: 'Asset/p3.png',
imagePath2: 'Asset/p2.png',
imagePath3: null,
layoutType: 3,
title: 'For kids',
subtitle:
'Turn screen time into progress with captivating stories that drive you forward',
),
];

Future<void> _finish() async {
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('onboarded', true);
if (!mounted) return;
Navigator.of(context).pushReplacement(
MaterialPageRoute(builder: (context) => const LoginScreen()),
);
}

void _next() {
if (_index == _pages.length - 1) {
_finish();
} else {
_pageController.animateToPage(
_index + 1,
duration: const Duration(milliseconds: 400),
curve: Curves.easeInOutCubic,
);
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: _deepBlue,
body: SafeArea(
child: Column(
children: [
Expanded(
child: Center(
child: PageView.builder(
controller: _pageController,
onPageChanged: (i) => setState(() => _index = i),
itemCount: _pages.length,
itemBuilder: (context, i) {
return _ContentCard(
page: _pages[i],
isActive: i == _index,
);
},
),
),
),
_PageIndicatorDots(pageCount: _pages.length, currentIndex: _index),
const SizedBox(height: 24),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
child: Column(
children: [
SizedBox(
width: double.infinity,
height: 56,
child: ElevatedButton(
onPressed: _finish,
style: ElevatedButton.styleFrom(
backgroundColor: _primaryWhite,
foregroundColor: _deepBlue,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
),
child: const Text(
'Sign in',
style: TextStyle(
fontWeight: FontWeight.w700, fontSize: 16),
),
),
),
const SizedBox(height: 16),
TextButton(
onPressed: _finish,
child: const Text(
'Continue with Signup',
style: TextStyle(
color: _textWhite,
fontSize: 15,
fontWeight: FontWeight.w600),
),
)
],
),
),
],
),
),
);
}
}

// Content Card (with two side-by-side illustrations)
class _ContentCard extends StatelessWidget {
const _ContentCard({required this.page, required this.isActive});

final _OnboardingPage page;
final bool isActive;

@override
Widget build(BuildContext context) {
final screenHeight = MediaQuery.of(context).size.height;

return Container(
  margin: const EdgeInsets.only(top: 10, bottom: 10),
  decoration: BoxDecoration(
    color: _deepBlue,
    borderRadius: BorderRadius.circular(40),
  ),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
        // Different layout based on page type
        Flexible(
          flex: 2,
          child: page.layoutType == 1
              ? _buildTwoImageLayout(page)
              : page.layoutType == 2
                  ? _buildThreeImageLayout(page)
                  : _buildKidsLayout(page),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _textWhite,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: _textLight,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
);
}

// Layout 1: Two images - large centered tilted + small right peek
Widget _buildTwoImageLayout(_OnboardingPage page) {
return Stack(
children: [
// First image - large, centered, and tilted
Center(
child: Transform.rotate(
angle: 0.08, // Slight tilt
child: _ovalImage(page.imagePath1, const Color(0xFFA9A9FD), 180, 400),
),
),
// Second image - small peek on right edge
Positioned(
right: -50,
top: 180,
child: _ovalImage(page.imagePath2, const Color(0xFFCA61), 130, 180),
),
],
);
}

// Layout 2: Three images - left peek + large center + right peek
Widget _buildThreeImageLayout(_OnboardingPage page) {
return Stack(
children: [
// Left image - small peek on left edge, vertically centered
Positioned(
left: -50,
top: 0,
bottom: 0,
child: Center(
child: _ovalImage(page.imagePath1!, const Color(0xFFA9A9FD), 110, 170),
),
),
// Center image - large, centered
Center(
child: _ovalImage(page.imagePath2!, const Color(0xFFCA61), 180, 320),
),
// Right image - small peek on right edge, vertically centered
Positioned(
right: -50,
top: 0,
bottom: 0,
child: Center(
child: _ovalImage(page.imagePath3!, const Color(0xFFFF7043), 110, 170),
),
),
],
);
}

// Layout 3: Kids - large centered + small left peek
Widget _buildKidsLayout(_OnboardingPage page) {
return Stack(
children: [
// Left image - small peek on left edge
Positioned(
left: -50,
top: 0,
bottom: 0,
child: Center(
child: _ovalImage(page.imagePath2, const Color(0xFFFFC107), 120, 180),
),
),
// Center image - large coral/orange
Center(
child: _ovalImage(page.imagePath1, const Color(0xFFFF7043), 180, 400),
),
],
);
}

// Helper: oval image with background
Widget _ovalImage(String path, Color bgColor, double width, double height) {
return ClipRRect(
borderRadius: BorderRadius.circular(width / 2),
child: Container(
width: width,
height: height,
decoration: BoxDecoration(
color: bgColor,
),
child: Image.asset(
path,
fit: BoxFit.cover,
width: width,
height: height,
),
),
);
}
}

// Page indicator dots
class _PageIndicatorDots extends StatelessWidget {
const _PageIndicatorDots({
required this.pageCount,
required this.currentIndex,
});

final int pageCount;
final int currentIndex;

@override
Widget build(BuildContext context) {
return Row(
mainAxisAlignment: MainAxisAlignment.center,
children: List.generate(pageCount, (i) {
final isActive = i == currentIndex;
return AnimatedContainer(
duration: const Duration(milliseconds: 300),
margin: const EdgeInsets.symmetric(horizontal: 4),
width: isActive ? 24 : 8,
height: 8,
decoration: BoxDecoration(
color: isActive ? _primaryWhite : _textWhite.withOpacity(0.3),
borderRadius: BorderRadius.circular(4),
),
);
}),
);
}
}

// Onboarding data model
class _OnboardingPage {
final String imagePath1;
final String imagePath2;
final String? imagePath3;
final int layoutType;
final String title;
final String subtitle;
const _OnboardingPage({
required this.imagePath1,
required this.imagePath2,
this.imagePath3,
required this.layoutType,
required this.title,
required this.subtitle,
});
}
