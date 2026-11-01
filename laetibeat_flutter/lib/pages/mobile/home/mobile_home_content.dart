import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../shared/layout/app_bottom_inset.dart';
import 'widgets/mobile_daily_section.dart';
import 'widgets/mobile_history_section.dart';
import 'widgets/mobile_welcome_section.dart';

/// 移动端首页内容。
class MobileHomeContent extends StatelessWidget {
  const MobileHomeContent({super.key});

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
              const MobileWelcomeSection(),
              SizedBox(height: theme.spacing.md),
              const MobileDailySection(),
              SizedBox(height: theme.spacing.md),
              const MobileHistorySection(),
            ],
          ),
        ),
      ),
    );
  }
}
