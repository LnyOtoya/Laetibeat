import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/mobile_large_subpage_app_bar.dart';

enum _ServerScheme { http, https }

/// Opensubsonic 服务器配置页面。
class MobileOpensubsonicConfigPage extends StatefulWidget {
  const MobileOpensubsonicConfigPage({super.key});

  @override
  State<MobileOpensubsonicConfigPage> createState() =>
      _MobileOpensubsonicConfigPageState();
}

class _MobileOpensubsonicConfigPageState
    extends State<MobileOpensubsonicConfigPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  _ServerScheme _scheme = _ServerScheme.http;
  bool _tested = false;

  @override
  void dispose() {
    _urlController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: 'Opensubsonic',
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: M3EDropdownMenu<_ServerScheme>(
                    singleSelect: true,
                    showChipAnimation: false,
                    items: [
                      M3EDropdownItem<_ServerScheme>(
                        label: 'http',
                        value: _ServerScheme.http,
                        selected: _scheme == _ServerScheme.http,
                      ),
                      M3EDropdownItem<_ServerScheme>(
                        label: 'https',
                        value: _ServerScheme.https,
                        selected: _scheme == _ServerScheme.https,
                      ),
                    ],
                    fieldStyle: const M3EDropdownFieldStyle(
                      hintText: 'http',
                      showArrow: false,
                    ),
                    onSelectionChanged:
                        (List<M3EDropdownItem<_ServerScheme>> items) {
                          if (items.isEmpty) return;
                          final _ServerScheme next = items.first.value;
                          if (next == _scheme) return;
                          setState(() => _scheme = next);
                        },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: M3ETextField(
                    controller: _urlController,
                    variant: M3ETextFieldVariant.filled,
                    maxLines: 1,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    label: '服务器 URL',
                    supportingText: '配置URL',
                    supportingTextOnFocusOnly: false,
                    isRequired: true,
                    placeholder: 'music.example.com',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 14, 6, 0),
                  child: Text(':'),
                ),
                SizedBox(
                  width: 78,
                  child: M3ETextField(
                    controller: _portController,
                    variant: M3ETextFieldVariant.filled,
                    maxLines: 1,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    label: '端口',
                    supportingText: '端口号',
                    supportingTextOnFocusOnly: false,
                    isRequired: false,
                    placeholder: '4533',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            M3ETextField(
              controller: _usernameController,
              variant: M3ETextFieldVariant.filled,
              maxLines: 1,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              label: '用户名',
              supportingText: '用户名',
              supportingTextOnFocusOnly: false,
              isRequired: true,
              leading: const Icon(M3EIcons.person),
            ),
            const SizedBox(height: 16),
            M3ETextField(
              controller: _passwordController,
              variant: M3ETextFieldVariant.filled,
              maxLines: 1,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              label: '密码',
              supportingText: '密码',
              supportingTextOnFocusOnly: false,
              isRequired: true,
              leading: const Icon(M3EIcons.lock),
              obscureText: true,
              showPasswordToggle: true,
              showPasswordSemanticsLabel: '显示密码',
              hidePasswordSemanticsLabel: '隐藏密码',
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                M3EButton(
                  size: M3EButtonSize.md,
                  shape: M3EButtonShape.square,
                  label: const Text('测试'),
                  onPressed: () {
                    setState(() => _tested = true);
                  },
                ),
                const SizedBox(height: 12),
                M3EButton(
                  size: M3EButtonSize.md,
                  shape: M3EButtonShape.square,
                  style: M3EButtonStyle.tonal,
                  enabled: _tested,
                  label: const Text('扫描'),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
