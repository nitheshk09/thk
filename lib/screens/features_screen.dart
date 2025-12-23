import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/plan_classifier.dart';
import '../widgets/translated_text.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  final ThinkCyberApi _api = ThinkCyberApi();
  List<FeaturePlan> _plans = [];
  bool _loading = true;
  String? _error;
  int? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.fetchFeaturePlans();
      if (!mounted) return;

      setState(() {
        _plans = response.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load plans. Please try again.';
        _loading = false;
      });
      debugPrint('Error loading plans: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const TranslatedText(
          'Learning Plans',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6366F1),
              Color(0xFFF5F7FA),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPlans,
                          child: const TranslatedText('Retry'),
                        ),
                      ],
                    ),
                  )
                : _plans.isEmpty
                    ? const Center(
                        child: TranslatedText('No plans available'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPlans,
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                                child: Column(
                                  children: [
                                    const TranslatedText(
                                      'Choose Your Learning Path',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    const TranslatedText(
                                      'Select the perfect plan for your learning journey',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFFE0E7FF),
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final plan = _plans[index];
                                    final planType = PlanClassifier.classifyPlan(plan);
                                    final isSelected = _selectedPlanId == plan.id;
                                    return _buildPlanCard(plan, planType, isSelected);
                                  },
                                  childCount: _plans.length,
                                ),
                              ),
                            ),
                            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildPlanCard(FeaturePlan plan, PlanType planType, bool isSelected) {
    final colors = {
      PlanType.free: const Color(0xFF10B981),
      PlanType.bundleOnly: const Color(0xFF0EA5E9),
      PlanType.flexible: const Color(0xFF4F46E5),
      PlanType.individualOnly: const Color(0xFFF59E0B),
    };

    final bgColors = {
      PlanType.free: const Color(0xFFECFDF5),
      PlanType.bundleOnly: const Color(0xFFE0F2FE),
      PlanType.flexible: const Color(0xFFEEF2FF),
      PlanType.individualOnly: const Color(0xFFFEF3C7),
    };

    final cardColor = colors[planType]!;
    final bgColor = bgColors[planType]!;
    final features = PlanClassifier.getPlanFeatures(plan);
    final badge = PlanClassifier.getPlanTypeLabel(planType);
    final hasFutureTopics = PlanClassifier.includesFutureTopics(planType);
    final canBuyIndividual = PlanClassifier.canBuyIndividual(planType);
    final canBuyBundle = PlanClassifier.canBuyBundle(planType);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isSelected ? cardColor : Colors.black).withOpacity(isSelected ? 0.2 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isSelected ? cardColor : const Color(0xFFE5E7EB),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TranslatedText(
                    badge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cardColor,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Plan name and description
            TranslatedText(
              plan.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cardColor,
              ),
            ),
            const SizedBox(height: 8),
            TranslatedText(
              plan.description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Features list
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                              Icons.check,
                                color: cardColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TranslatedText(
                                feature,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF475569),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaButton({
    required String label,
    required bool enabled,
    required Color color,
    VoidCallback? onTap,
    String variant = 'filled',
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(colors: [color, color.withOpacity(0.8)])
              : null,
          color: enabled ? null : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
          border: variant == 'outline'
              ? Border.all(
                  color: enabled ? color : const Color(0xFFD1D5DB),
                  width: 2,
                )
              : null,
          boxShadow: enabled && variant == 'filled'
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: TranslatedText(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? (variant == 'outline' ? color : Colors.white)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }

  void _selectPlan(FeaturePlan plan, String type) {
    setState(() {
      _selectedPlanId = plan.id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${plan.name} selected ($type)'),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
