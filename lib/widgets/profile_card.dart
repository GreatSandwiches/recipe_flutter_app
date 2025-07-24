import 'package:flutter/material.dart';

/// A card widget that displays user profile information.
/// 
/// Shows the user's name and optionally their profile image.
/// If no image URL is provided, displays a default person icon.
class ProfileCard extends StatelessWidget {
  /// The name to display on the profile card.
  final String name;
  
  /// Optional URL for the user's profile image.
  final String? imageUrl;

  /// Creates a profile card with the specified name and optional image.
  const ProfileCard({super.key, required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        size: 40,
                      color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}