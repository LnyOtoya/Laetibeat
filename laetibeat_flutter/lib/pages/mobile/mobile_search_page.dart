import 'package:flutter/widgets.dart';

import '../search/search_view.dart';

class MobileSearchPage extends StatelessWidget {
  const MobileSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SearchView(
      layoutBuilder: (context, content) => content,
    );
  }
}
