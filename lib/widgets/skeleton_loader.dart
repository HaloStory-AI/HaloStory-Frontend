import 'package:flutter/material.dart';

class SkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;

  const SkeletonWidget({
    super.key,
    this.width = double.infinity,
    this.height = 20.0,
    this.borderRadius = 8.0,
    this.color,
  });

  @override
  State<SkeletonWidget> createState() => _SkeletonWidgetState();
}

class _SkeletonWidgetState extends State<SkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color:
              widget.color ??
              (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;

    return ListView.separated(
      itemCount: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) =>
          Divider(height: 1, indent: 80, endIndent: 16, color: dividerColor),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SkeletonWidget(width: 55, height: 55, borderRadius: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonWidget(
                          width: MediaQuery.of(context).size.width * 0.3,
                          height: 16,
                        ),
                        const SkeletonWidget(width: 40, height: 12),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const SkeletonWidget(width: double.infinity, height: 14),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BotGridSkeleton extends StatelessWidget {
  const BotGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? theme.colorScheme.outline : Colors.grey.shade100,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonWidget(width: 70, height: 70, borderRadius: 35),
              SizedBox(height: 16),
              SkeletonWidget(width: 80, height: 16),
              SizedBox(height: 8),
              SkeletonWidget(width: 120, height: 12),
            ],
          ),
        );
      },
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      children: [
        const Center(
          child: Column(
            children: [
              SkeletonWidget(width: 100, height: 100, borderRadius: 50),
              SizedBox(height: 16),
              SkeletonWidget(width: 150, height: 24),
              SizedBox(height: 8),
              SkeletonWidget(width: 200, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const SkeletonWidget(width: 180, height: 20),
        const SizedBox(height: 15),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonWidget(
              width: double.infinity,
              height: 70,
              borderRadius: 12,
            ),
          ),
        ),
        const SizedBox(height: 30),
        const SkeletonWidget(width: 100, height: 20),
        const SizedBox(height: 15),
        ...List.generate(
          2,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonWidget(
              width: double.infinity,
              height: 50,
              borderRadius: 8,
            ),
          ),
        ),
      ],
    );
  }
}
