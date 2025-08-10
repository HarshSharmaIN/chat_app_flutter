import 'dart:io';
import 'package:chat_app/data/models/chat_message.dart';
import 'package:chat_app/data/services/service_locator.dart';
import 'package:chat_app/data/services/video_call_service.dart';
import 'package:chat_app/config/theme/app_theme.dart';
import 'package:chat_app/logic/cubits/chat/chat_cubit.dart';
import 'package:chat_app/logic/cubits/chat/chat_state.dart';
import 'package:chat_app/presentation/widgets/loading_dots.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ChatMessageSceen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String currentUserName;
  const ChatMessageSceen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.currentUserName,
  });

  @override
  State<ChatMessageSceen> createState() => _ChatMessageSceenState();
}

class _ChatMessageSceenState extends State<ChatMessageSceen> {
  final TextEditingController messageController = TextEditingController();
  late final ChatCubit _chatCubit;
  final _scrollController = ScrollController();
  List<ChatMessage> _previousMessages = [];

  bool _isComposing = false;
  bool _showEmoji = false;

  @override
  void initState() {
    _chatCubit = getIt<ChatCubit>();
    _chatCubit.enterChat(widget.receiverId);
    messageController.addListener(_onTextChange);
    _scrollController.addListener(_onScroll);
    super.initState();
  }

  Future<void> _handleSendMessage() async {
    final messageText = messageController.text.trim();
    messageController.clear();
    await _chatCubit.sendMessage(
      content: messageText,
      receiverId: widget.receiverId,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _chatCubit.loadMoreMessage();
    }
  }

  void _onTextChange() {
    final isComposing = messageController.text.isNotEmpty;

    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
      if (isComposing) {
        _chatCubit.startTyping();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _hasNewMessages(List<ChatMessage> messages) {
    if (messages.length != _previousMessages.length) {
      _scrollToBottom();
      _previousMessages = messages;
    }
  }

  Future<void> _startVideoCall() async {
    try {
      final videoService = getIt<VideoCallService>();
      
      // Initialize video service if not already done
      if (videoService.streamVideo == null) {
        // You'll need to get these from your Stream dashboard
        await videoService.initialize( 
          userId: _chatCubit.currentUserId,
          userName: widget.currentUserName,
          apiKey: 'your_stream_api_key', // Replace with your API key
          token: 'your_user_token', // Replace with your user token
        );
      }

      final callId = '${_chatCubit.currentUserId}_${widget.receiverId}_${DateTime.now().millisecondsSinceEpoch}';
      
      await videoService.startCall(
        callId: callId, 
        memberIds: [widget.receiverId],
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start video call: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    _chatCubit.leaveChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        scrolledUnderElevation: 4,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
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
                  widget.receiverName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  BlocBuilder<ChatCubit, ChatState>(
                    bloc: _chatCubit,
                    builder: (context, state) {
                      if (state.isReceiverTyping) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "typing",
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const SizedBox(
                              width: 20,
                              height: 12,
                              child: LoadingDots(),
                            ),
                          ],
                        );
                      }
                      if (state.isReceiverOnline) {
                        return Text(
                          "Online",
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                      if (state.receiverLastSeen != null) {
                        final lastSeen = state.receiverLastSeen!.toDate();
                        return Text(
                          "last seen at ${DateFormat('h:mm a').format(lastSeen)}",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => _startVideoCall(),
              icon: const Icon(
                Icons.videocam_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          BlocBuilder<ChatCubit, ChatState>(
            bloc: _chatCubit,
            builder: (context, state) {
              if (state.isUserBlocked) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: TextButton.icon(
                    onPressed: () => _chatCubit.unBlockUser(widget.receiverId),
                    label: const Text("Unblock"),
                    icon: const Icon(Icons.block),
                  ),
                );
              }
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) async {
                    if (value == "block") {
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text("Block User?"),
                          content: Text("You won't receive messages from ${widget.receiverName}"),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                "Block",
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _chatCubit.blockUser(widget.receiverId);
                      }
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                      value: "block",
                      child: Row(
                        children: [
                          Icon(Icons.block, color: AppTheme.errorColor),
                          SizedBox(width: 8),
                          Text("Block User"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: BlocConsumer<ChatCubit, ChatState>(
            listener: (context, state) {
              _hasNewMessages(state.messages);
            },
            bloc: _chatCubit,
            builder: (context, state) {
              if (state.status == ChatStatus.loading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                );
              }
              if (state.status == ChatStatus.error) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.error ?? "Something went wrong",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  if (state.amIBlocked)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.errorColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.block,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You have been blocked by ${widget.receiverName}",
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        final isMe = message.senderId == _chatCubit.currentUserId;
                        return MessageBubble(message: message, isMe: isMe);
                      },
                    ),
                  ),
                  if (!state.amIBlocked && !state.isUserBlocked)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showEmoji = !_showEmoji;
                                      if (_showEmoji) {
                                        FocusScope.of(context).unfocus();
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    _showEmoji
                                        ? Icons.keyboard_rounded
                                        : Icons.emoji_emotions_outlined,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    onTap: () {
                                      if (_showEmoji) {
                                        setState(() {
                                          _showEmoji = false;
                                        });
                                      }
                                    },
                                    controller: messageController,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    maxLines: 4,
                                    minLines: 1,
                                    decoration: InputDecoration(
                                      hintText: "Type a message...",
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _isComposing
                                      ? AppTheme.primaryGradient
                                      : LinearGradient(
                                          colors: [
                                            Colors.grey.shade300,
                                            Colors.grey.shade300,
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isComposing
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.send_rounded,
                                    color: _isComposing
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                  ),
                                  onPressed: _isComposing
                                      ? _handleSendMessage
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          if (_showEmoji)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              height: 250,
                              child: EmojiPicker(
                                textEditingController: messageController,
                                onEmojiSelected: (category, emoji) {
                                  messageController
                                    ..text += emoji.emoji
                                    ..selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset: messageController.text.length,
                                      ),
                                    );
                                  setState(() {
                                    _isComposing =
                                        messageController.text.isNotEmpty;
                                  });
                                },
                                config: Config(
                                  height: 250,
                                  emojiViewConfig: EmojiViewConfig(
                                    columns: 7,
                                    emojiSizeMax:
                                        32.0 * (Platform.isIOS ? 1.30 : 1.0),
                                    verticalSpacing: 0,
                                    horizontalSpacing: 0,
                                    gridPadding: EdgeInsets.zero,
                                    backgroundColor: Colors.white,
                                    loadingIndicator: const SizedBox.shrink(),
                                  ),
                                  categoryViewConfig: const CategoryViewConfig(
                                    initCategory: Category.RECENT,
                                  ),
                                  bottomActionBarConfig: BottomActionBarConfig(
                                    enabled: true,
                                    backgroundColor: Colors.white,
                                    buttonColor: AppTheme.primaryColor,
                                  ),
                                  skinToneConfig: const SkinToneConfig(
                                    enabled: true,
                                    dialogBackgroundColor: Colors.white,
                                    indicatorColor: Colors.grey,
                                  ),
                                  searchViewConfig: SearchViewConfig(
                                    backgroundColor: Colors.white,
                                    buttonIconColor: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            left: isMe ? 64 : 16,
            right: isMe ? 16 : 64,
            bottom: 8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isMe
                ? AppTheme.primaryGradient
                : null,
            color: isMe ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('h:mm a').format(message.timestamp.toDate()),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      size: 16,
                      message.status == MessageStatus.read
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      color: message.status == MessageStatus.read
                          ? AppTheme.successColor
                          : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
