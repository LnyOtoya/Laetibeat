import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../shared/layout/app_bottom_inset.dart';
import '../../../widgets/daily_section.dart';
import '../../../widgets/history_section.dart';
import '../../../widgets/recent_section.dart';
import '../../../widgets/welcome_section.dart';

/// 首页内容本身与布局形态无关：桌面端放进右栏布局，移动端直接作为 Tab。
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              const WelcomeSection(),
              SizedBox(height: theme.spacing.md),
              const RecentSection(),
              SizedBox(height: theme.spacing.md),
              const DailySection(),
              SizedBox(height: theme.spacing.md),
              const HistorySection(),
            ],
          ),
        ),
      ),
    );
  }
}
