import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'premium_questionnaire_screen.dart'; // import your questionnaire screen

class PremiumProgramScreen extends StatelessWidget {
  const PremiumProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Premium")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            /// Hero Card
            AppCard(
              padding: const EdgeInsets.all(20),
              borderColor: c.premium.withValues(alpha: 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppPill('PREMIUM',
                          icon: Icons.workspace_premium, color: c.premium),
                      const Spacer(),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: c.premium.withValues(alpha: 0.6)),
                        ),
                        child: Icon(Icons.workspace_premium_outlined,
                            color: c.premium, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Your personalized program",
                      style: appDisplay(context, 34)),
                  const SizedBox(height: 8),
                  Text(
                    "Designed specifically for your goals, schedule, and experience.",
                    style: TextStyle(color: c.muted, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const AppSectionTitle("What you get"),
            const SizedBox(height: 12),

            /// Feature Cards
            _buildFeatureCard(
              context,
              icon: Icons.flag_outlined,
              title: "Tailored to your goal",
              description: "Fat loss, muscle gain, strength, rehab or general fitness",
            ),
            _buildFeatureCard(
              context,
              icon: Icons.schedule,
              title: "Matches your schedule",
              description: "2–6 days per week, home or gym",
            ),
            _buildFeatureCard(
              context,
              icon: Icons.person_outline,
              title: "Built around you",
              description: "Experience level, injuries, and equipment considered",
            ),
            _buildFeatureCard(
              context,
              icon: Icons.trending_up,
              title: "Progression included",
              description: "Weights & difficulty scale over time — no guesswork",
            ),

            const SizedBox(height: 12),

            /// Price / CTA Card — lime, like the home hero
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "ONE-TIME PAYMENT",
                    style: TextStyle(
                      color: c.onAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No subscriptions. Yours forever.",
                    style: appDisplay(context, 28, color: c.onAccent),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      // Navigate to questionnaire screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PremiumQuestionnaireScreen(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: c.onAccent,
                      foregroundColor: c.accent,
                    ),
                    child: const Text("Create my program"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () {
                // Navigate to example program screen
              },
              child: const Text("View example program"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon,
        required String title,
        required String description}) {
    final c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            AppIconBadge(icon, color: c.premium),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(color: c.muted, fontSize: 13),
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
