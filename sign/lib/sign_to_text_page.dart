import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_tts/flutter_tts.dart';

class SignToTextPage extends StatefulWidget {
  @override
  _SignToTextPageState createState() => _SignToTextPageState();
}

class _SignToTextPageState extends State<SignToTextPage> {
  List<CameraDescription>? _cameras;
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _camerasInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      setState(() {
        _camerasInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing cameras: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndProcessVideo() async {
    try {
      final XFile? videoFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (videoFile != null) {
        File video = File(videoFile.path);

        if (!await video.exists()) {
          throw Exception('Selected file does not exist');
        }

        int fileSize = await video.length();
        if (fileSize == 0) {
          throw Exception('Selected file is empty');
        }

        if (fileSize > 100 * 1024 * 1024) {
          throw Exception('Video file too large. Please select a smaller videos (max 100MB)');
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingScreen(
              videoPath: video.path,
              apiService: _apiService,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _navigateToCamera() {
    if (_cameras == null || _cameras!.isEmpty) {
      _showErrorDialog('No cameras available on this device');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          cameras: _cameras!,
          apiService: _apiService,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1a1a2e),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Color(0xFFa0a0b2))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFF4facfe))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0a0f),
      appBar: AppBar(
        backgroundColor: Color(0xFF1a1a2e),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sign Language to Text',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF4facfe)))
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0a0a0f),
              Color(0xFF1a1a2e),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20),
                _buildHeader(),
                SizedBox(height: 40),
                _buildFeatureCards(),
                SizedBox(height: 40),
                _buildActionButtons(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFFf093fb).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(Icons.videocam, size: 60, color: Colors.white),
        ),
        SizedBox(height: 24),
        Text(
          'Convert Sign Language',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Record or upload a videos to translate',
          style: TextStyle(fontSize: 14, color: Color(0xFFa0a0b2)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2a2a3e)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFeatureItem(
            Icons.video_library,
            'Upload Video',
            'Select a pre-recorded sign language videos',
            Color(0xFF4facfe),
          ),
          Divider(height: 32, color: Color(0xFF2a2a3e)),
          _buildFeatureItem(
            Icons.videocam,
            'Record Live',
            'Use your camera to record sign language',
            Color(0xFFf5576c),
          ),
          Divider(height: 32, color: Color(0xFF2a2a3e)),
          _buildFeatureItem(
            Icons.psychology,
            'AI Processing',
            'Advanced ML model recognizes 50+ signs',
            Color(0xFF00f2fe),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Color(0xFFa0a0b2),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        GestureDetector(
          onTap: _camerasInitialized ? _navigateToCamera : null,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _camerasInitialized
                  ? LinearGradient(colors: [Color(0xFFf093fb), Color(0xFFf5576c)])
                  : LinearGradient(colors: [Color(0xFF7c7c8a), Color(0xFF5c5c6a)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_camerasInitialized ? Color(0xFFf093fb) : Color(0xFF7c7c8a)).withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Record Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: _pickAndProcessVideo,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF4facfe), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, color: Color(0xFF4facfe)),
                SizedBox(width: 8),
                Text(
                  'Upload Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4facfe),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============ API SERVICE ============
class ApiService {
  static const String baseUrl = 'https://swaggeringly-superimproved-laney.ngrok-free.dev';

  Future<Map<String, dynamic>> predictSigns(File videoFile) async {
    try {
      print('Sending videos to: $baseUrl/predict_signs/');

      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict_signs/'),
      );

      var multipartFile = await http.MultipartFile.fromPath(
        'file',
        videoFile.path,
        filename: path.basename(videoFile.path),
      );

      request.files.add(multipartFile);
      request.headers.addAll({'Accept': 'application/json'});

      var streamedResponse = await request.send().timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          throw Exception('Request timeout - videos processing took too long');
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (streamedResponse.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          var errorJson = json.decode(response.body);
          throw Exception(errorJson['message'] ?? errorJson['detail'] ?? 'Server error');
        } catch (e) {
          throw Exception('Server error: ${streamedResponse.statusCode}');
        }
      }
    } on SocketException {
      throw Exception('Cannot connect to server. Please check backend is running.');
    } catch (e) {
      rethrow;
    }
  }
}

// ============ PROCESSING SCREEN ============
class ProcessingScreen extends StatefulWidget {
  final String videoPath;
  final ApiService apiService;

  const ProcessingScreen({
    Key? key,
    required this.videoPath,
    required this.apiService,
  }) : super(key: key);

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _processVideo();
  }

  Future<void> _processVideo() async {
    try {
      File videoFile = File(widget.videoPath);
      final response = await widget.apiService.predictSigns(videoFile);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            result: response,
            videoPath: widget.videoPath,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Color(0xFF1a1a2e),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(e.toString(), style: TextStyle(color: Color(0xFFa0a0b2))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('OK', style: TextStyle(color: Color(0xFF4facfe))),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0a0f),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4facfe), strokeWidth: 3),
            SizedBox(height: 24),
            Text(
              'Processing videos...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(color: Color(0xFFa0a0b2)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ CAMERA SCREEN ============
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ApiService apiService;

  const CameraScreen({
    Key? key,
    required this.cameras,
    required this.apiService,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      try {
        final video = await _controller!.stopVideoRecording();
        setState(() => _isRecording = false);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingScreen(
              videoPath: video.path,
              apiService: widget.apiService,
            ),
          ),
        );
      } catch (e) {
        print('Error stopping recording: $e');
        setState(() => _isRecording = false);
      }
    } else {
      try {
        await _controller!.startVideoRecording();
        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });
        _startTimer();
      } catch (e) {
        print('Error starting recording: $e');
      }
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() => _recordingSeconds++);
        return true;
      }
      return false;
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Color(0xFF0a0a0f),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4facfe)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF0a0a0f),
      appBar: AppBar(
        title: Text('Record Sign Language', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF1a1a2e),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _isRecording ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(child: CameraPreview(_controller!)),
                if (_isRecording)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.red, Colors.redAccent]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              _formatDuration(_recordingSeconds),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF1a1a2e),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _isRecording ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: _isRecording ? Color(0xFF7c7c8a) : Colors.white),
                  iconSize: 32,
                ),
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isRecording
                          ? LinearGradient(colors: [Colors.red, Colors.redAccent])
                          : LinearGradient(colors: [Color(0xFFf093fb), Color(0xFFf5576c)]),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : Color(0xFFf093fb)).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: _isRecording
                        ? Icon(Icons.stop, color: Colors.white, size: 32)
                        : null,
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ RESULT SCREEN ============
class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final String videoPath;

  const ResultScreen({
    Key? key,
    required this.result,
    required this.videoPath,
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeTts();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
      await _videoController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      print('Error initializing videos player: $e');
    }
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() => _isSpeaking = false);
      print('TTS Error: $msg');
    });
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;

    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool success = widget.result['success'] ?? false;
    final String sentence = widget.result['sentence'] ?? '';
    final List<dynamic> signs = widget.result['predicted_signs'] ?? [];
    final String message = widget.result['message'] ?? '';
    final String textToSpeak = success && sentence.isNotEmpty
        ? sentence
        : message;

    return Scaffold(
      backgroundColor: Color(0xFF0a0a0f),
      appBar: AppBar(
        title: Text('Translation Result', style: TextStyle(color: Colors
            .white)),
        backgroundColor: Color(0xFF1a1a2e),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isInitialized && _videoController != null)
              _buildVideoPlayer()
            else
              Container(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4facfe)),
                ),
              ),
            SizedBox(height: 24),
            _buildResultCard(success, sentence, signs, message, textToSpeak),
            SizedBox(height: 24),
            if (success && signs.isNotEmpty) _buildSignsList(signs),
            SizedBox(height: 24),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2a2a3e), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
            Container(
              color: Color(0xFF1a1a2e),
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _videoController!.value.isPlaying ? Icons
                          .pause_circle_filled : Icons.play_circle_filled,
                      color: Color(0xFF4facfe),
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(bool success, String sentence, List signs,
      String message, String textToSpeak) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2a2a3e)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: success
                        ? [Colors.green, Colors.greenAccent]
                        : [Colors.orange, Colors.orangeAccent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  success ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  success ? 'Translation Complete' : 'Translation Result',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Translated Text:',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF7c7c8a),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4facfe).withOpacity(0.1),
                  Color(0xFF00f2fe).withOpacity(0.1)
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF4facfe).withOpacity(0.3)),
            ),
            child: Text(
              textToSpeak,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 16),
          GestureDetector(
            onTap: () => _speakText(textToSpeak),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSpeaking
                      ? [Color(0xFFf5576c), Color(0xFFf093fb)]
                      : [Color(0xFF4facfe), Color(0xFF00f2fe)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_isSpeaking ? Color(0xFFf5576c) : Color(0xFF4facfe))
                        .withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isSpeaking ? 'Stop Speaking' : 'Speak Text',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignsList(List signs) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2a2a3e)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: Color(0xFF4facfe)),
              SizedBox(width: 8),
              Text(
                'Detected Signs (${signs.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: signs.map((sign) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF4facfe).withOpacity(0.2),
                      Color(0xFF00f2fe).withOpacity(0.2)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF4facfe).withOpacity(0.4)),
                ),
                child: Text(
                  sign.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4facfe).withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Back to Home',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}