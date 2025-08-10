import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallService {
  static VideoCallService? _instance;
  static VideoCallService get instance => _instance ??= VideoCallService._();
  VideoCallService._();

  StreamVideo? _streamVideo;
  User? _currentUser;

  StreamVideo? get streamVideo => _streamVideo;
  User? get currentUser => _currentUser;

  Future<void> initialize({
    required String userId,
    required String userName,
    required String apiKey,
    required String token,
  }) async {
    try {
      _currentUser = User(
        id: userId,
        name: userName,
      );

      _streamVideo = StreamVideo(
        apiKey,
        user: _currentUser!,
        userToken: token,
      );

      log('Video call service initialized successfully');
    } catch (e) {
      log('Error initializing video call service: $e');
      rethrow;
    }
  }

  Future<bool> requestPermissions() async {
    final permissions = [Permission.camera, Permission.microphone];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<Call> createCall({
    required String callId,
    required List<String> memberIds,
  }) async {
    if (_streamVideo == null) {
      throw Exception('Video service not initialized');
    }

    final call = _streamVideo!.makeCall(
      callType: StreamCallType.defaultType(),
      id: callId,
    );

    // Create the call with member IDs
    await call.getOrCreate(memberIds: memberIds);

    return call;
  }

  Future<void> startCall({
    required String callId,
    required List<String> memberIds,
    required BuildContext context,
  }) async {
    try {
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('Camera and microphone permissions are required');
      }

      final call = await createCall(callId: callId, memberIds: memberIds);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CallScreen(call: call)),
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
  }) async {
    try {
      if (_streamVideo == null) {
        throw Exception('Video service not initialized');
      }

      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        throw Exception('Camera and microphone permissions are required');
      }

      final call = _streamVideo!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      await call.join();

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CallScreen(call: call)),
        );
      }
    } catch (e) {
      log('Error joining call: $e');
      rethrow;
    }
  }

  void dispose() {
    _streamVideo?.dispose();
    _streamVideo = null;
    _currentUser = null;
  }
}

class CallScreen extends StatefulWidget {
  final Call call;

  const CallScreen({super.key, required this.call});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isCameraEnabled = true;
  bool _isMicrophoneEnabled = true;

  @override
  void initState() {
    super.initState();
    _setupCall();
  }

  void _setupCall() async {
    try {
      // Enable camera and microphone
      await widget.call.setCameraEnabled(enabled: true);
      await widget.call.setMicrophoneEnabled(enabled: true);
    } catch (e) {
      log('Error setting up call: $e');
    }
  }

  @override
  void dispose() {
    widget.call.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<CallState>(
          stream: widget.call.state,
          builder: (context, snapshot) {
            final callState = snapshot.data;
            final participants = callState?.callParticipants ?? [];

            return Stack(
              children: [
                // Video participants
                if (participants.isNotEmpty)
                  _buildParticipantsView(participants)
                else
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),

                // Controls overlay
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: _buildControlsBar(),
                ),

                // Top bar with call info
                Positioned(top: 20, left: 20, right: 20, child: _buildTopBar()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildParticipantsView(List<CallParticipantState> participants) {
    if (participants.length == 1) {
      return SizedBox.expand(
        child: StreamVideoRenderer(
          call: widget.call,
          participant: participants.first,
          videoTrackType: SfuTrackType.video,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length > 4 ? 3 : 2,
        childAspectRatio: 0.75,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: StreamVideoRenderer(
              call: widget.call,
              participant: participants[index],
              videoTrackType: SfuTrackType.video,
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Camera toggle
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            isActive: _isCameraEnabled,
            onPressed: () async {
              await widget.call.setCameraEnabled(enabled: !_isCameraEnabled);
              setState(() {
                _isCameraEnabled = !_isCameraEnabled;
              });
            },
          ),

          // Microphone toggle
          _buildControlButton(
            icon: _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            isActive: _isMicrophoneEnabled,
            onPressed: () async {
              await widget.call.setMicrophoneEnabled(
                enabled: !_isMicrophoneEnabled,
              );
              setState(() {
                _isMicrophoneEnabled = !_isMicrophoneEnabled;
              });
            },
          ),

          // End call
          _buildControlButton(
            icon: Icons.call_end,
            isActive: false,
            backgroundColor: Colors.red,
            onPressed: () {
              widget.call.leave();
              Navigator.pop(context);
            },
          ),

          // Switch camera
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            isActive: true,
            onPressed: () async {
              await widget.call.flipCamera();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isActive ? Colors.white24 : Colors.white12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive ? Colors.white38 : Colors.white24,
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Video Call',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          StreamBuilder<CallState>(
            stream: widget.call.state,
            builder: (context, snapshot) {
              final callState = snapshot.data;
              final startedAt = callState?.startedAt;
              if (startedAt != null) {
                final duration = DateTime.now().difference(startedAt);
                return Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                );
              }
              return const Text(
                '00:00',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}