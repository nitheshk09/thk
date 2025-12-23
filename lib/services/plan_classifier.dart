import '../services/api_client.dart';

enum PlanType {
  free,
  bundleOnly,
  flexible,
  individualOnly,
}

class PlanClassifier {
  static PlanType classifyPlan(FeaturePlan plan) {
    final features = plan.features.toLowerCase();

    // Free Plan: "No payment required"
    if (features.contains('no payment required')) {
      return PlanType.free;
    }

    // Bundle-Only Plan: "Discounted bundle price"
    if (features.contains('discounted bundle price')) {
      return PlanType.bundleOnly;
    }

    // Flexible Plan: Both "Individual topic purchase" AND "Category bundle purchase"
    if (features.contains('individual topic purchase') &&
        features.contains('category bundle purchase')) {
      return PlanType.flexible;
    }

    // Individual-Only Plan: "Single topic purchase" AND "No bundle discounts"
    if (features.contains('single topic purchase') &&
        features.contains('no bundle discounts')) {
      return PlanType.individualOnly;
    }

    // Default fallback
    return PlanType.flexible;
  }

  static String getPlanTypeLabel(PlanType type) {
    switch (type) {
      case PlanType.free:
        return 'Free';
      case PlanType.bundleOnly:
        return 'Bundle';
      case PlanType.flexible:
        return 'Flexible';
      case PlanType.individualOnly:
        return 'Individual';
    }
  }

  static bool canBuyIndividual(PlanType type) {
    return type == PlanType.flexible || type == PlanType.individualOnly;
  }

  static bool canBuyBundle(PlanType type) {
    return type == PlanType.flexible || type == PlanType.bundleOnly;
  }

  static bool canAccessFree(PlanType type) {
    return type == PlanType.free;
  }

  static bool includesFutureTopics(PlanType type) {
    // Current API plans don't have subscription-based, so all return false
    return false;
  }

  static String getMainCTA(PlanType type) {
    switch (type) {
      case PlanType.free:
        return 'Start Free';
      case PlanType.bundleOnly:
        return 'Buy Bundle';
      case PlanType.flexible:
        return 'Select Plan';
      case PlanType.individualOnly:
        return 'Buy Topic';
    }
  }

  static String getPlanDescription(PlanType type) {
    switch (type) {
      case PlanType.free:
        return 'Start learning with free content';
      case PlanType.bundleOnly:
        return 'Purchase bundled topics at a discount';
      case PlanType.flexible:
        return 'Buy topics individually or save with bundles';
      case PlanType.individualOnly:
        return 'Purchase topics one by one';
    }
  }

  static List<String> getPlanFeatures(FeaturePlan plan) {
    return plan.features
        .split('\n')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();
  }

  static bool hasFeature(FeaturePlan plan, String featureName) {
    return plan.features.toLowerCase().contains(featureName.toLowerCase());
  }
}
