import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/razorpay_config.dart';
import '../services/api_client.dart';
import '../services/razorpay_http_service.dart';
import '../services/wishlist_store.dart';
import '../services/cart_service.dart';
import '../widgets/topic_visuals.dart';
import '../widgets/translated_text.dart';
import 'cart_screen.dart';

const _primaryRed = Color( 0xFF2E7DFF);
const _darkText = Color(0xFF2D3142);
const _lightText = Color(0xFF9094A6);
const _cardBg = Color(0xFFF8F9FA);

class _UploadedVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const _UploadedVideoPlayerScreen({required this.videoUrl, required this.title});

  @override
  State<_UploadedVideoPlayerScreen> createState() => _UploadedVideoPlayerScreenState();
}

class _UploadedVideoPlayerScreenState extends State<_UploadedVideoPlayerScreen> {
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    debugPrint('Video URL: ${widget.videoUrl}');
    
    // Create the HTML content for video player
    final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body {
          margin: 0;
          padding: 0;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          background-color: #000;
          font-family: Arial, sans-serif;
        }
        .video-container {
          width: 100%;
          height: 100%;
          display: flex;
          justify-content: center;
          align-items: center;
          background-color: #000;
        }
        video {
          width: 100%;
          height: 100%;
          object-fit: contain;
        }
        .error {
          color: #ff0000;
          text-align: center;
          padding: 20px;
        }
      </style>
    </head>
    <body>
      <div class="video-container">
        <video controls controlsList="nodownload" autoplay disablePictureInPicture>
          <source src="${widget.videoUrl}" type="video/mp4">
          Your browser does not support the video tag.
        </video>
      </div>
    </body>
    </html>
    ''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36')
      ..loadHtmlString(htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WebViewWidget(controller: _webViewController),
    );
  }
}

