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
  bool _isInitialized = false;

  StreamVideo? get streamVideo => _streamVideo;
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    required String userId,
    required String userName,
    required String apiKey,
    required String token,
  }) async {
    try {
      if (_isInitialized) {
        log('Video call service already initialized');
        return;
      }

      log('Initializing video call service...');
      
      _currentUser = User(id: userId, name: userName);
      _streamVideo = StreamVideo(apiKey, user: _currentUser!, userToken: token);
      
      // Wait for connection
      await _streamVideo!.connect();
      _isInitialized = true;
      
      log('Video call service initialized successfully');
    } catch (e) {
      log('Error initializing video call service: $e');
      _isInitialized = false;
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
      final call = _streamVideo!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      // Create the call with member IDs
      await call.getOrCreate(memberIds: memberIds);
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
      
      // Join the call immediately after creating it
      await call.join();
      
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              call: call,
              receiverName: 'Video Call', // You can pass the actual name
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
            builder: (context) => CallScreen(
              call: call,
              receiverName: 'Video Call',
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

class CallScreen extends StatefulWidget {
  final Call call;
  final String receiverName;

  const CallScreen({
    super.key, 
    required this.call,
    this.receiverName = 'Video Call',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isCameraEnabled = true;
  bool _isMicrophoneEnabled = true;
  bool _isCallConnected = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupCall();
    _listenToCallState();
  }

  void _setupCall() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Enable camera and microphone
      await widget.call.camera.enable();
      await widget.call.microphone.enable();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      log('Error setting up call: $e');
      setState(() {
        _error = 'Failed to setup call: $e';
        _isLoading = false;
      });
    }
  }

  void _listenToCallState() {
    widget.call.state.listen((callState) {
      if (mounted) {
        setState(() {
          _isCallConnected = callState.status == CallStatus.joined;
        });
      }
    });
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
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorScreen();
    }

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return StreamBuilder<CallState>(
      stream: widget.call.state,
      builder: (context, snapshot) {
        final callState = snapshot.data;
        final participants = callState?.callParticipants ?? [];

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Colors.black,
                  ],
                ),
              ),
            ),

            if (participants.isNotEmpty && _isCallConnected)
              _buildParticipantsView(participants)
            else
              _buildWaitingScreen(),

            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: _buildControlsBar(),
            ),

            Positioned(top: 20, left: 20, right: 20, child: _buildTopBar()),
          ],
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF16213e),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'Setting up video call...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF16213e),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.receiverName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          Text(
            widget.receiverName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _isCallConnected ? 'Connected' : 'Connecting...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),

          if (!_isCallConnected) ...[
            const SizedBox(height: 20),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantsView(List<CallParticipantState> participants) {
    if (participants.length == 1) {
      return SizedBox.expand(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: StreamVideoRenderer(
            call: widget.call,
            participant: participants.first,
            videoTrackType: SfuTrackType.video,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: participants.length > 4 ? 3 : 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: StreamVideoRenderer(
                call: widget.call,
                participant: participants[index],
                videoTrackType: SfuTrackType.video,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            isActive: _isCameraEnabled,
            onPressed: () async {
              try {
                if (_isCameraEnabled) {
                  await widget.call.camera.disable();
                } else {
                  await widget.call.camera.enable();
                }
                setState(() {
                  _isCameraEnabled = !_isCameraEnabled;
                });
              } catch (e) {
                log('Error toggling camera: $e');
              }
            },
          ),

          _buildControlButton(
            icon: _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            isActive: _isMicrophoneEnabled,
            onPressed: () async {
              try {
                if (_isMicrophoneEnabled) {
                  await widget.call.microphone.disable();
                } else {
                  await widget.call.microphone.enable();
                }
                setState(() {
                  _isMicrophoneEnabled = !_isMicrophoneEnabled;
                });
              } catch (e) {
                log('Error toggling microphone: $e');
              }
            },
          ),

          _buildControlButton(
            icon: Icons.call_end,
            isActive: false,
            backgroundColor: Colors.red,
            onPressed: () {
              widget.call.leave();
              Navigator.pop(context);
            },
          ),

          _buildControlButton(
            icon: Icons.flip_camera_ios,
            isActive: true,
            onPressed: () async {
              try {
                await widget.call.camera.flip();
              } catch (e) {
                log('Error flipping camera: $e');
              }
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
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isActive ? Colors.white24 : Colors.white12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isActive ? Colors.white38 : Colors.white24,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isCallConnected ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.videocam, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            _isCallConnected ? 'Video Call' : 'Connecting...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_isCallConnected)
            StreamBuilder<Duration>(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final callState = widget.call.state.value;
                final startedAt = callState.startedAt;
                if (startedAt != null) {
                  final duration = DateTime.now().difference(startedAt);
                  return Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return const Text(
                  '00:00',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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