import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../shared/widgets/rider_widgets.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  void _send(AppState state) {
    final message = state.sendGroupMessage(widget.groupId, _controller.text);
    if (message == null) return;
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEnd(animated: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final group = state.groupById(widget.groupId);
    final theme = Theme.of(context);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Group not found')),
      );
    }

    final member = state.isMemberOf(group.id);
    final messages = state.messagesForGroup(group.id);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name),
            Text(
              '${group.memberCount} members',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.stone,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !member
                ? _JoinPrompt(
                    onJoin: () => state.toggleGroupMembership(group.id),
                  )
                : messages.isEmpty
                    ? const _EmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final previous =
                              index > 0 ? messages[index - 1] : null;
                          final showDay = previous == null ||
                              !_sameDay(previous.createdAt, message.createdAt);
                          final mine = message.senderId == state.currentUserId;
                          final rider = state.riderById(message.senderId);
                          final showAvatar = !mine &&
                              (previous == null ||
                                  previous.senderId != message.senderId ||
                                  showDay);

                          return Column(
                            children: [
                              if (showDay) _DayDivider(date: message.createdAt),
                              _ChatBubble(
                                message: message,
                                mine: mine,
                                rider: rider,
                                showAvatar: showAvatar,
                                showName: showAvatar,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          if (member)
            _Composer(
              controller: _controller,
              focusNode: _focusNode,
              onSend: () => _send(state),
            ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final label = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat('EEE, MMM d').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.stone,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.mine,
    required this.rider,
    required this.showAvatar,
    required this.showName,
  });

  final GroupMessage message;
  final bool mine;
  final RiderProfile? rider;
  final bool showAvatar;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm').format(message.createdAt);
    final bubbleColor = mine
        ? AppColors.forest
        : theme.brightness == Brightness.dark
            ? AppColors.cardDark
            : Colors.white;
    final textColor = mine ? Colors.white : theme.colorScheme.onSurface;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      child: Container(
        margin: EdgeInsets.only(
          top: showName || showAvatar ? 8 : 3,
          left: mine ? 40 : 0,
          right: mine ? 0 : 40,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine
              ? null
              : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showName && !mine && rider != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  rider!.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: rider!.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (mine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 36,
          child: showAvatar && rider != null
              ? GestureDetector(
                  onTap: () => context.push('/profile/rider/${rider!.id}'),
                  child: RiderAvatar(rider: rider!, radius: 16),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + bottom),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message the group…',
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? AppColors.cardDark
                      : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: AppColors.stone.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Say hi and coordinate the next ride.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.stone,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.stone),
            const SizedBox(height: 12),
            Text(
              'Join to chat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Only group members can read and send messages.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.stone,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onJoin, child: const Text('Join group')),
          ],
        ),
      ),
    );
  }
}
