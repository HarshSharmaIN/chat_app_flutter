import 'package:chat_app/data/models/chat_room_model.dart';
import 'package:chat_app/data/repositories/chat_repository.dart';
import 'package:chat_app/data/services/service_locator.dart';
import 'package:chat_app/config/theme/app_theme.dart';
import 'package:chat_app/presentation/widgets/animated_list_tile.dart';
import 'package:flutter/material.dart';

class ChatListTile extends StatefulWidget {
  final ChatRoomModel chat;
  final String currentUserId;
  final VoidCallback onTap;
  final int animationDelay;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
    this.animationDelay = 0,
  });

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<ChatListTile> {
  String _getOtherUsername() {
    final otherUserId = widget.chat.participants.firstWhere(
      (id) => id != widget.currentUserId,
    );
    return widget.chat.participantsName![otherUserId] ?? "Unknown";
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedListTile(
      animationDelay: widget.animationDelay,
      onTap: widget.onTap,
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _getOtherUsername()[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      title: Text(
        _getOtherUsername(),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.chat.lastMessage ?? "No messages yet",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            if (widget.chat.lastMessageTime != null)
              Text(
                _formatTime(widget.chat.lastMessageTime!.toDate()),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      trailing: StreamBuilder<int>(
        stream: getIt<ChatRepository>().getUnreadCount(widget.chat.id, widget.currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == 0) {
            return const SizedBox();
          }
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                snapshot.data! > 99 ? '99+' : snapshot.data.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
