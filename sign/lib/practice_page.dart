import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────────────────────────────────────
const String _kBaseUrl =
    'https://swaggeringly-superimproved-laney.ngrok-free.dev';

// ─────────────────────────────────────────────────────────────────────────────
// ALL 33 challenges — mirrors backend LABELS exactly
// 0-25 → A-Z   |  26 → Hello  27 → Done  28 → Thank You
// 29 → I Love you  30 → Sorry  31 → Please  32 → You are welcome
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _kChallenges = [
  {'sign': 'A',               'hint': 'Closed fist, thumb rests on the side',          'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'B',               'hint': 'Four fingers straight up, thumb tucked in',      'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'C',               'hint': 'Curved hand forming a C shape',                  'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'D',               'hint': 'Index finger up, other fingers touch thumb',     'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'E',               'hint': 'All fingers bent, thumb tucked under',           'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'F',               'hint': 'Index & thumb touch, three fingers point up',    'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'G',               'hint': 'Index & thumb point sideways horizontally',      'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'H',               'hint': 'Index & middle together point sideways',         'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'I',               'hint': 'Pinky finger up, all others closed',             'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'J',               'hint': 'Pinky up, draw a J shape in the air',            'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'K',               'hint': 'Index up, middle angled, thumb between them',    'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'L',               'hint': 'Index up, thumb out — makes an L shape',         'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'M',               'hint': 'Three fingers draped over tucked thumb',         'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'N',               'hint': 'Two fingers draped over tucked thumb',           'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'O',               'hint': 'All fingers curve to touch thumb — O shape',     'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'P',               'hint': 'K handshape rotated to point downward',          'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'Q',               'hint': 'G handshape rotated to point downward',          'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'R',               'hint': 'Index and middle fingers crossed',               'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'S',               'hint': 'Closed fist with thumb over the fingers',        'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'T',               'hint': 'Thumb tucked between index & middle finger',     'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'U',               'hint': 'Index & middle fingers up and held together',    'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'V',               'hint': 'Index & middle up in a V shape — peace sign',   'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'W',               'hint': 'Index, middle & ring spread upward',             'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'X',               'hint': 'Index finger hooked / bent like a hook',         'level': 'Intermediate', 'category': 'Alphabet'},
  {'sign': 'Y',               'hint': 'Thumb & pinky out — hang loose / shaka',         'level': 'Beginner',     'category': 'Alphabet'},
  {'sign': 'Z',               'hint': 'Index finger draws a Z shape in the air',        'level': 'Advanced',     'category': 'Alphabet'},
  {'sign': 'Hello',           'hint': 'Flat hand salute from forehead, move outward',   'level': 'Beginner',     'category': 'Phrase'},
  {'sign': 'Done',            'hint': 'Both hands face up, then flip to face down',     'level': 'Intermediate', 'category': 'Phrase'},
  {'sign': 'Thank You',       'hint': 'Flat hand from chin, extend forward toward person', 'level': 'Beginner',  'category': 'Phrase'},
  {'sign': 'I Love you',      'hint': 'Pinky, index finger & thumb all extended out',   'level': 'Beginner',     'category': 'Phrase'},
  {'sign': 'Sorry',           'hint': 'Closed fist circles on the chest',               'level': 'Intermediate', 'category': 'Phrase'},
  {'sign': 'Please',          'hint': 'Flat open hand circles on the chest',            'level': 'Intermediate', 'category': 'Phrase'},
  {'sign': 'You are welcome', 'hint': 'Flat hand sweeps from chest outward gracefully', 'level': 'Advanced',     'category': 'Phrase'},
];

// ─────────────────────────────────────────────────────────────────────────────
// Colour helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _levelColor(String level) {
  switch (level) {
    case 'Beginner':     return const Color(0xFF43e97b);
    case 'Intermediate': return const Color(0xFFf9ca24);
    default:             return const Color(0xFFfa709a);
  }
}

Color _categoryColor(String cat) =>
    cat == 'Alphabet' ? const Color(0xFF7c6bf8) : const Color(0xFF00c9ff);

