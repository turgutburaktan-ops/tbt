import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'swipe_to_reply.dart';

class RouteChatBubble extends StatelessWidget {
  const RouteChatBubble({
    super.key,
    required this.mine,
    required this.name,
    required this.text,
    required this.time,
    required this.onReply,
    this.avatar,
    this.attachment,
    this.replyText,
    this.onProfile,
    this.pending = false,
  });
  final bool mine, pending;
  final String name, text, time;
  final String? replyText;
  final Widget? avatar, attachment;
  final VoidCallback onReply;
  final VoidCallback? onProfile;
  @override
  Widget build(BuildContext context) => SwipeToReply(
    onReply: onReply,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onProfile,
                child:
                    avatar ??
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.surfaceStrong,
                      child: Icon(
                        Icons.person_outline,
                        size: 17,
                        color: Colors.white70,
                      ),
                    ),
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .76,
              ),
              child: GestureDetector(
                onLongPress: onReply,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
                  decoration: BoxDecoration(
                    color: mine
                        ? AppColors.messageOutgoing
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 5),
                      bottomRight: Radius.circular(mine ? 5 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!mine)
                        GestureDetector(
                          onTap: onProfile,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      if (replyText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(
                                color: AppColors.primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            replyText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      attachment ??
                          Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          pending ? 'Gönderiliyor…' : time,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
