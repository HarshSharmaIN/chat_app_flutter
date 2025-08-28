import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:chat_app/data/repositories/chat_repository.dart';
import 'package:chat_app/logic/cubits/chat/chat_state.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _chatRepository;
  final String currentUserId;
  bool _isInChat = false;

  StreamSubscription? _messagesSubscription;
  StreamSubscription? _onlineStatusSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _blockStatusSubscription;
  StreamSubscription? _amIBlockStatusSubscription;
  Timer? typingTimer;

  ChatCubit({
    required ChatRepository chatRepository,
    required this.currentUserId,
  }) : _chatRepository = chatRepository,
       super(const ChatState());

  void enterChat(String receiverId) async {
    _isInChat = true;
    emit(state.copyWith(status: ChatStatus.loading));
    try {
      final chatRoom = await _chatRepository.getOrCreateChatRoom(
        currentUserId,
        receiverId,
      );
      emit(
        state.copyWith(
          chatRoomId: chatRoom.id,
          receiverId: receiverId,
          status: ChatStatus.loaded,
        ),
      );
      _subscribeToMessages(chatRoom.id);
      _subscribeToOnlineStatus(receiverId);
      _subscribeToTypingStatus(chatRoom.id);
      _subscribeToBlockStatus(receiverId);
      await _chatRepository.updateOnlineStatus(currentUserId, true);
    } catch (e) {
      emit(
        state.copyWith(
          status: ChatStatus.error,
          error: "Failed to create chat room",
        ),
      );
    }
  }

  Future<void> sendMessage({
    required String content,
    required String receiverId,
  }) async {
    if (state.chatRoomId == null) return;

    try {
      await _chatRepository.sendMessage(
        chatRoomId: state.chatRoomId!,
        senderId: currentUserId,
        receiverId: receiverId,
        content: content,
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ChatStatus.error,
          error: "Failed to send message",
        ),
      );
    }
  }

  Future<void> loadMoreMessage() async {
    if (state.status != ChatStatus.loaded ||
        state.messages.isEmpty ||
        !state.hasMoreMessages ||
        state.isLoadingMore) {
      return;
    }
    try {
      emit(state.copyWith(isLoadingMore: true));
      final lastMessage = state.messages.last;
      final lastDoc = await _chatRepository
          .getChatRoomMessages(state.chatRoomId!)
          .doc(lastMessage.id)
          .get();
      final moreMessages = await _chatRepository.getMoreMessages(
        state.chatRoomId!,
        lastDocument: lastDoc,
      );
      if (moreMessages.isEmpty) {
        emit(state.copyWith(hasMoreMessages: false, isLoadingMore: false));
        return;
      }
      emit(
        state.copyWith(
          messages: [...state.messages, ...moreMessages],
          hasMoreMessages: moreMessages.length > 20,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          error: "Failed to load more messages",
        ),
      );
    }
  }

  void _subscribeToMessages(String chatRoomId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatRepository
        .getMessages(chatRoomId)
        .listen(
          (messages) {
            if (_isInChat) {
              _markMessagesAsRead(chatRoomId);
            }
            emit(state.copyWith(messages: messages, error: null));
          },
          onError: (error) {
            emit(
              state.copyWith(
                error: "Failed to load messages",
                status: ChatStatus.error,
              ),
            );
          },
        );
  }

  void _subscribeToOnlineStatus(String userId) {
    _onlineStatusSubscription?.cancel();
    _onlineStatusSubscription = _chatRepository
        .getUserOnlineStatus(userId)
        .listen(
          (status) {
            final isOnline = status["isOnline"] as bool;
            final lastSeen = status["lastSeen"] as Timestamp?;

            emit(
              state.copyWith(
                isReceiverOnline: isOnline,
                receiverLastSeen: lastSeen,
              ),
            );
          },
          onError: (error) {
            print("error getting online status");
          },
        );
  }

  void _subscribeToTypingStatus(String chatRoomId) {
    _typingSubscription?.cancel();
    _typingSubscription = _chatRepository
        .getTypingStatus(chatRoomId)
        .listen(
          (status) {
            final isTyping = status["isTyping"] as bool;
            final typingUserId = status["typingUserId"] as String?;

            emit(
              state.copyWith(
                isReceiverTyping: isTyping && typingUserId != currentUserId,
              ),
            );
          },
          onError: (error) {
            print("error getting online status");
          },
        );
  }

  void _subscribeToBlockStatus(String otherUserId) {
    _blockStatusSubscription?.cancel();
    _blockStatusSubscription = _chatRepository
        .isUserBlocked(currentUserId, otherUserId)
        .listen(
          (isBlocked) {
            emit(state.copyWith(isUserBlocked: isBlocked));

            _amIBlockStatusSubscription?.cancel();
            _blockStatusSubscription = _chatRepository
                .amIBlocked(currentUserId, otherUserId)
                .listen((isBlocked) {
                  emit(state.copyWith(amIBlocked: isBlocked));
                });
          },
          onError: (error) {
            print("error getting online status");
          },
        );
  }

  void startTyping() {
    if (state.chatRoomId != null) {
      return;
    }
    typingTimer?.cancel();
    _updateTypingStatus(true);
    typingTimer = Timer(Duration(seconds: 3), () {
      _updateTypingStatus(false);
    });
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (state.chatRoomId == null) return;

    try {
      await _chatRepository.updateTypingStatus(
        state.chatRoomId!,
        currentUserId,
        isTyping,
      );
    } catch (e) {
      print("Error getting typing status");
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await _chatRepository.blockUser(currentUserId, userId);
    } catch (e) {
      emit(state.copyWith(error: "failed to block user: $e"));
    }
  }

  Future<void> unBlockUser(String userId) async {
    try {
      await _chatRepository.unBlockUsers(currentUserId, userId);
    } catch (e) {
      emit(state.copyWith(error: "failed to unblock user: $e"));
    }
  }

  Future<void> _markMessagesAsRead(String chatRoomId) async {
    try {
      await _chatRepository.markMessageAsRead(chatRoomId, currentUserId);
    } catch (e) {
      print("Error marking messages as read.");
    }
  }

  Future<Call> createCall() async {
    return StreamVideo.instance.makeCall(
      callType: StreamCallType.defaultType(),
      id: state.chatRoomId!,
    );
  }

  Future<void> leaveChat() async {
    _isInChat = false;
    _messagesSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _typingSubscription?.cancel();
    _blockStatusSubscription?.cancel();
    _amIBlockStatusSubscription?.cancel();
    typingTimer?.cancel();
  }
}
