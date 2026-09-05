import 'package:flutter/material.dart';

/// Lazily mounts tabs and retains their state across navigation.
class MarketTabStack extends StatefulWidget {
  const MarketTabStack(
      {super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<MarketTabStack> createState() => _MarketTabStackState();
}

class _MarketTabStackState extends State<MarketTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );
  late final Animation<double> _opacity = Tween<double>(begin: .85, end: 1)
      .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  final Set<int> _visited = {};

  @override
  void didUpdateWidget(covariant MarketTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return FadeTransition(
      opacity: _opacity,
      child: IndexedStack(
        index: widget.index,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            TickerMode(
              enabled: i == widget.index,
              child: _visited.contains(i)
                  ? RepaintBoundary(child: widget.children[i])
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