// ─────────────────────────────────────────────────────────────────────────────
class PracticePage extends StatefulWidget {
  const PracticePage({Key? key}) : super(key: key);
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with TickerProviderStateMixin {

  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady  = false;
  bool _isFrontCam   = true;
  bool _streaming    = false;

  // ── Frame sending ───────────────────────────────────────────────────────────
  Timer? _frameTimer;
  bool   _processingFrame = false;
  static const int _fpsCap = 5;

  // ── Socket.IO ───────────────────────────────────────────────────────────────
  IO.Socket? _socket;
  bool _socketConnected = false;

  // ── Server ──────────────────────────────────────────────────────────────────
  bool   _serverReachable = false;
  String _serverStatus    = 'Checking…';

  // ── Prediction ──────────────────────────────────────────────────────────────
  String     _predictedChar  = '—';
  double     _confidence     = 0.0;
  Uint8List? _annotatedFrame;

  // ── Filter ──────────────────────────────────────────────────────────────────
  String _filterCategory = 'All';
  String _filterLevel    = 'All';

  List<Map<String, dynamic>> get _filtered {
    return _kChallenges.where((c) {
      final catOk = _filterCategory == 'All' || c['category'] == _filterCategory;
      final lvlOk = _filterLevel    == 'All' || c['level']    == _filterLevel;
      return catOk && lvlOk;
    }).toList();
  }

  // ── Practice ────────────────────────────────────────────────────────────────
  int    _challengeIndex     = 0;
  int    _score              = 0;
  int    _streak             = 0;
  bool   _challengeCompleted = false;
  bool   _onCooldown         = false;
  Timer? _cooldownTimer;
  List<Map<String, dynamic>> _completedChallenges = [];

  // ── Free sign ───────────────────────────────────────────────────────────────
  String _sentence  = '';
  String _lastAdded = '';

  // ── Tab ─────────────────────────────────────────────────────────────────────
  int _tabIndex = 0;

  // ── Animations ──────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _successCtrl;
  late Animation<double>   _successAnim;
  late AnimationController _cardCtrl;
  late Animation<double>   _cardAnim;

  Map<String, dynamic> get _currentChallenge {
    final list = _filtered;
    if (list.isEmpty) return _kChallenges.first;
    return list[_challengeIndex.clamp(0, list.length - 1)];
  }

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successAnim =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _cardAnim =
        CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic);

