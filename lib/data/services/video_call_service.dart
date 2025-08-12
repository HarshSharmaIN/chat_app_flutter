import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_app/data/services/stream_token_service.dart';

class VideoCallService {
  static VideoCallService? _instance;
  static VideoCallService get instance => _instance ??= VideoCallService._();
  VideoCallService._();

  StreamVideo? _streamVideo;
  User? _currentUser;
  bool _isInitialized = false;

  StreamVideo? get streamVideo => _streamVideo;
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    required String userId,
    required String userName,
    required String apiKey,
  }) async {
    try {
      if (_isInitialized && _streamVideo != null) {
        log('Video call service already initialized');
        return;
      }

      log('Initializing video call service for user: $userId');
      
      // Generate token using the service
      final token = await StreamTokenService.generateUserToken(userId: userId);
      
      _currentUser = User(id: userId, name: userName);
      _streamVideo = StreamVideo(
        apiKey,
        user: _currentUser!,
        userToken: token,
      );
      
      // Connect to Stream
      await _streamVideo!.connect();
      _isInitialized = true;
      
      log('Video call service initialized successfully');
    } catch (e) {
      log('Error initializing video call service: $e');
      _isInitialized = false;
      _streamVideo = null;
      _currentUser = null;
      rethrow;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final permissions = [Permission.camera, Permission.microphone];
      Map<Permission, PermissionStatus> statuses = await permissions.request();
      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      log('Error requesting permissions: $e');
      return false;
    }
  }

  Future<Call> createCall({
    required String callId,
    required List<String> memberIds,
  }) async {
    if (_streamVideo == null || !_isInitialized) {
      throw Exception('Video service not initialized');
    }

    try {
      log('Creating call with ID: $callId');
      
      final call = _streamVideo!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      // Create the call with member IDs
      await call.getOrCreate(memberIds: memberIds.map((id) => MemberRequest(userId: id)).toList());
      
      log('Call created successfully');
      return call;
    } catch (e) {
      log('Error creating call: $e');
      rethrow;
    }
  }

  Future<void> startCall({
    required String callId,
    required List<String> memberIds,
    required BuildContext context,
    required String receiverName,
  }) async {
    try {
      log('Starting video call...');
      
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('Camera and microphone permissions are required');
      }

      if (!_isInitialized) {
        throw Exception('Video service not initialized');
      }

      final call = await createCall(callId: callId, memberIds: memberIds);
      
      // Join the call
      await call.join();
      
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StreamCallScreen(
              call: call,
              onCallEnded: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      log('Error starting call: $e');
      rethrow;
    }
  }

  Future<void> joinCall({
    required String callId,
    required BuildContext context,
    required String receiverName,
  }) async {
    try {
      if (_streamVideo == null || !_isInitialized) {
        throw Exception('Video service not initialized');
      }

      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('Camera and microphone permissions are required');
      }

      log("Joining call: $callId");

      final call = _streamVideo!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      await call.join();
      log("Call joined successfully");

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StreamCallScreen(
              call: call,
              onCallEnded: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      log('Error joining call: $e');
      rethrow;
    }
  }

  void dispose() {
    _streamVideo?.disconnect();
    _streamVideo = null;
    _currentUser = null;
    _isInitialized = false;
  }
}

// Using Stream's prebuilt call screen
class StreamCallScreen extends StatefulWidget {
  final Call call;
  final VoidCallback onCallEnded;

  const StreamCallScreen({
    super.key,
    required this.call,
    required this.onCallEnded,
  });

  @override
  State<StreamCallScreen> createState() => _StreamCallScreenState();
}

class _StreamCallScreenState extends State<StreamCallScreen> {
  @override
  void initState() {
    super.initState();
    _listenToCallState();
  }

  void _listenToCallState() {
    widget.call.state.listen((callState) {
      // Handle call ended
      if (callState.status == CallStatus.ended || 
          callState.status == CallStatus.left ||
          callState.status == CallStatus.rejected) {
        if (mounted) {
          widget.onCallEnded();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamCallContainer(
      call: widget.call,
      child: StreamCallContent(
        call: widget.call,
        callContentBuilder: (
          BuildContext context,
          Call call,
          CallState callState,
        ) {
          return StreamCallControls(
            call: call,
            localParticipant: callState.localParticipant,
            onLeaveCallTap: () {
              call.leave();
              widget.onCallEnded();
            },
          );
        },
      ),
    );
  }
}