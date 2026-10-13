import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

//可选中卡片列表:固化"长按切换选中高亮+leading点击翻转选中图标"效果
//内部自建并托管M3ESelectionController,各页面无需单独实现选中逻辑
//
//[controller]为空时自建并负责释放(适用单列表);
//传入外部controller时(如分组列表每组一个)不释放,由外部负责生命周期
//
//形态二选一:
//- [SelectableCardList.builder]:懒加载ListView,作为页面主滚动列表(需有界高度)
//- [SelectableCardList.eager]  :即时构建Column,可嵌入SliverToBoxAdapter供分组使用
class SelectableCardList extends StatefulWidget {
  ///懒加载ListView,作页面主滚动列表(占据有界高度,如Expanded内)
  const SelectableCardList.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.onTap,
    this.onLongPress,
    this.selectionKey,
  }) : lazy = true;

  ///即时构建,可嵌入SliverToBoxAdapter(分组列表每组一个)
  const SelectableCardList.eager({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.onTap,
    this.onLongPress,
    this.selectionKey,
  }) : lazy = false;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final M3ESelectionController? controller;
  final void Function(int index)? onTap;
  final void Function(int index)? onLongPress;

  //数据/上下文变化(如切换筛选)时清空选中,避免陈旧高亮
  final Object? selectionKey;

  //true=懒加载ListView,false=即时Column
  final bool lazy;

  @override
  State<SelectableCardList> createState() => _SelectableCardListState();
}

class _SelectableCardListState extends State<SelectableCardList> {
  //外部注入了controller则共享,否则内部自建
  late final M3ESelectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? M3ESelectionController();
  }

  @override
  void didUpdateWidget(covariant SelectableCardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionKey != widget.selectionKey) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final M3ESelectionController controller = widget.controller ?? _controller;
    final Widget Function(BuildContext, int) itemBuilder = widget.itemBuilder;
    if (widget.lazy) {
      return M3EList.scrollable(
        itemCount: widget.itemCount,
        selection: true,
        selectionController: controller,
        selectionState: const M3EListSelectionState(
          selectedIcon: Icon(M3EIcons.check),
        ),
        onTap: widget.onTap,
        onLongPress: (i) {
          controller.toggle(i);
          widget.onLongPress?.call(i);
        },
        itemBuilder: itemBuilder,
      );
    }
    return M3EList(
      itemCount: widget.itemCount,
      selection: true,
      selectionController: controller,
      selectionState: const M3EListSelectionState(
        selectedIcon: Icon(M3EIcons.check),
      ),
      onTap: widget.onTap,
      onLongPress: (i) {
        controller.toggle(i);
        widget.onLongPress?.call(i);
      },
      itemBuilder: itemBuilder,
    );
  }
}