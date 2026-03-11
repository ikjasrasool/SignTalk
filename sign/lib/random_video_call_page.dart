import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────
const String agoraAppId = 'b596587d3333466c9b9c223f9a5bf5b3';
const String agoraToken = '';
const int _maxRoomsToTry = 50;
// ─────────────────────────────────────────────

// Chat message model
class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;
  ChatMessage({required this.text, required this.isMe, required this.time});
}

class RandomVideoCallPage extends StatefulWidget {
  const RandomVideoCallPage({Key? key}) : super(key: key);

  @override
  State<RandomVideoCallPage> createState() => _RandomVideoCallPageState();
}

class _RandomVideoCallPageState extends State<RandomVideoCallPage>
    with SingleTickerProviderStateMixin {
  late RtcEngine _engine;

  bool _engineInitialized = false;
  bool _searching = true;
  bool _callConnected = false;
  bool _localMuted = false;
  bool _localVideoOff = false;
  bool _chatOpen = false;
  int? _remoteUid;

  int _currentRoom = 1;
  String get _currentChannel => 'signtalk_room_$_currentRoom';

  int _remoteUsersInRoom = 0;
  bool _waitingForPartner = false;

  final int _localUid = Random().nextInt(900000) + 100000;

  // ── Chat ──
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _unreadCount = 0;

  // ── Agora RTM (Data Stream for chat) ──
  int? _localStreamId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.95, end: 1.05).animate(_pulseController);
    _initAgora();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _safeLeave();
    super.dispose();
  }

  // ──────────────────────── AGORA INIT ────────────────────────

  Future<void> _initAgora() async {
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('✅ Joined: ${connection.channelId}');
        _waitingForPartner = true;
        Future.delayed(const Duration(seconds: 8), () {
          if (!mounted || !_waitingForPartner) return;
          if (!_callConnected && _remoteUsersInRoom == 0) {
            _moveToNextRoom();
          }
        });
      },

      onUserJoined: (connection, remoteUid, elapsed) {
        _remoteUsersInRoom++;
        if (_remoteUsersInRoom == 1) {
          _waitingForPartner = false;
          setState(() {
            _remoteUid = remoteUid;
            _searching = false;
            _callConnected = true;
          });
          _addSystemMessage('Partner connected! Say hello 👋');
        } else {
          _moveToNextRoom();
        }
      },

      onUserOffline: (connection, remoteUid, reason) {
        setState(() {
          _remoteUid = null;
          _callConnected = false;
          _searching = true;
          _remoteUsersInRoom = 0;
          _messages.clear();
          _chatOpen = false;
          _unreadCount = 0;
        });
        _showSnackBar('Partner left. Finding new partner...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _engine.leaveChannel().then((_) => _joinRoom(1));
        });
      },

      // ── Receive chat via data stream ──
      onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
        final text = String.fromCharCodes(data);
        debugPrint('💬 Received: $text');
        setState(() {
          _messages.add(ChatMessage(
            text: text,
            isMe: false,
            time: DateTime.now(),
          ));
          if (!_chatOpen) _unreadCount++;
        });
        _scrollToBottom();
      },

      onError: (err, msg) {
        debugPrint('❌ Agora Error [$err]: $msg');
      },
    ));

    await _engine.enableVideo();
    await _engine.startPreview();
    setState(() => _engineInitialized = true);
    await _joinRoom(1);
  }

  // ──────────────────────── ROOM LOGIC ────────────────────────

  Future<void> _joinRoom(int roomNumber) async {
    _currentRoom = roomNumber;
    _remoteUsersInRoom = 0;
    _waitingForPartner = false;
    _localStreamId = null;
    if (mounted) setState(() {});

    await _engine.joinChannel(
      token: agoraToken,
      channelId: _currentChannel,
      uid: _localUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Create data stream for chat
    final streamId = await _engine.createDataStream(
      const DataStreamConfig(syncWithAudio: false, ordered: true),
    );
    _localStreamId = streamId;
  }

  Future<void> _moveToNextRoom() async {
    if (_currentRoom >= _maxRoomsToTry) {
      _showSnackBar('All rooms busy. Try again later.');
      return;
    }
    await _engine.leaveChannel();
    await Future.delayed(const Duration(milliseconds: 400));
    await _joinRoom(_currentRoom + 1);
  }

  Future<void> _safeLeave() async {
    try {
      _waitingForPartner = false;
      await _engine.leaveChannel();
      await _engine.release();
    } catch (_) {}
  }

  // ──────────────────────── CHAT ────────────────────────

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _localStreamId == null || !_callConnected) return;

    try {
      // Send via Agora data stream
      await _engine.sendStreamMessage(
        streamId: _localStreamId!,
        data: Uint8List.fromList(text.codeUnits),
        length: text.length,
      );

      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isMe: true,
          time: DateTime.now(),
        ));
      });
      _chatController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('❌ Send error: $e');
      _showSnackBar('Failed to send message');
    }
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: '🔔 $text',
        isMe: false,
        time: DateTime.now(),
      ));
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      if (_chatOpen) _unreadCount = 0;
    });
    if (_chatOpen) _scrollToBottom();
  }

  // ──────────────────────── CONTROLS ────────────────────────

  void _endCall() {
    _safeLeave();
    Navigator.of(context).pop();
  }

  void _toggleMute() async {
    setState(() => _localMuted = !_localMuted);
    await _engine.muteLocalAudioStream(_localMuted);
  }

  void _toggleVideo() async {
    setState(() => _localVideoOff = !_localVideoOff);
    await _engine.muteLocalVideoStream(_localVideoOff);
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  // ──────────────────────── UI ────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Full screen remote video
          _buildRemoteVideo(),

          // Local PiP video (hidden when chat is open)
          if (!_chatOpen) _buildLocalVideo(),

          // Top bar
          _buildTopBar(),

          // Chat panel (slides up from bottom)
          if (_chatOpen) _buildChatPanel(),

          // Bottom controls
          _buildBottomControls(),

          // Searching overlay
          if (_searching) _buildSearchingOverlay(),
        ],
      ),
    );
  }

  // ── Remote Video ──
  Widget _buildRemoteVideo() {
    if (!_callConnected || _remoteUid == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0a0a0f), Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: _currentChannel),
      ),
    );
  }

  // ── Local PiP ──
  Widget _buildLocalVideo() {
    if (!_engineInitialized) return const SizedBox.shrink();
    return Positioned(
      top: 80,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 110,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4facfe), width: 2),
          ),
          child: _localVideoOff
              ? const Center(
              child: Icon(Icons.videocam_off,
                  color: Colors.white54, size: 32))
              : AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top Bar ──
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _callConnected ? 'Connected' : 'Finding partner...',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _callConnected
                          ? 'Private Room $_currentRoom'
                          : 'Scanning room $_currentRoom...',
                      style: const TextStyle(
                          color: Color(0xFFa0a0b2), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_callConnected)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.green, size: 8),
                      SizedBox(width: 4),
                      Text('LIVE',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat Panel ──
  Widget _buildChatPanel() {
    return Positioned(
      top: 100,
      bottom: 130,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xE6111118),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2a2a3e), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            // Chat header
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF2a2a3e), width: 1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: Color(0xFF4facfe), size: 18),
                  const SizedBox(width: 8),
                  const Text('Chat',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleChat,
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Color(0xFFa0a0b2)),
                  ),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.waving_hand,
                        color: const Color(0xFF4facfe).withOpacity(0.5),
                        size: 36),
                    const SizedBox(height: 8),
                    const Text('Say hello to your partner!',
                        style: TextStyle(
                            color: Color(0xFF7c7c8a), fontSize: 13)),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // Input bar
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    // System message
    if (msg.text.startsWith('🔔')) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a3e),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(msg.text,
              style: const TextStyle(
                  color: Color(0xFFa0a0b2), fontSize: 11)),
        ),
      );
    }

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.62),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: msg.isMe
              ? const LinearGradient(
              colors: [Color(0xFF4facfe), Color(0xFF00f2fe)])
              : null,
          color: msg.isMe ? null : const Color(0xFF2a2a3e),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 16),
          ),
          boxShadow: msg.isMe
              ? [
            BoxShadow(
              color: const Color(0xFF4facfe).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: msg.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isMe ? Colors.white : const Color(0xFFe0e0f0),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: msg.isMe
                    ? Colors.white.withOpacity(0.6)
                    : const Color(0xFF7c7c8a),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border:
        Border(top: BorderSide(color: Color(0xFF2a2a3e), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF3a3a4e), width: 1),
              ),
              child: TextField(
                controller: _chatController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF7c7c8a)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
                enabled: _callConnected,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _callConnected
                    ? const LinearGradient(
                    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)])
                    : null,
                color: _callConnected ? null : const Color(0xFF2a2a3e),
                shape: BoxShape.circle,
                boxShadow: _callConnected
                    ? [
                  BoxShadow(
                    color: const Color(0xFF4facfe).withOpacity(0.4),
                    blurRadius: 10,
                  )
                ]
                    : null,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Controls ──
  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _localMuted ? Icons.mic_off : Icons.mic,
                label: _localMuted ? 'Unmute' : 'Mute',
                color:
                _localMuted ? Colors.red : const Color(0xFF2a2a3e),
                onTap: _toggleMute,
              ),

              // Chat button with unread badge
              GestureDetector(
                onTap: _toggleChat,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _chatOpen
                                ? const Color(0xFF4facfe)
                                : const Color(0xFF2a2a3e),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white24, width: 1),
                          ),
                          child: const Icon(Icons.chat_bubble_outline,
                              color: Colors.white, size: 24),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$_unreadCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_chatOpen ? 'Close' : 'Chat',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),

              // End call (big red)
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFf5576c), Color(0xFFf093fb)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFf5576c).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call_end,
                      color: Colors.white, size: 32),
                ),
              ),

              _buildControlButton(
                icon: _localVideoOff
                    ? Icons.videocam_off
                    : Icons.videocam,
                label: _localVideoOff ? 'Show Cam' : 'Hide Cam',
                color: _localVideoOff
                    ? Colors.red
                    : const Color(0xFF2a2a3e),
                onTap: _toggleVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Searching Overlay ──
  Widget _buildSearchingOverlay() {
    return Container(
      color: const Color(0xCC0a0a0f),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4facfe).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sign_language,
                      size: 64, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Finding a Partner',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Text(
                'Scanning room $_currentRoom of $_maxRoomsToTry...',
                style: const TextStyle(
                    color: Color(0xFF4facfe), fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Private room • Video + Chat included\nNo 3rd person can join your call',
              textAlign: TextAlign.center,
              style:
              TextStyle(color: Color(0xFFa0a0b2), fontSize: 13),
            ),
            const SizedBox(height: 40),
            _buildLoadingDots(),
            const SizedBox(height: 60),
            GestureDetector(
              onTap: _endCall,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a2e),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: const Color(0xFFf5576c), width: 1),
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: Color(0xFFf5576c),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
            (i) => AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final value = (_pulseController.value + i * 0.3) % 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  const Color(0xFF4facfe).withOpacity(0.3),
                  const Color(0xFF4facfe),
                  value,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}