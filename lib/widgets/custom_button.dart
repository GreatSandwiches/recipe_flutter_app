import 'package:flutter/material.dart';

/// A customizable button widget that can display text with or without an icon.
/// 
/// This widget provides consistent styling across the app while allowing
/// customization of colors, size, and content.
class CustomButton extends StatelessWidget {
  /// The text to display on the button.
  final String label;
  
  /// Callback function executed when the button is pressed.
  final VoidCallback onPressed;
  
  /// Background color of the button. Defaults to theme's primary color.
  final Color? backgroundColor;
  
  /// Text color of the button. Defaults to white.
  final Color? textColor;
  
  /// Width of the button. If null, uses intrinsic width.
  final double? width;
  
  /// Height of the button. Defaults to 48 pixels.
  final double? height;
  
  /// Optional icon to display alongside the text.
  final Icon? icon;

  /// Creates a custom button with the specified properties.
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 48,
      child: icon != null
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    backgroundColor ?? Theme.of(context).primaryColor,
                foregroundColor: textColor ?? Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onPressed,
              icon: icon!,
              label: Text(label),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    backgroundColor ?? Theme.of(context).primaryColor,
                foregroundColor: textColor ?? Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }
}