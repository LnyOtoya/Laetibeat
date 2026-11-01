import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 歌曲分类内容。
///
/// 后续歌曲列表、详情页和播放逻辑都放在这个独立区域内实现。
class SongsLibraryView extends StatefulWidget {
  const SongsLibraryView({super.key});

  @override
  State<SongsLibraryView> createState() => _SongsLibraryViewState();
}

class _SongsLibraryViewState extends State<SongsLibraryView> {
  String? _selectedSource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              M3EButton.icon(
                icon: const Icon(M3EIcons.shuffle),
                label: const Text('随机播放'),
                style: M3EButtonStyle.filled,
                size: M3EButtonSize.sm,
                shape: M3EButtonShape.round,
                onPressed: () {},
              ),
              const Spacer(),
              M3ESplitButton<String>(
                items: const [],
                label: '排序',
                leadingIcon: M3EIcons.sort,
                style: M3EButtonStyle.tonal,
                size: M3EButtonSize.sm,
                shape: M3EButtonShape.round,
                trailingTooltip: _selectedSource == null
                    ? '选择音源'
                    : '当前音源：$_selectedSource',
                decoration: const M3ESplitButtonDecoration(
                  menuStyle: M3ESplitButtonMenuStyle.popup,
                ),
                onPressed: () {},
                m3eMenuBuilder: (BuildContext context) {
                  return const [
                    M3EMenuEntry(label: 'Subsonic', value: 'Subsonic'),
                    M3EMenuEntry(label: 'Jellyfin', value: 'Jellyfin'),
                    M3EMenuEntry(label: 'Emby音乐', value: 'Emby音乐'),
                    M3EMenuEntry(label: '洛雪音源', value: '洛雪音源'),
                    M3EMenuEntry(label: 'QQ音乐', value: 'QQ音乐'),
                    M3EMenuEntry(label: '网易云', value: '网易云'),
                  ];
                },
                onSelected: (String value) {
                  setState(() => _selectedSource = value);
                },
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