class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({super.key, required this.topic, this.fromEnrollments = false});

  final CourseTopic topic;
  final bool fromEnrollments;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen>
    with SingleTickerProviderStateMixin {
  final ThinkCyberApi _api = ThinkCyberApi();
  final WishlistStore _wishlist = WishlistStore.instance;
  late Razorpay _razorpay;
  TopicDetail? _detail;
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  int? _userId;
  String? _userEmail;
  String? _currentOrderId;
  bool _processingCheckout = false;
  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
    _hydrateWishlist();
  }

  Future<void> _initialize() async {
    final userId = await _loadUser();
    await _fetchDetail(userId: userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _api.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchDetail({int? userId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Removed static detail injection after testing
      final resolvedUserId = userId ?? _userId;
      final response = await _api.fetchTopicDetail(
        widget.topic.id,
        userId: resolvedUserId,
      );
      if (!mounted) return;
      setState(() {
        _detail = response.topic;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load course details right now.';
        _loading = false;
      });
    }
  }

  Future<int?> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    int? userId;
    String? email;

    final rawUser = prefs.getString('thinkcyber_user');
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final json = jsonDecode(rawUser);
        if (json is Map<String, dynamic>) {
          userId = json['id'] as int?;
          email = json['email'] as String?;
        }
      } catch (_) {
        // Ignore malformed cache and fall back to individual keys.
      }
    }

    userId ??= prefs.getInt('thinkcyber_user_id');
    email ??= prefs.getString('thinkcyber_email');

    if (!mounted) return userId;
    setState(() {
      _userId = userId;
      _userEmail = email;
    });
    return userId;
  }

  Future<void> _hydrateWishlist() async {
    await _wishlist.hydrate();
    if (!mounted) return;
    setState(() {
      _isWishlisted = _wishlist.contains(widget.topic.id);
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Handle Razorpay payment success - verify payment and enroll
    debugPrint('✅ Razorpay | Payment Success - PaymentId: ${response.paymentId}');
    
    final messenger = ScaffoldMessenger.of(context);
    final userId = _userId;
    final orderId = _currentOrderId;

    if (userId == null || orderId == null) {
      debugPrint('❌ Razorpay | Missing userId or orderId');
      messenger.showSnackBar(
        const SnackBar(content: TranslatedText('Payment successful!')),
      );
      return;
    }

    try {
      debugPrint('✅ Razorpay | Verifying payment and enrolling user...');
      debugPrint('✅ Razorpay | PaymentId: ${response.paymentId}, OrderId: $orderId');
      
      // Verify payment and auto-enroll
      final enrollResponse = await _api.verifyPaymentAndEnroll(
        userId: userId,
        topicId: widget.topic.id,
        paymentId: response.paymentId!,
        orderId: orderId,
        signature: response.signature!,
      );
      
      if (!mounted) return;

      if (enrollResponse.success) {
        debugPrint('✅ Razorpay | Payment verified and user enrolled successfully!');
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: TranslatedText('Payment successful! You are now enrolled.'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
          
          setState(() {
            // Mark user as enrolled since payment verification succeeded
            _detail = _detail?.copyWith(isEnrolled: true);
          });
        }
        // Don't refresh detail here - user might see buttons flash
        // The UI is already updated with isEnrolled: true
      } else {
        debugPrint('❌ Razorpay | Verification failed: ${enrollResponse.message}');
        messenger.showSnackBar(
          SnackBar(content: Text('Enrollment error: ${enrollResponse.message}')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Razorpay | Error verifying payment: $error');
      debugPrint('❌ Razorpay | Stack trace: $stackTrace');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingCheckout = false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Handle Razorpay payment failure
    final errorMessage = response.message ?? response.code ?? 'Payment cancelled';
    debugPrint('Razorpay | Payment Error - Code: ${response.code}, Message: ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: $errorMessage')),
    );
    setState(() => _processingCheckout = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle Razorpay external wallet
    final walletName = response.walletName ?? 'Wallet';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: $walletName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.topic;
    final detail = _detail;
    final bool summaryEnrolled = summary.isEnrolled;
    final bool detailEnrolled = detail?.isEnrolled ?? false;
    final bool isEnrolled = widget.fromEnrollments || detailEnrolled || summaryEnrolled;
    final bool isFreeCourse = detail?.isFree ?? summary.isFree || summary.price == 0;
    final num priceValue = detail?.price ?? summary.price;
    final String formattedPrice;
    if (priceValue % 1 == 0) {
      formattedPrice = '₹${priceValue.toInt()}';
    } else {
      formattedPrice = '₹${priceValue.toStringAsFixed(2)}';
    }
    final String priceDisplay = isFreeCourse ? 'Free' : formattedPrice;
    final String badgeLabel = isEnrolled ? 'Enrolled' : priceDisplay;
    final heroTag = topicHeroTag(summary.id);
    final heroTitle = (((detail?.title) ?? '').isNotEmpty)
        ? detail!.title
        : summary.title;
    final heroThumbnail = (((detail?.thumbnailUrl) ?? '').isNotEmpty)
        ? detail!.thumbnailUrl
        : summary.thumbnailUrl;
    final Color badgeColor = isEnrolled
        ? const Color(0xFF22C55E)
        : (isFreeCourse ? _primaryRed : const Color(0xFF4A5568));

    final heroHeader = TopicHeroHeader(
      heroTag: heroTag,
      title: heroTitle,
      thumbnailUrl: heroThumbnail,
      badgeLabel: badgeLabel,
      badgeColor: badgeColor,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          'Details',
          style: TextStyle(
            color: _darkText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (detail != null)
            IconButton(
              icon: Icon(
                _isWishlisted ? Icons.favorite : Icons.favorite_border,
                color: _isWishlisted ? _primaryRed : _darkText,
              ),
              onPressed: () => _toggleWishlistAction(detail),
              tooltip: _isWishlisted
                  ? 'Remove from wishlist'
                  : 'Add to wishlist',
            ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: EdgeInsets.zero,
              children: [
                heroHeader,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(color: _primaryRed),
                  ),
                ),
              ],
            )
          : _error != null
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    heroHeader,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: _DetailError(
                        message: _error!,
                        onRetry: () {
                          _fetchDetail(userId: _userId);
                        },
                      ),
                    ),
                  ],
                )
              : detail == null
                  ? ListView(
                      padding: EdgeInsets.zero,
                      children: [heroHeader],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heroHeader,
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TranslatedText(
                                  detail.title,
                                  style: const TextStyle(
                                    color: _darkText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const TranslatedText(
                                      'By',
                                      style: TextStyle(
                                        color: _lightText,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    TranslatedText(
                                      detail.categoryName,
                                      style: const TextStyle(
                                        color: _darkText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFFFFC107),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '(4.9)',
                                      style: TextStyle(
                                        color: _darkText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFFFFC107),
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: _lightText,
                                    ),
                                    const SizedBox(width: 6),
                                    TranslatedText(
                                      detail.durationMinutes > 0
                                          ? '${(detail.durationMinutes / 60).toStringAsFixed(1)}h ${detail.durationMinutes % 60}m'
                                          : 'Self-paced',
                                      style: const TextStyle(
                                        color: _lightText,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(
                                      Icons.play_circle_outline,
                                      size: 16,
                                      color: _lightText,
                                    ),
                                    const SizedBox(width: 6),
                                    TranslatedText(
                                      '${_getTotalVideos(detail.modules)} Tutorials',
                                      style: const TextStyle(
                                        color: _lightText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _TabSection(
                                  tabController: _tabController,
                                  detail: detail,
                                  hasCourseAccess: isEnrolled || isFreeCourse,
                                  isEnrolled: isEnrolled,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: !_loading && _error == null && detail != null && !isEnrolled && !widget.fromEnrollments
          ? _BottomBar(
              priceLabel: priceDisplay,
              isFree: isFreeCourse,
              isProcessing: _processingCheckout,
              onBuyNow: () => _handlePurchase(detail, isFreeCourse),
              onAddToCart: _handleAddToCart,
            )
          : null,
    );
  }

  int _getTotalVideos(List<TopicModule> modules) {
    return modules.fold(0, (sum, module) => sum + module.videos.length);
  }

  Future<void> _handlePurchase(TopicDetail detail, bool isFree) async {
    if (_processingCheckout) return;

    final messenger = ScaffoldMessenger.of(context);
    final userId = _userId;
    final email = _userEmail;

    if (userId == null || userId <= 0 || email == null || email.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: TranslatedText('Please sign in to continue with checkout.'),
        ),
      );
      return;
    }

    final isFreeCourse = isFree || detail.isFree || detail.price == 0;

    if (isFreeCourse) {
      setState(() => _processingCheckout = true);
      try {
        final response = await _api.enrollFreeCourse(
          userId: userId,
          topicId: detail.id,
          email: email,
        );

        if (response.success) {
          debugPrint('✅ FreeEnroll | Enrollment successful!');
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: TranslatedText('You are now enrolled!'),
                backgroundColor: Color(0xFF22C55E),
              ),
            );
            
            setState(() {
              // Mark user as enrolled since enrollment succeeded
              _detail = _detail?.copyWith(isEnrolled: true);
            });
          }
          // Don't refresh detail here - user might see buttons flash
          // The UI is already updated with isEnrolled: true
        } else {
          final message = response.message.isNotEmpty
              ? response.message
              : 'Unable to enroll in this course.';
          
          debugPrint('❌ FreeEnroll | Enrollment failed: $message');
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      } on ApiException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error, stackTrace) {
        debugPrint('FreeEnroll | Unexpected error $error\n$stackTrace');
        messenger.showSnackBar(
          const SnackBar(
            content: TranslatedText('Unable to enroll right now. Please try again.'),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _processingCheckout = false);
        }
      }
      return;
    }

    setState(() => _processingCheckout = true);
    try {
      // Step 1: Create order via backend
      debugPrint('✅ Razorpay | Creating order via backend...');
      
      final orderData = await _api.createOrderForCourse(
        userId: userId,
        topicId: detail.id,
        email: email,
      );

      final orderId = orderData['orderId'] as String?;
      final keyId = orderData['keyId'] as String?;
      
      if (orderId == null || keyId == null) {
        throw Exception('Invalid order response from backend');
      }
      
      debugPrint('✅ Razorpay | Order created: $orderId');

      // Step 2: Open Razorpay dialog with the order
      var options = {
        'key': keyId,
        'amount': (detail.price * 100).toInt(), // Amount in paise
        'name': RazorpayConfig.merchantName,
        'description': detail.title,
        'order_id': orderId,
        'prefill': {
          'contact': '',
          'email': email,
        },
        'external': {
          'wallets': RazorpayConfig.supportedWallets,
        }
      };

      // Store orderId for payment verification
      _currentOrderId = orderId;

      try {
        _razorpay.open(options);
      } catch (e) {
        debugPrint('Razorpay | Error opening dialog: $e');
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _processingCheckout = false);
      }
    } catch (error, stackTrace) {
      debugPrint('Razorpay | Unexpected error creating order: $error\n$stackTrace');
      messenger.showSnackBar(
        const SnackBar(
          content: TranslatedText('Unable to start checkout. Please try again.'),
        ),
      );
      if (mounted) {
        setState(() => _processingCheckout = false);
      }
    }
  }

  Future<void> _toggleWishlistAction(TopicDetail detail) async {
    final added = await _wishlist.toggleCourse(
      summary: widget.topic,
      detail: detail,
    );
    if (!mounted) return;
    setState(() => _isWishlisted = added);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TranslatedText(added ? 'Added to wishlist' : 'Removed from wishlist'),
      ),
    );
  }

  Future<void> _handleAddToCart() async {
    final cartService = CartService.instance;
    final detail = _detail;
    final topic = widget.topic;
    
    // Check if already in cart
    if (cartService.contains(topic.id)) {
      // If already in cart, navigate to cart screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CartScreen(),
        ),
      );
      return;
    }
    
    // Add to cart
    final added = await cartService.addItem(
      topic: topic,
      detail: detail,
    );
    
    if (!mounted) return;
    
    if (added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const TranslatedText('Added to cart successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'View Cart',  // Note: SnackBarAction doesn't support TranslatedText
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                ),
              );
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('This course is already in your cart'),
          backgroundColor: Color(0xFFFF9500),
        ),
      );
    }
  }
}

