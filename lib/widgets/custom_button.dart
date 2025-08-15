import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final IconData? icon;
  final bool loading;
  final bool outlined;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.icon,
    this.loading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                textColor ?? Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          )
        : Text(label);

    final styleBase = (outlined ? OutlinedButton.styleFrom : FilledButton.styleFrom)(
      backgroundColor: outlined ? null : backgroundColor,
      foregroundColor: outlined
          ? Theme.of(context).colorScheme.primary
          : (textColor ?? Theme.of(context).colorScheme.onPrimary),
      minimumSize: Size(width ?? double.infinity, height ?? 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    );

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        style: styleBase,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: child,
      );
    }
    return icon != null
        ? FilledButton.icon(
            onPressed: loading ? null : onPressed,
            style: styleBase,
            icon: Icon(icon),
            label: child,
          )
        : FilledButton(
            onPressed: loading ? null : onPressed,
            style: styleBase,
            child: child,
          );
  }
}