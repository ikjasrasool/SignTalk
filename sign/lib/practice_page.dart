import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String _hfApiUrl = 'https://ikjas-asl.hf.space/predict';

const List<String> _alphabet = [
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
];

const List<String> _phrases = [
  'Hello', 'Done', 'Thank You', 'I Love you',
  'Sorry', 'Please', 'You are welcome.'
];

const Map<String, String> _phraseEmoji = {
  'Hello': '👋',
  'Done': '✅',
  'Thank You': '🙏',
  'I Love you': '❤️',
  'Sorry': '😔',
  'Please': '🤲',
  'You are welcome.': '😊',
};

class PracticePage extends StatefulWidget {
  const PracticePage({Key? key}) : super(key: key);

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _cameraReady = false;

  String _detectedSign = '';
  double _confidence = 0.0;
  bool _isDetecting = false;
  String _errorMsg = '';
  Timer? _autoTimer;

  String _targetLetter = 'A';
  int _targetIndex = 0;
  int _score = 0;
  int _streak = 0;
  bool _showSuccess = false;
  List<String> _history = [];

  // 0 = Free Practice, 1 = A-Z Challenge, 2 = Phrases
  int _selectedMode = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _successCtrl;
  late Animation<double> _successAnim;

  List<String> get _currentList =>
      _selectedMode == 2 ? _phrases : _alphabet;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successAnim =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front, ResolutionPreset.max, enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _captureAndClassify() async {
    if (_isDetecting || _cameraController == null || !_cameraReady) return;
    setState(() { _isDetecting = true; _errorMsg = ''; });

    try {
      final xFile = await _cameraController!.takePicture();
      final request = http.MultipartRequest('POST', Uri.parse(_hfApiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', xFile.path),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final predicted = (data['prediction'] as String? ?? '');
          final conf = (data['confidence'] as num?)?.toDouble() ?? 0.0;
          setState(() {
            _detectedSign = predicted;
            _confidence = conf * 100;
            _history = [predicted, ..._history].take(5).toList();
            _errorMsg = '';
          });
          if (_selectedMode == 1) _checkChallenge(predicted.toUpperCase());
          if (_selectedMode == 2) _checkChallenge(predicted);
        } else {
          setState(() {
            _errorMsg = data['error'] as String? ?? 'Detection failed';
            _detectedSign = '';
            _confidence = 0.0;
          });
        }
      } else {
        setState(() => _errorMsg = 'Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      setState(() => _errorMsg = 'Request timed out');
    } catch (e) {
      setState(() => _errorMsg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  void _checkChallenge(String detected) {
    if (detected == _targetLetter) {
      setState(() { _score++; _streak++; _showSuccess = true; });
      _successCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() {
          _showSuccess = false;
          _targetIndex = (_targetIndex + 1) % _currentList.length;
          _targetLetter = _currentList[_targetIndex];
        });
      });
    } else {
      setState(() => _streak = 0);
    }
  }

  void _toggleAutoDetect() {
    if (_autoTimer != null) {
      _autoTimer!.cancel();
      _autoTimer = null;
    } else {
      _autoTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => _captureAndClassify(),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _cameraController?.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildModeTabs(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    if (_selectedMode == 1) _buildChallengeHeader(),
                    if (_selectedMode == 2) _buildPhrasesHeader(),
                    _buildCameraCard(),
                    const SizedBox(height: 16),
                    _buildResultCard(),
                    const SizedBox(height: 16),
                    _buildControlRow(),
                    const SizedBox(height: 16),
                    if (_errorMsg.isNotEmpty) _buildErrorBanner(),
                    _buildHistoryRow(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Practice',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: Colors.white, letterSpacing: 0.5)),
          ),
          if (_selectedMode == 1 || _selectedMode == 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFfa709a), Color(0xFFfee140)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('🏆 $_score',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
        ],
      ),
    );
  }

  Widget _buildModeTabs() {
    final tabs = ['Free', 'A–Z', 'Phrases'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2a2a3e)),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final selected = _selectedMode == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedMode = i;
                  _detectedSign = '';
                  _confidence = 0;
                  _errorMsg = '';
                  _targetIndex = 0;
                  _score = 0;
                  _streak = 0;
                  _targetLetter = i == 2 ? _phrases[0] : _alphabet[0];
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                        colors: [Color(0xFFfa709a), Color(0xFFfee140)])
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(tabs[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF7c7c8a),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── A-Z Challenge header ─────────────────────
  Widget _buildChallengeHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _alphabet.length,
              itemBuilder: (_, i) {
                final done = i < _targetIndex;
                final current = i == _targetIndex;
                return Container(
                  width: 26, height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? const Color(0xFF43e97b)
                        : current ? const Color(0xFFfa709a)
                        : const Color(0xFF2a2a3e),
                    border: current ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: Center(
                    child: Text(_alphabet[i],
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold,
                            color: done || current ? Colors.white : const Color(0xFF7c7c8a))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statChip('🎯 Sign', _targetLetter, const Color(0xFFfa709a)),
              const SizedBox(width: 12),
              _statChip('🔥 Streak', '$_streak', const Color(0xFFfee140)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Phrases header ───────────────────────────
  Widget _buildPhrasesHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrollable phrase progress pills
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _phrases.length,
              itemBuilder: (_, i) {
                final done = i < _targetIndex;
                final current = i == _targetIndex;
                final emoji = _phraseEmoji[_phrases[i]] ?? '🤟';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: done ? const Color(0xFF43e97b)
                        : current ? const Color(0xFFfa709a)
                        : const Color(0xFF2a2a3e),
                    border: current ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: Center(
                    child: Text('$emoji ${_phrases[i]}',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold,
                            color: done || current ? Colors.white : const Color(0xFF7c7c8a))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Current phrase target card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFfa709a).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Text(_phraseEmoji[_targetLetter] ?? '🤟',
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Show this sign:',
                          style: TextStyle(color: Color(0xFF7c7c8a), fontSize: 11)),
                      Text(_targetLetter,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                _statChip('🔥', '$_streak', const Color(0xFFfee140)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCameraCard() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _autoTimer != null ? const Color(0xFFfa709a) : const Color(0xFF2a2a3e),
              width: 2,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: _cameraReady && _cameraController != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: CameraPreview(_cameraController!),
          )
              : Container(
            color: const Color(0xFF1a1a2e),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Color(0xFFfa709a)),
                SizedBox(height: 12),
                Text('Starting camera…',
                    style: TextStyle(color: Color(0xFF7c7c8a))),
              ]),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _CornerPainter())),
        ),
        if (_showSuccess)
          ScaleTransition(
            scale: _successAnim,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF43e97b).withOpacity(0.92),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
            ),
          ),
        if (_isDetecting)
          Positioned(
            top: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 10, height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfa709a))),
                SizedBox(width: 6),
                Text('Detecting', style: TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ),
          ),
        if (_autoTimer != null)
          Positioned(
            top: 16, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFfa709a).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('● AUTO',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMsg,
              style: const TextStyle(color: Colors.orange, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final hasResult = _detectedSign.isNotEmpty;
    final isCorrect = (_selectedMode == 1 || _selectedMode == 2) &&
        _detectedSign == _targetLetter;
    final isPhrase = hasResult && _detectedSign.length > 1;
    final displayIcon = isPhrase
        ? (_phraseEmoji[_detectedSign] ?? '🤟')
        : (hasResult ? _detectedSign : '?');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasResult
              ? (isCorrect ? const Color(0xFF43e97b) : const Color(0xFFfa709a))
              : const Color(0xFF2a2a3e),
          width: 1.5,
        ),
        boxShadow: hasResult
            ? [BoxShadow(
            color: (isCorrect ? const Color(0xFF43e97b) : const Color(0xFFfa709a))
                .withOpacity(0.15),
            blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: hasResult ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: hasResult
                    ? LinearGradient(colors: isCorrect
                    ? [const Color(0xFF43e97b), const Color(0xFF38f9d7)]
                    : [const Color(0xFFfa709a), const Color(0xFFfee140)])
                    : null,
                color: hasResult ? null : const Color(0xFF2a2a3e),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(displayIcon,
                    style: TextStyle(
                        fontSize: isPhrase ? 32 : 42,
                        fontWeight: FontWeight.bold,
                        color: hasResult ? Colors.white : const Color(0xFF7c7c8a))),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasResult ? 'Detected Sign' : 'No Detection Yet',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF7c7c8a))),
                const SizedBox(height: 4),
                Text(hasResult ? _detectedSign : '—',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                if (hasResult) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _confidence / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF2a2a3e),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isCorrect ? const Color(0xFF43e97b) : const Color(0xFFfa709a)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${_confidence.toStringAsFixed(1)}% confidence',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFa0a0b2))),
                ],
                if ((_selectedMode == 1 || _selectedMode == 2) && hasResult)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isCorrect ? '✅ Correct! Great job!'
                          : '❌ Try again — show "$_targetLetter"',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: isCorrect ? const Color(0xFF43e97b) : const Color(0xFFfee140)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _gradientButton(
            label: _isDetecting ? 'Detecting…' : 'Detect Now',
            icon: Icons.camera_alt_rounded,
            gradient: const LinearGradient(
                colors: [Color(0xFFfa709a), Color(0xFFfee140)]),
            onTap: _isDetecting ? null : _captureAndClassify,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _outlineButton(
            label: _autoTimer != null ? 'Stop Auto' : 'Auto',
            icon: _autoTimer != null ? Icons.stop_rounded : Icons.loop_rounded,
            active: _autoTimer != null,
            onTap: _toggleAutoDetect,
          ),
        ),
      ],
    );
  }

  Widget _gradientButton({
    required String label, required IconData icon,
    required Gradient gradient, VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: const Color(0xFFfa709a).withOpacity(0.3),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label, required IconData icon,
    required bool active, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFfa709a).withOpacity(0.15) : const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? const Color(0xFFfa709a) : const Color(0xFF2a2a3e)),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: active ? const Color(0xFFfa709a) : const Color(0xFF7c7c8a),
                size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: active ? const Color(0xFFfa709a) : const Color(0xFF7c7c8a),
                fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow() {
    if (_history.isEmpty) {
      return const Center(
        child: Text('Tap "Detect Now" or enable Auto to start',
            style: TextStyle(color: Color(0xFF7c7c8a), fontSize: 13)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Detections',
            style: TextStyle(
                color: Color(0xFF7c7c8a), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_history.length, (idx) {
            final item = _history[idx];
            final isPhrase = item.length > 1;
            final display = isPhrase ? (_phraseEmoji[item] ?? '🤟') : item;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Opacity(
                opacity: 1.0 - (idx * 0.18),
                child: Container(
                  width: isPhrase ? 52 : 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a2e),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2a2a3e)),
                  ),
                  child: Center(
                    child: Text(display,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: isPhrase ? 22 : 18,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFfa709a)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 24.0;

    canvas.drawLine(Offset(r, 0), Offset(r + len, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, r + len), paint);
    canvas.drawLine(Offset(size.width - r, 0), Offset(size.width - r - len, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawLine(Offset(0, size.height - r), Offset(0, size.height - r - len), paint);
    canvas.drawLine(Offset(size.width - r, size.height),
        Offset(size.width - r - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r),
        Offset(size.width, size.height - r - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}