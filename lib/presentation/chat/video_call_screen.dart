import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:chat_app/config/theme/app_theme.dart';

class VideoCallScreen extends StatefulWidget {
  final Call call;
  final String receiverName;

  const VideoCallScreen({
    super.key,
    required this.call,
    required this.receiverName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with TickerProviderStateMixin {
  bool _isCameraEnabled = true;
  bool _isMicrophoneEnabled = true;
  bool _isCallConnected = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupCall();
    _listenToCallState();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  void _setupCall() async {
    try {
      await widget.call.setCameraEnabled(enabled: true);
      await widget.call.setMicrophoneEnabled(enabled: true);
    } catch (e) {
      debugPrint('Error setting up call: $e');
    }
  }

  void _listenToCallState() {
    widget.call.state.listen((callState) {
      setState(() {
        _isCallConnected = callState.status == CallStatus.joined;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
              );
            },
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
            _isCallConnected ? 'Connected' : 'Calling...',
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
              await widget.call.setCameraEnabled(enabled: !_isCameraEnabled);
              setState(() {
                _isCameraEnabled = !_isCameraEnabled;
              });
            },
          ),

          _buildControlButton(
            icon: _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            isActive: _isMicrophoneEnabled,
            onPressed: () async {
              await widget.call.setMicrophoneEnabled(enabled: !_isMicrophoneEnabled);
              setState(() {
                _isMicrophoneEnabled = !_isMicrophoneEnabled;
              });
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