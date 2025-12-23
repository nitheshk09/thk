import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/razorpay_config.dart';
import '../services/api_client.dart';
import '../services/cart_service.dart';
import '../widgets/translated_text.dart';
import 'topic_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService.instance;
  final ThinkCyberApi _api = ThinkCyberApi();
  late Razorpay _razorpay;
  bool _isLoading = false;
  int? _userId;
  String? _userEmail;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
    _cartService.addListener(_onCartChanged);
    _initializeRazorpay();
    _loadUserInfo();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('thinkcyber_user');
    
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final json = jsonDecode(rawUser);
        if (json is Map<String, dynamic>) {
          final user = SignupUser.fromJson(json);
          setState(() {
            _userId = user.id;
            _userEmail = user.email;
          });
        }
      } catch (e) {
        debugPrint('Error loading user info: $e');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('✅ Payment Success: ${response.paymentId}');
    
    if (_currentOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Error: Order ID not found')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get list of paid courses from cart
      final paidCourses = _cartService.items.where((item) => !item.isFree && item.price > 0).toList();

      if (paidCourses.isEmpty) {
        throw Exception('No paid courses found in cart');
      }

      // Verify payment and enroll for each paid course
      int enrolledCount = 0;
      for (final item in paidCourses) {
        try {
          final verifyResponse = await _api.verifyPaymentAndEnroll(
            userId: _userId!,
            topicId: item.id,
            paymentId: response.paymentId!,
            orderId: _currentOrderId!,
            signature: response.signature!,
          );

          if (verifyResponse.success) {
            debugPrint('✅ Enrolled in paid course: ${item.title}');
            enrolledCount++;
          } else {
            debugPrint('❌ Failed to enroll in ${item.title}: ${verifyResponse.message}');
          }
        } catch (e) {
          debugPrint('❌ Error enrolling in course ${item.id}: $e');
        }
      }

      if (!mounted) return;
      
      if (enrolledCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Payment successful! Enrolled in $enrolledCount course(s).'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );

        // Clear cart and navigate back
        await _cartService.checkout();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatedText('Payment successful but enrollment failed.')),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrollment failed: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Payment Error: ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
    setState(() => _isLoading = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${response.walletName} wallet selected')),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCartItems() async {
    await _cartService.hydrate();
  }

  Future<void> _removeItem(int itemId) async {
    await _cartService.removeItem(itemId);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: TranslatedText('Item removed from cart'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _proceedToCheckout() async {
    if (_cartService.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Your cart is empty')),
      );
      return;
    }

    if (_userId == null || _userId! <= 0 || _userEmail == null || _userEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Please sign in to continue with checkout.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Separate free and paid courses
      final freeCourses = _cartService.items.where((item) => item.isFree || item.price == 0).toList();
      final paidCourses = _cartService.items.where((item) => !item.isFree && item.price > 0).toList();

      // Enroll in all free courses first
      for (final item in freeCourses) {
        try {
          await _api.enrollFreeCourse(
            userId: _userId!,
            topicId: item.id,
            email: _userEmail!,
          );
          debugPrint('✅ Enrolled in free course: ${item.title}');
        } catch (e) {
          debugPrint('❌ Failed to enroll in free course ${item.title}: $e');
        }
      }

      // If there are paid courses, process them
      if (paidCourses.isNotEmpty) {
        // For cart with multiple paid courses, create order for the first one with total amount
        // Backend will handle enrollment for all courses after payment
        final totalAmount = paidCourses.fold<double>(0, (sum, item) => sum + item.price);
        
        debugPrint('✅ Creating order for ${paidCourses.length} paid course(s), total: ₹$totalAmount');
        
        // Create order using the first course ID but with total amount
        final orderData = await _api.createOrderForCourse(
          userId: _userId!,
          topicId: paidCourses.first.id,
          email: _userEmail!,
        );

        final orderId = orderData['orderId'] as String?;
        final keyId = orderData['keyId'] as String?;

        if (orderId == null || keyId == null) {
          throw Exception('Invalid order response from backend');
        }

        debugPrint('✅ Order created: $orderId');

        // Open Razorpay payment dialog
        var options = {
          'key': keyId,
          'amount': (totalAmount * 100).toInt(), // Amount in paise
          'name': RazorpayConfig.merchantName,
          'description': 'ThinkCyber Course Bundle',
          'order_id': orderId,
          'prefill': {
            'contact': '',
            'email': _userEmail,
          },
          'external': {
            'wallets': RazorpayConfig.supportedWallets,
          }
        };

        _currentOrderId = orderId;

        try {
          _razorpay.open(options);
        } catch (e) {
          debugPrint('Error opening Razorpay: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
          setState(() => _isLoading = false);
        }
      } else {
        // Only free courses - enroll complete
        if (!mounted) return;

        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Successfully enrolled in all courses!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );

        // Clear cart and navigate back
        await _cartService.checkout();
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          'Cart',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _cartService.isEmpty
          ? const _EmptyCartWidget()
          : Column(
              children: [
                // Cart Items List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _cartService.items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _cartService.items[index];
                      return _CartItemCard(
                        item: item,
                        onRemove: () => _removeItem(item.id),
                        onTap: () {
                          // Navigate to course detail when tapped
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TopicDetailScreen(
                                topic: item.toCourseTopic(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                // Summary Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TranslatedText(
                        'Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TranslatedText(
                            'Courses (${_cartService.itemCount})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '(${_cartService.itemCount})',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const TranslatedText(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '₹${_cartService.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      const Divider(color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const TranslatedText(
                            'Total',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                          Text(
                            '₹${_cartService.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7DFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Checkout Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _proceedToCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7DFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const TranslatedText(
                                  'Checkout',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onRemove,
    required this.onTap,
  });

  final CartCourseItem item;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Thumbnail
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
            ),
            child: item.thumbnailUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 16),
          
          // Course Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                TranslatedText(
                  'by ${item.instructor}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Rating
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFFC107),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.rating}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '(${item.ratingCount} ratings)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          TranslatedText(
                            item.isFree ? 'Free' : '₹${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: item.isFree ? const Color(0xFF22C55E) : const Color(0xFF2D3142),
                            ),
                          ),
                          if (!item.isFree && item.isDiscounted && item.originalPrice > item.price) ...[
                            const SizedBox(width: 8),
                            Text(
                              '₹${item.originalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Remove Button
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4757),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _EmptyCartWidget extends StatelessWidget {
  const _EmptyCartWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7DFF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Color(0xFF2E7DFF),
              ),
            ),
            const SizedBox(height: 24),
            
            const TranslatedText(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            TranslatedText(
              'Looks like you haven\'t added any courses to your cart yet. Browse our courses and find something you like!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const TranslatedText(
                'Browse Courses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

