import 'package:flutter/material.dart';

class UpdateIconButton extends StatelessWidget {
  const UpdateIconButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    this.tooltip = 'Aktualisieren',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;

    return IconButton(
      tooltip: tooltip,
      onPressed: isLoading ? null : onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading
            ? SizedBox(
                key: const ValueKey('loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            : const Icon(
                Icons.refresh_outlined,
                key: ValueKey('refresh'),
              ),
      ),
    );
  }
}
