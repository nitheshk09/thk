import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/plan_classifier.dart';
import '../widgets/translated_text.dart';

class PlanDisplayWidget extends StatelessWidget {
  final FeaturePlan? selectedPlan;
  final VoidCallback? onChangePlan;

  const PlanDisplayWidget({
    this.selectedPlan,
    this.onChangePlan,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedPlan == null) {
      return GestureDetector(
        onTap: onChangePlan,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  TranslatedText(
                    'Choose Your Plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  TranslatedText(
                    'Select a plan to get started',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7DFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF2E7DFF),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final planType = PlanClassifier.classifyPlan(selectedPlan!);
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
    final badge = PlanClassifier.getPlanTypeLabel(planType);

    return GestureDetector(
      onTap: onChangePlan,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: cardColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getPlanIcon(planType),
                color: cardColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TranslatedText(
                        selectedPlan!.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cardColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TranslatedText(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cardColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TranslatedText(
                    selectedPlan!.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_rounded,
                color: cardColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlanIcon(PlanType type) {
    switch (type) {
      case PlanType.free:
        return Icons.card_giftcard_rounded;
      case PlanType.bundleOnly:
        return Icons.inventory_2_rounded;
      case PlanType.flexible:
        return Icons.tune_rounded;
      case PlanType.individualOnly:
        return Icons.shopping_cart_rounded;
    }
  }
}
