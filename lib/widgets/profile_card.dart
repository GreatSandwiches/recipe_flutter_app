import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? bio;
  final Color? avatarColor;
  final VoidCallback? onEdit;

  const ProfileCard({super.key, required this.name, this.imageUrl, this.bio, this.avatarColor, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: (avatarColor ?? theme.colorScheme.primary).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: (avatarColor ?? theme.colorScheme.primary).withValues(alpha: .4)),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: avatarColor ?? theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit profile',
                          onPressed: onEdit,
                        )
                    ],
                  ),
                  if (bio != null && bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      bio!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color?.withValues(alpha: .8)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}