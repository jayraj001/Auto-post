import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String _selected = 'pro';
  bool _annual = false;

  final _plans = [
    _Plan(
      id: 'free',
      name: 'Free',
      priceMonthly: 0,
      color: Colors.grey,
      features: const [
        '10 posts/month',
        '1 social account',
        '5 AI credits',
        'Basic analytics',
      ],
      missing: const ['Bulk upload', 'Automation', 'Priority support'],
    ),
    _Plan(
      id: 'basic',
      name: 'Basic',
      priceMonthly: 199,
      color: AppTheme.secondary,
      features: const [
        '50 posts/month',
        '3 social accounts',
        '50 AI credits',
        'Full analytics',
        'Bulk upload',
      ],
      missing: const ['Automation', 'Priority support'],
    ),
    _Plan(
      id: 'pro',
      name: 'Pro',
      priceMonthly: 499,
      color: AppTheme.primary,
      features: const [
        '200 posts/month',
        '7 social accounts',
        '200 AI credits',
        'Full analytics',
        'Bulk upload',
        'Automation engine',
        'AI image generation',
      ],
      missing: const [],
      isPopular: true,
    ),
    _Plan(
      id: 'premium',
      name: 'Premium',
      priceMonthly: 999,
      color: Color(0xFFFFD700),
      features: const [
        'Unlimited posts',
        '15 social accounts',
        'Unlimited AI credits',
        'Full analytics',
        'Bulk upload',
        'Automation engine',
        'AI image generation',
        'Priority support',
        'White-label',
      ],
      missing: const [],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _annual = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_annual
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Monthly',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_annual ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _annual = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _annual ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Annual',
                              style: TextStyle(
                                color: _annual ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Save 20%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._plans.map((plan) {
              final isSelected = _selected == plan.id;
              final price = _annual
                  ? (plan.priceMonthly * 0.8).round()
                  : plan.priceMonthly;

              return GestureDetector(
                onTap: () => setState(() => _selected = plan.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? plan.color.withValues(alpha: 0.08)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? plan.color
                          : Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: plan.color,
                            ),
                          ),
                          if (plan.isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: plan.color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (price == 0)
                            const Text(
                              'Free',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'INR $price',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '/mo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...plan.features.map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: plan.color,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                feature,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (plan.missing.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...plan.missing.map(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  feature,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected == 'free' ? null : _subscribe,
                child: Text(
                  _selected == 'free'
                      ? 'Current Plan'
                      : 'Subscribe to ${_plans.firstWhere((plan) => plan.id == _selected).name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cancel anytime. No hidden fees.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _subscribe() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _PaymentOption(
              label: 'Pay with Card (Stripe)',
              icon: Icons.credit_card,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _PaymentOption(
              label: 'Pay with Razorpay (UPI/Cards)',
              icon: Icons.payment,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _Plan {
  final String id;
  final String name;
  final int priceMonthly;
  final Color color;
  final List<String> features;
  final List<String> missing;
  final bool isPopular;

  const _Plan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.color,
    required this.features,
    required this.missing,
    this.isPopular = false,
  });
}