class TopicHeroHeader extends StatelessWidget {
  const TopicHeroHeader({
    super.key,
    required this.heroTag,
    required this.title,
    required this.thumbnailUrl,
    required this.badgeLabel,
    this.badgeColor,
  });

  final String heroTag;
  final String title;
  final String thumbnailUrl;
  final String badgeLabel;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    Widget buildImage() {
      return TopicImage(
        imageUrl: thumbnailUrl,
        title: title,
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: buildImage(),
              ),
            ),
          ),
          Positioned(top: 16, right: 16, child: _HeartBadge()),
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFF4A5568),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TranslatedText(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFFFA07A), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.favorite, color: Colors.white, size: 18),
    );
  }
}

class _TabSection extends StatelessWidget {
  const _TabSection({
    required this.tabController,
    required this.detail,
    required this.hasCourseAccess,
    required this.isEnrolled,
  });

  final TabController tabController;
  final TopicDetail detail;
  final bool hasCourseAccess;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(25),
          ),
          child: TabBar(
            controller: tabController,
            indicator: BoxDecoration(
              color: _primaryRed,
              borderRadius: BorderRadius.circular(25),
            ),
            labelColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.tab, // 🔥 makes indicator match tab width

            unselectedLabelColor: _lightText,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TranslatedText('Playlist'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${detail.modules.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Tab(child: TranslatedText('Descriptions')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65, // Use 65% of screen height for more space
          child: TabBarView(
            controller: tabController,
            children: [
              _PlaylistTab(
                modules: detail.modules,
                hasCourseAccess: hasCourseAccess,
                isEnrolled: isEnrolled,
              ),
              _DescriptionTab(detail: detail),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaylistTab extends StatelessWidget {
  const _PlaylistTab({
    required this.modules,
    required this.hasCourseAccess,
    required this.isEnrolled,
  });

  final List<TopicModule> modules;
  final bool hasCourseAccess;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const Center(
        child: TranslatedText(
          'No modules available yet',
          style: TextStyle(color: _lightText, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120), // Increased bottom padding for footer space
      itemCount: modules.length + 1, // Add one more item for footer
      itemBuilder: (context, index) {
        // Show footer at the end
        if (index == modules.length) {
          return _ModulesFooter(totalModules: modules.length);
        }
        
        final module = modules[index];
        final moduleAccess = hasCourseAccess || module.isEnrolled;
        return _ModuleItem(
          index: index + 1,
          module: module,
          hasAccess: moduleAccess,
          showDescriptions: isEnrolled,
        );
      },
    );
  }
}

class _ModuleItem extends StatefulWidget {
  const _ModuleItem({
    required this.index,
    required this.module,
    required this.hasAccess,
    required this.showDescriptions,
  });

  final int index;
  final TopicModule module;
  final bool hasAccess;
  final bool showDescriptions;

  @override
  State<_ModuleItem> createState() => _ModuleItemState();
}

class _ModuleItemState extends State<_ModuleItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final totalDuration = _calculateDuration();
    final hasVideos = module.videos.isNotEmpty;
    final hasDescription = module.description.isNotEmpty;
    final bool isUnlocked = widget.hasAccess;
    final bool shouldShowDescription = widget.showDescriptions && hasDescription;
    final bool canExpand = isUnlocked && (hasVideos || shouldShowDescription);

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Increased spacing between modules
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: canExpand
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index}',
                        style: const TextStyle(
                          color: _darkText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          module.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TranslatedText(
                          hasVideos 
                              ? totalDuration 
                              : shouldShowDescription
                                  ? 'Module content available'
                                  : 'Coming soon',
                          style: const TextStyle(
                            color: _lightText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (canExpand)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: _darkText,
                      size: 24,
                    )
                  else if (!isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TranslatedText(
                        'Locked',
                        style: TextStyle(
                          color: _primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _lightText.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.lock_clock,
                        color: _lightText,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_expanded && canExpand)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), // More padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show module description if available and user is enrolled
                  if (shouldShowDescription) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: EdgeInsets.only(bottom: hasVideos ? 12 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _lightText.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: _primaryRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const TranslatedText(
                                'Module Description',
                                style: TextStyle(
                                  color: _darkText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TranslatedText(
                            module.description,
                            style: const TextStyle(
                              color: _lightText,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Show videos if available
                  ...module.videos.map((video) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8), // Space between videos
                      child: _VideoListItem(
                        video: video,
                        isUnlocked: isUnlocked,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _calculateDuration() {
    if (widget.module.durationMinutes > 0) {
      final minutes = widget.module.durationMinutes;
      final hours = minutes ~/ 60;
      final remaining = minutes % 60;
      if (hours > 0) {
        return '${hours}h ${remaining}m';
      }
      return '${minutes}m';
    }

    if (widget.module.videos.isEmpty) return 'Coming soon';
    final count = widget.module.videos.length;
    return '$count video${count == 1 ? '' : 's'}';
  }
}

class _VideoListItem extends StatelessWidget {
  const _VideoListItem({required this.video, required this.isUnlocked});

  final TopicVideo video;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14), // Slightly more padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _lightText.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? _primaryRed.withValues(alpha: 0.1)
                    : _lightText.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isUnlocked ? Icons.play_arrow : Icons.lock_outline,
                color: isUnlocked ? _primaryRed : _lightText,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TranslatedText(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isUnlocked ? Icons.chevron_right : Icons.lock_outline,
              color: _lightText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (!isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Purchase the course to access this lesson.'),
        ),
      );
      return;
    }

    _playVideo(context, video);
  }

  void _playVideo(BuildContext context, TopicVideo video) {
    // Extract YouTube video ID from URL
    String? videoId = _extractYouTubeId(video.videoUrl);

    if (videoId != null) {
      // It's a YouTube video
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              _VideoPlayerScreen(videoId: videoId, title: video.title),
        ),
      );
    } else if (video.videoUrl.isNotEmpty) {
      // It's an uploaded video (direct URL)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              _UploadedVideoPlayerScreen(videoUrl: video.videoUrl, title: video.title),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Unable to play this video')),
      );
    }
  }

  String? _extractYouTubeId(String url) {
    if (url.isEmpty) return null;
    
    // Handle youtu.be format
    if (url.contains('youtu.be/')) {
      return url.split('youtu.be/').last.split('?').first.split('#').first;
    }
    // Handle youtube.com/watch?v= format
    if (url.contains('youtube.com/watch?v=')) {
      return url.split('v=').last.split('&').first;
    }
    // Handle youtube.com/embed/ format
    if (url.contains('youtube.com/embed/')) {
      return url.split('embed/').last.split('?').first.split('#').first;
    }
    // Handle bare video ID (11 characters, alphanumeric + _ and -)
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url.trim())) {
      return url.trim();
    }
    // If it looks like a YouTube URL but we haven't matched it yet, try to extract from the last part
    if (url.contains('youtube')) {
      final parts = url.split('/');
      for (int i = parts.length - 1; i >= 0; i--) {
        final part = parts[i].split('?').first.split('#').first;
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(part)) {
          return part;
        }
      }
    }
    return null;
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({required this.videoId, required this.title});

  final String videoId;
  final String title;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with your video ID
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        mute: false,
        autoPlay: true, // Set to false if you want manual start
        disableDragSeek: false,
        loop: false,
        isLive: false,
        enableCaption: true, // Shows subtitles if available
        // showVideoProgressIndicator: true,
      ),
    );

    // Listen for player readiness
    _controller.addListener(() {
      // Keep local state in sync with the controller. This ensures the
      // UI (volume icon) correctly reflects the actual player state.
      if (mounted) {
        setState(() {
          _isPlayerReady = _controller.value.isReady;
          // Note: YoutubePlayerValue doesn't have isMuted property
          // We track mute state manually in _isMuted variable
        });
      }
    });

    // Enable full-screen orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    // Reset orientation to portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // YouTube Player (takes most of the screen)
          Expanded(
            child: YoutubePlayerBuilder(
              onExitFullScreen: () {
                // Optional: Handle exit full-screen
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
              },
              player: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  // handleAndBufferedColor: Colors.white24,
                ),
                topActions: [
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: _isMuted ? Colors.grey[400] : Colors.white,
                      size: 25.0,
                    ),
                    onPressed: () {
                      // Toggle our local flag first for immediate UI feedback,
                      // then call controller methods. Use setVolume as a
                      // fallback on platforms where mute() may not work.
                      final willMute = !_isMuted;
                      setState(() => _isMuted = willMute);
                      if (willMute) {
                        try {
                          _controller.mute();
                          // Ensure volume is 0 as robust fallback
                          _controller.setVolume(0);
                        } catch (_) {
                          // ignore failures from controller methods
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: TranslatedText('Video muted'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      } else {
                        try {
                          _controller.unMute();
                          // Restore volume to a reasonable level
                          _controller.setVolume(100);
                        } catch (_) {}
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: TranslatedText('Video unmuted'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 25.0,
                    ),
                    onPressed: () {
                      // Optional: Open settings
                    },
                  ),
                ],
                onReady: () {
                  _hideVideoProgressIndicator();
                },
                onEnded: (metaData) {
                  _controller.load(widget.videoId); // Restart video on end
                },
              ),
              builder: (context, player) {
                return player; // This builds the player widget
              },
            ),
          ),
          // Optional: Add controls or description below the player
          if (!_isPlayerReady)
            const LinearProgressIndicator(
              backgroundColor: Colors.black,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TranslatedText(
              'Video ID: ${widget.videoId}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _hideVideoProgressIndicator() {
    // Optional: Hide progress after a delay
  }
}

class _DescriptionTab extends StatelessWidget {
  const _DescriptionTab({required this.detail});

  final TopicDetail detail;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.description.isNotEmpty) ...[
            const TranslatedText(
              'About Course',
              style: TextStyle(
                color: _darkText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TranslatedText(
              detail.description,
              style: const TextStyle(
                color: _lightText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (detail.learningObjectives.trim().isNotEmpty) ...[
            const TranslatedText(
              'What You\'ll Learn',
              style: TextStyle(
                color: _darkText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TranslatedText(
              _cleanText(detail.learningObjectives),
              style: const TextStyle(
                color: _lightText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (detail.targetAudience.isNotEmpty) ...[
            const TranslatedText(
              'Target Audience',
              style: TextStyle(
                color: _darkText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detail.targetAudience
                  .map((audience) => _AudienceChip(text: audience))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (detail.prerequisites.trim().isNotEmpty) ...[
            const TranslatedText(
              'Prerequisites',
              style: TextStyle(
                color: _darkText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TranslatedText(
              detail.prerequisites,
              style: const TextStyle(
                color: _lightText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 32),
          _DescriptionFooter(),
          const SizedBox(height: 300), // Extra bottom padding to ensure all content is visible
        ],
      ),
    );
  }

  String _cleanText(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('_', '')
        .replaceAll('|', ' ')
        .trim();
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lightText.withValues(alpha: 0.2)),
      ),
      child: TranslatedText(
        text,
        style: const TextStyle(
          color: _darkText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.priceLabel,
    required this.isFree,
    required this.isProcessing,
    required this.onBuyNow,
    required this.onAddToCart,
  });

  final String priceLabel;
  final bool isFree;
  final bool isProcessing;
  final VoidCallback onBuyNow;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final label = isFree ? 'Enroll for Free' : 'Buy Now';  // Will be translated below
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: onAddToCart,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: _primaryRed, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: _primaryRed,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: isProcessing ? null : onBuyNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : TranslatedText(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (!isFree) ...[
              const SizedBox(width: 16),
              Text(
                priceLabel,
                style: const TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: _lightText),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _darkText, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const TranslatedText('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionFooter extends StatelessWidget {
  const _DescriptionFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightText.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: _primaryRed,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          const TranslatedText(
            'Ready to Start Learning?',
            style: TextStyle(
              color: _darkText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TranslatedText(
            'This course is designed to help you master the fundamentals and advance your skills.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _lightText.withOpacity(0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primaryRed.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow,
                  color: _primaryRed,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const TranslatedText(
                  'Start Learning',
                  style: TextStyle(
                    color: _primaryRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _ModulesFooter extends StatelessWidget {
  const _ModulesFooter({required this.totalModules});

  final int totalModules;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 40),
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightText.withOpacity(0.1)),
      ),
      child: Column( 
        children: [
          TranslatedText(
            'You have reached the end of the playlist. You have access to $totalModules module${totalModules == 1 ? '' : 's'}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _lightText.withOpacity(0.8),
              fontSize: 13,
              height: 1.4, 
            ),
          ),
        ],
      ),
    );
  }
}