    _checkServer();
    _connectSocket();
    _initCamera();
  }

  // ── Server ───────────────────────────────────────────────────────────────────
  Future<void> _checkServer() async {
    try {
      final res = await http.get(
        Uri.parse('$_kBaseUrl/health'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _serverReachable = body['model_loaded'] == true;
          _serverStatus    = _serverReachable
              ? 'AI Ready · ${body['labels'] ?? 0} signs'
              : 'Model not loaded';
        });
      }
    } catch (_) {
      setState(() => _serverStatus = 'Cannot reach server');
    }
  }

  // ── Socket ───────────────────────────────────────────────────────────────────
  void _connectSocket() {
    _socket = IO.io(
      _kBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket!.onConnect((_) => setState(() => _socketConnected = true));
    _socket!.onDisconnect((_) => setState(() => _socketConnected = false));

    _socket!.on('prediction', (data) {
      final char = data['text']?.toString() ?? '';
      final conf = (data['confidence'] is double)
          ? data['confidence'] as double
          : double.tryParse(data['confidence'].toString()) ?? 0.0;

      setState(() { _predictedChar = char; _confidence = conf; });
      _cardCtrl.forward(from: 0);

      // Practice tab: check match
      if (_tabIndex == 0 && !_challengeCompleted && !_onCooldown) {
        final target = _currentChallenge['sign'].toString().toUpperCase();
        if (char.toUpperCase() == target && conf > 0.75) {
          _onChallengeSuccess();
        }
      }

      // Free sign tab: build sentence
      if (_tabIndex == 1 && char != _lastAdded && !_onCooldown && conf > 0.75) {
        setState(() {
          _sentence  += char.length > 1 ? ' $char ' : char;
          _lastAdded  = char;
        });
        _onCooldown = true;
        _cooldownTimer =
            Timer(const Duration(milliseconds: 1500), () => _onCooldown = false);
      }
    });

    _socket!.on('annotated_frame', (data) {
      try {
        final b64 = data['frame']?.toString() ?? '';
        if (b64.isEmpty) return;
        setState(() => _annotatedFrame = base64Decode(b64));
      } catch (_) {}
    });

    _socket!.connect();
  }

  // ── Camera ───────────────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _startCamera(_isFrontCam ? _frontCam() : _cameras.first);
  }

  CameraDescription _frontCam() => _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first);

  CameraDescription _backCam() => _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first);

  Future<void> _startCamera(CameraDescription cam) async {
    await _camCtrl?.dispose();
    _camCtrl = CameraController(cam, ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await _camCtrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) { debugPrint('[CAM] $e'); }
  }

  Future<void> _flipCamera() async {
    setState(() { _isFrontCam = !_isFrontCam; _cameraReady = false; });
    await _startCamera(_isFrontCam ? _frontCam() : _backCam());
  }

  // ── Streaming ────────────────────────────────────────────────────────────────
  void _startStream() {
    if (!_cameraReady || !_socketConnected) return;
    setState(() => _streaming = true);
    _frameTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _fpsCap).round()),
          (_) => _sendFrame(),
    );
  }

  void _stopStream() {
    _frameTimer?.cancel();
    _frameTimer = null;
    setState(() => _streaming = false);
  }

  Future<void> _sendFrame() async {
    if (_processingFrame) return;
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    _processingFrame = true;
    try {
      final XFile file = await _camCtrl!.takePicture();
      final bytes      = await file.readAsBytes();
      _socket?.emit('phone_frame', {'frame': base64Encode(bytes)});
    } catch (e) { debugPrint('[FRAME] $e'); }
    finally { _processingFrame = false; }
  }

  // ── Challenge logic ──────────────────────────────────────────────────────────
  void _onChallengeSuccess() {
    setState(() {
      _challengeCompleted = true;
      _score += 10 + (_streak * 2);
      _streak++;
      _completedChallenges.add({..._currentChallenge, 'completedAt': DateTime.now()});
    });
    _successCtrl.forward(from: 0);
  }

  void _nextChallenge() {
    final list = _filtered;
    setState(() {
      _challengeIndex     = (_challengeIndex + 1) % (list.isEmpty ? 1 : list.length);
      _challengeCompleted = false;
      _predictedChar      = '—';
      _confidence         = 0.0;
    });
    _successCtrl.reset();
  }

  void _skipChallenge() {
    final list = _filtered;
    setState(() {
      _streak             = 0;
      _challengeIndex     = (_challengeIndex + 1) % (list.isEmpty ? 1 : list.length);
      _challengeCompleted = false;
      _predictedChar      = '—';
      _confidence         = 0.0;
    });
  }

  void _jumpToChallenge(int globalIndex) {
    // globalIndex is index in _kChallenges
    // find the same sign in _filtered
    final sign = _kChallenges[globalIndex]['sign'];
    final filtIdx = _filtered.indexWhere((c) => c['sign'] == sign);
    setState(() {
      if (filtIdx >= 0) _challengeIndex = filtIdx;
      _challengeCompleted = false;
      _predictedChar      = '—';
      _confidence         = 0.0;
      _tabIndex           = 0;
    });
    _successCtrl.reset();
  }

  // ── Colour helper ─────────────────────────────────────────────────────────────
  Color get _confidenceColor => _confidence > 0.8
      ? const Color(0xFF43e97b)
      : _confidence > 0.5
      ? const Color(0xFFf9ca24)
      : Colors.redAccent;

  @override
  void dispose() {
    _stopStream();
    _camCtrl?.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    _cardCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080f),
      appBar: _buildAppBar(),
      body: Column(children: [
        _buildConnectionBanner(),
        _buildTabBar(),
        Expanded(child: IndexedStack(
          index: _tabIndex,
          children: [
            _buildPracticeTab(),
            _buildFreeSignTab(),
            _buildProgressTab(),
          ],
        )),
      ]),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
    backgroundColor: const Color(0xFF0d0e1a),
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF7c6bf8)),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7c6bf8), Color(0xFFa78bfa)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('PRACTICE',
            style: TextStyle(color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      const SizedBox(width: 10),
      const Text('Sign Lab',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    ]),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1b2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7c6bf8).withOpacity(0.5)),
        ),
        child: Row(children: [
          const Text('⭐', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text('$_score',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
      IconButton(
        icon: const Icon(Icons.flip_camera_android_rounded, color: Color(0xFF7c6bf8)),
        onPressed: _flipCamera,
      ),
    ],
  );

  // ── Connection banner ─────────────────────────────────────────────────────────
  Widget _buildConnectionBanner() {
    final ok = _serverReachable && _socketConnected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: ok ? 0 : 36,
      child: Container(
        color: const Color(0xFF1a0a00),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(_serverStatus,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
          GestureDetector(
            onTap: _checkServer,
            child: const Text('Retry',
                style: TextStyle(color: Colors.orange, fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      {'icon': Icons.sports_esports_rounded, 'label': 'Practice'},
      {'icon': Icons.edit_rounded,            'label': 'Free Sign'},
      {'icon': Icons.bar_chart_rounded,       'label': 'Progress'},
    ];
    return Container(
      color: const Color(0xFF0d0e1a),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: List.generate(tabs.length, (i) {
        final sel = _tabIndex == i;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _tabIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: sel ? const LinearGradient(
                  colors: [Color(0xFF7c6bf8), Color(0xFF5b4fcf)]) : null,
              color: sel ? null : const Color(0xFF1a1b2e),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? Colors.transparent : const Color(0xFF2a2b3e)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(tabs[i]['icon'] as IconData, size: 16,
                  color: sel ? Colors.white : const Color(0xFF7c7c9a)),
              const SizedBox(width: 6),
              Text(tabs[i]['label'] as String,
                  style: TextStyle(
                      color: sel ? Colors.white : const Color(0xFF7c7c9a),
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        ));
      })),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 0 — PRACTICE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPracticeTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildFilterRow(),
      const SizedBox(height: 12),
      _buildChallengeCard(),
      const SizedBox(height: 16),
      _buildCameraView(),
      const SizedBox(height: 16),
      _buildStreamButton(),
      const SizedBox(height: 16),
      _buildDetectionFeedback(),
      const SizedBox(height: 24),
    ]),
  );

  // ── Filter row ────────────────────────────────────────────────────────────────
  Widget _buildFilterRow() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Category
    Row(children: [
      _chip('All',      _filterCategory, (v) => _setFilter(cat: v), const Color(0xFF7c7c9a)),
      const SizedBox(width: 8),
      _chip('Alphabet', _filterCategory, (v) => _setFilter(cat: v), const Color(0xFF7c6bf8)),
      const SizedBox(width: 8),
      _chip('Phrase',   _filterCategory, (v) => _setFilter(cat: v), const Color(0xFF00c9ff)),
    ]),
    const SizedBox(height: 8),
    // Level
    SingleChildScrollView(scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('All',          _filterLevel, (v) => _setFilter(lvl: v), const Color(0xFF7c7c9a)),
        const SizedBox(width: 8),
        _chip('Beginner',     _filterLevel, (v) => _setFilter(lvl: v), const Color(0xFF43e97b)),
        const SizedBox(width: 8),
        _chip('Intermediate', _filterLevel, (v) => _setFilter(lvl: v), const Color(0xFFf9ca24)),
        const SizedBox(width: 8),
        _chip('Advanced',     _filterLevel, (v) => _setFilter(lvl: v), const Color(0xFFfa709a)),
      ]),
    ),
    const SizedBox(height: 6),
    Text('${_filtered.length} of ${_kChallenges.length} signs shown',
        style: const TextStyle(color: Color(0xFF4a4b6e), fontSize: 11)),
  ]);

  void _setFilter({String? cat, String? lvl}) {
    setState(() {
      if (cat != null) _filterCategory = cat;
      if (lvl != null) _filterLevel    = lvl;
      _challengeIndex = 0;
      _challengeCompleted = false;
    });
  }

  Widget _chip(String label, String current, ValueChanged<String> onTap, Color color) {
    final sel = current == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.18) : const Color(0xFF1a1b2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : const Color(0xFF2a2b3e)),
        ),
        child: Text(label,
            style: TextStyle(color: sel ? color : const Color(0xFF7c7c9a),
                fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  // ── Challenge card ────────────────────────────────────────────────────────────
  Widget _buildChallengeCard() {
    final challenge = _currentChallenge;
    final lColor    = _levelColor(challenge['level']);
    final catColor  = _categoryColor(challenge['category']);
    final list      = _filtered;
    final idx       = _challengeIndex.clamp(0, list.isEmpty ? 0 : list.length - 1);

    return AnimatedBuilder(
      animation: _successAnim,
      builder: (_, child) => Transform.scale(
        scale: _challengeCompleted ? 0.97 + _successAnim.value * 0.03 : 1.0,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: _challengeCompleted
                ? [const Color(0xFF0a2a1a), const Color(0xFF0a1f2e)]
                : [const Color(0xFF12132a), const Color(0xFF1a1b35)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _challengeCompleted
                ? const Color(0xFF43e97b).withOpacity(0.6)
                : const Color(0xFF7c6bf8).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [BoxShadow(
            color: (_challengeCompleted
                ? const Color(0xFF43e97b)
                : const Color(0xFF7c6bf8)).withOpacity(0.12),
            blurRadius: 24, offset: const Offset(0, 8),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Wrap(spacing: 6, runSpacing: 4, children: [
              _badge(challenge['category'], catColor),
              _badge(challenge['level'], lColor),
              Text('${idx + 1} / ${list.length}',
                  style: const TextStyle(color: Color(0xFF7c7c9a), fontSize: 12)),
            ]),
            if (_challengeCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF43e97b).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('✓ NAILED IT!',
                    style: TextStyle(color: Color(0xFF43e97b), fontSize: 11,
                        fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
          ]),
          const SizedBox(height: 16),

          // Sign target
          Row(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: _challengeCompleted
                    ? const LinearGradient(colors: [Color(0xFF43e97b), Color(0xFF38f9d7)])
                    : LinearGradient(colors: [catColor, catColor.withOpacity(0.6)]),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                challenge['sign'].toString().length > 2
                    ? challenge['sign'].toString().substring(0, 2)
                    : challenge['sign'],
                style: const TextStyle(color: Colors.white, fontSize: 30,
                    fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SIGN THIS',
                  style: TextStyle(color: Color(0xFF7c7c9a), fontSize: 10,
                      letterSpacing: 2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(challenge['sign'],
                  style: const TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: Color(0xFFf9ca24), size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(challenge['hint'],
                    style: const TextStyle(color: Color(0xFFa0a0b8), fontSize: 12))),
              ]),
            ])),
          ]),
          const SizedBox(height: 14),

          if (_challengeCompleted)
            _actionButton(
              label: 'Next Challenge  →',
              gradient: const LinearGradient(
                  colors: [Color(0xFF43e97b), Color(0xFF38f9d7)]),
              onTap: _nextChallenge,
            )
          else
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: list.isEmpty ? 0 : (idx + 1) / list.length,
                  minHeight: 5,
                  backgroundColor: const Color(0xFF2a2b3e),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7c6bf8)),
                ),
              )),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _skipChallenge,
                child: const Text('Skip →',
                    style: TextStyle(color: Color(0xFF7c7c9a), fontSize: 12)),
              ),
            ]),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  // ── Camera view ───────────────────────────────────────────────────────────────
  Widget _buildCameraView() => Container(
    height: 280,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: _streaming
            ? const Color(0xFF7c6bf8).withOpacity(0.6)
            : const Color(0xFF2a2b3e),
        width: 2,
      ),
      boxShadow: _streaming
          ? [BoxShadow(color: const Color(0xFF7c6bf8).withOpacity(0.2), blurRadius: 24)]
          : [],
    ),
    clipBehavior: Clip.hardEdge,
    child: Stack(fit: StackFit.expand, children: [
      if (_annotatedFrame != null && _streaming)
        Image.memory(_annotatedFrame!, fit: BoxFit.cover, gaplessPlayback: true)
      else if (_cameraReady && _camCtrl != null)
        CameraPreview(_camCtrl!)
      else
        Container(color: const Color(0xFF0d0e1a),
            child: const Center(child: CircularProgressIndicator(color: Color(0xFF7c6bf8)))),

      ..._buildCornerGuides(),

      if (_streaming)
        Positioned(top: 12, left: 12,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(opacity: _pulseAnim.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 5),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ]),
              ),
            ),
          ),
        ),

      if (_streak > 1)
        Positioned(top: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFf9ca24).withOpacity(0.9),
                borderRadius: BorderRadius.circular(8)),
            child: Text('🔥 ×$_streak',
                style: const TextStyle(color: Color(0xFF1a1200),
                    fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),

      Positioned(bottom: 12, right: 12,
        child: AnimatedBuilder(
          animation: _cardAnim,
          builder: (_, child) =>
              Transform.scale(scale: 0.9 + _cardAnim.value * 0.1, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _confidenceColor.withOpacity(0.6), width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _predictedChar.length > 3
                    ? _predictedChar.substring(0, 3)
                    : _predictedChar,
                style: TextStyle(color: _confidenceColor, fontSize: 26,
                    fontWeight: FontWeight.w900),
              ),
              Text('${(_confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
          ),
        ),
      ),
    ]),
  );

  List<Widget> _buildCornerGuides() {
    const c = Color(0xFF7c6bf8);
    const s = 24.0;
    const t = 3.0;
    return [
      Positioned(top: 8,    left: 8,  child: _corner(c, s, t, top: true,  left: true)),
      Positioned(top: 8,    right: 8, child: _corner(c, s, t, top: true,  left: false)),
      Positioned(bottom: 8, left: 8,  child: _corner(c, s, t, top: false, left: true)),
      Positioned(bottom: 8, right: 8, child: _corner(c, s, t, top: false, left: false)),
    ];
  }

  Widget _corner(Color c, double sz, double t, {required bool top, required bool left}) =>
      SizedBox(width: sz, height: sz,
          child: CustomPaint(painter: _CornerPainter(c, t, top: top, left: left)));

  // ── Stream button ─────────────────────────────────────────────────────────────
  Widget _buildStreamButton() {
    final canStart = _cameraReady && _socketConnected && !_streaming;
    return GestureDetector(
      onTap: _streaming ? _stopStream : (canStart ? _startStream : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _streaming
              ? const LinearGradient(colors: [Color(0xFFfa709a), Color(0xFFfee140)])
              : canStart
              ? const LinearGradient(colors: [Color(0xFF7c6bf8), Color(0xFFa78bfa)])
              : null,
          color: canStart || _streaming ? null : const Color(0xFF1a1b2e),
          borderRadius: BorderRadius.circular(16),
          border: canStart || _streaming ? null : Border.all(color: const Color(0xFF2a2b3e)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _streaming ? Icons.stop_circle_rounded : Icons.play_circle_filled_rounded,
            color: canStart || _streaming ? Colors.white : const Color(0xFF4a4b5e),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            _streaming ? 'Stop Camera' : 'Start Camera',
            style: TextStyle(
              color: canStart || _streaming ? Colors.white : const Color(0xFF4a4b5e),
              fontWeight: FontWeight.w700, fontSize: 16,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Detection feedback ────────────────────────────────────────────────────────
  Widget _buildDetectionFeedback() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0d0e1a),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF1e1f35)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('DETECTION',
          style: TextStyle(color: Color(0xFF4a4b6e), fontSize: 10,
              letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _pill('Detecting',
            _predictedChar == '—' ? '—' : _predictedChar, const Color(0xFF7c6bf8))),
        const SizedBox(width: 10),
        Expanded(child: _pill('Confidence',
            '${(_confidence * 100).toStringAsFixed(1)}%', _confidenceColor)),
        const SizedBox(width: 10),
        Expanded(child: _pill('Score', '$_score pts', const Color(0xFFf9ca24))),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: _confidence.clamp(0.0, 1.0), minHeight: 6,
          backgroundColor: const Color(0xFF1e1f35),
          valueColor: AlwaysStoppedAnimation(_confidenceColor),
        ),
      ),
    ]),
  );

  Widget _pill(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 15,
          fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Color(0xFF5a5b7a), fontSize: 10),
          overflow: TextOverflow.ellipsis),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1 — FREE SIGN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFreeSignTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildCameraView(),
      const SizedBox(height: 16),
      _buildStreamButton(),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0d0e1a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1e1f35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('FREE SIGNING',
                style: TextStyle(color: Color(0xFF4a4b6e), fontSize: 10,
                    letterSpacing: 2, fontWeight: FontWeight.w700)),
            Row(children: [
              _smallBtn(Icons.backspace_outlined, const Color(0xFFf9ca24), () {
                if (_sentence.isNotEmpty)
                  setState(() => _sentence = _sentence.substring(0, _sentence.length - 1));
              }),
              const SizedBox(width: 8),
              _smallBtn(Icons.clear_rounded, Colors.redAccent,
                      () => setState(() { _sentence = ''; _lastAdded = ''; })),
            ]),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF07080f),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF7c6bf8).withOpacity(0.2)),
            ),
            child: Text(
              _sentence.isEmpty ? 'Start signing to build a sentence…' : _sentence,
              style: TextStyle(
                color: _sentence.isEmpty ? const Color(0xFF3a3b5e) : Colors.white,
                fontSize: 22, fontWeight: FontWeight.w600, height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Signs added when confidence > 75%  •  1.5 s cooldown',
              style: TextStyle(color: Color(0xFF3a3b5e), fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 24),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 — PROGRESS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProgressTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildScoreSummary(),
      const SizedBox(height: 16),
      _buildCategoryBreakdown(),
      const SizedBox(height: 16),
      _buildAllSignsGrid(),
      const SizedBox(height: 24),
    ]),
  );

  Widget _buildScoreSummary() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF12132a), Color(0xFF1e1040)]),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF7c6bf8).withOpacity(0.3)),
    ),
    child: Column(children: [
      const Text('SESSION STATS', style: TextStyle(color: Color(0xFF4a4b6e),
          fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statBig('$_score', 'SCORE', const Color(0xFF7c6bf8)),
        _statBig('$_streak', 'STREAK', const Color(0xFFf9ca24)),
        _statBig('${_completedChallenges.length}', 'DONE', const Color(0xFF43e97b)),
        _statBig('${_kChallenges.length - _completedChallenges.length}',
            'LEFT', const Color(0xFFfa709a)),
      ]),
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: _kChallenges.isEmpty
              ? 0 : _completedChallenges.length / _kChallenges.length,
          minHeight: 8,
          backgroundColor: const Color(0xFF2a2b3e),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF43e97b)),
        ),
      ),
      const SizedBox(height: 6),
      Text('${_completedChallenges.length} / ${_kChallenges.length} signs completed',
          style: const TextStyle(color: Color(0xFF4a4b6e), fontSize: 11)),
    ]),
  );

  Widget _statBig(String val, String label, Color color) => Column(children: [
    Text(val, style: TextStyle(color: color, fontSize: 28,
        fontWeight: FontWeight.w900, height: 1)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Color(0xFF4a4b6e),
        fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
  ]);

  Widget _buildCategoryBreakdown() {
    final ad = _completedChallenges.where((c) => c['category'] == 'Alphabet').length;
    final at = _kChallenges.where((c) => c['category'] == 'Alphabet').length;
    final pd = _completedChallenges.where((c) => c['category'] == 'Phrase').length;
    final pt = _kChallenges.where((c) => c['category'] == 'Phrase').length;
    return Row(children: [
      Expanded(child: _catCard('Alphabet', ad, at, const Color(0xFF7c6bf8))),
      const SizedBox(width: 12),
      Expanded(child: _catCard('Phrases', pd, pt, const Color(0xFF00c9ff))),
    ]);
  }

  Widget _catCard(String title, int done, int total, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0d0e1a),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('$done / $total', style: const TextStyle(color: Colors.white,
          fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : done / total, minHeight: 5,
          backgroundColor: const Color(0xFF2a2b3e),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]),
  );

  // ── Full 33-sign grid ─────────────────────────────────────────────────────────
  Widget _buildAllSignsGrid() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0d0e1a),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF1e1f35)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('ALL 33 SIGNS', style: TextStyle(color: Color(0xFF4a4b6e),
            fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const Text('Tap to jump', style: TextStyle(color: Color(0xFF3a3b5e), fontSize: 11)),
      ]),
      const SizedBox(height: 14),

      // A–Z grid
      const Text('A – Z  (26 letters)', style: TextStyle(color: Color(0xFF7c6bf8),
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8,
        children: List.generate(26, (i) {
          final c    = _kChallenges[i];
          final done = _completedChallenges.any((x) => x['sign'] == c['sign']);
          final isCur = _challengeIndex == _filtered.indexWhere((f) => f['sign'] == c['sign'])
              && _tabIndex == 0;
          return GestureDetector(
            onTap: () => _jumpToChallenge(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFF43e97b).withOpacity(0.15)
                    : isCur
                    ? const Color(0xFF7c6bf8).withOpacity(0.2)
                    : const Color(0xFF1a1b2e),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: done
                      ? const Color(0xFF43e97b).withOpacity(0.5)
                      : isCur
                      ? const Color(0xFF7c6bf8)
                      : const Color(0xFF2a2b3e),
                ),
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check_rounded, color: Color(0xFF43e97b), size: 18)
                  : Text(c['sign'], style: TextStyle(
                  color: isCur ? const Color(0xFF7c6bf8) : Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          );
        }),
      ),
      const SizedBox(height: 20),

      // Phrases list
      const Text('PHRASES  (7 signs)', style: TextStyle(color: Color(0xFF00c9ff),
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 10),
      ...List.generate(7, (i) {
        final idx  = 26 + i;
        final c    = _kChallenges[idx];
        final done = _completedChallenges.any((x) => x['sign'] == c['sign']);
        final isCur = _challengeIndex == _filtered.indexWhere((f) => f['sign'] == c['sign'])
            && _tabIndex == 0;
        final lc = _levelColor(c['level']);
        return GestureDetector(
          onTap: () => _jumpToChallenge(idx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isCur
                  ? const Color(0xFF00c9ff).withOpacity(0.06)
                  : const Color(0xFF12131f),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCur
                    ? const Color(0xFF00c9ff).withOpacity(0.4)
                    : done
                    ? const Color(0xFF43e97b).withOpacity(0.2)
                    : const Color(0xFF1e1f35),
              ),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF43e97b).withOpacity(0.15)
                      : const Color(0xFF1a1b2e),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: done
                    ? const Icon(Icons.check_rounded, color: Color(0xFF43e97b), size: 20)
                    : Text(c['sign'].toString().substring(0, 1),
                    style: TextStyle(
                        color: isCur ? const Color(0xFF00c9ff) : const Color(0xFF4a4b6e),
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['sign'], style: TextStyle(
                    color: done ? const Color(0xFF43e97b) : Colors.white,
                    fontWeight: FontWeight.w700)),
                Text(c['hint'],
                    style: const TextStyle(color: Color(0xFF4a4b6e), fontSize: 11)),
              ])),
              _badge(c['level'].toString().substring(0, 3), lc),
            ]),
          ),
        );
      }),
    ]),
  );

  // ── Shared helpers ────────────────────────────────────────────────────────────
  Widget _actionButton({required String label, required Gradient gradient,
    required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(gradient: gradient,
              borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
        ),
      );

  Widget _smallBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 16),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Corner guide painter
// ─────────────────────────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top, left;
  _CornerPainter(this.color, this.thickness, {required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color ..strokeWidth = thickness
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;
    final x  = left ? 0.0 : size.width;
    final y  = top  ? 0.0 : size.height;
    final dx = left ? size.width  : -size.width;
    final dy = top  ? size.height : -size.height;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), p);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}