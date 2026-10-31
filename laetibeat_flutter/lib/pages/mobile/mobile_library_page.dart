import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../widgets/library_browser.dart';
import 'mobile_sub_page.dart';

class MobileLibraryPage extends StatelessWidget {
  const MobileLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LibraryBrowser(
      onSelect: (headline, supporting) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MobileSubPage(
              title: headline,
              child: _MobileLibraryDetail(
                title: headline,
                subtitle: supporting,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileLibraryDetail extends StatelessWidget {
  const _MobileLibraryDetail({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.all(theme.spacing.md),
      padding: EdgeInsets.all(theme.spacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.typeScale.headlineSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            subtitle,
            style: theme.typeScale.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
