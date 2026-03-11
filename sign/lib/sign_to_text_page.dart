import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GRAMMAR ENGINE
// Fixes: "is", "are", "was", "more", "not", article insertion, capitalisation
// ─────────────────────────────────────────────────────────────────────────────
class GrammarEngine {
  // Signs that the video model predicts (after filtering stop-words).
  // We reconstruct a grammatical English sentence from them.

  // Verb-to-be mapping by subject
  static const _verbToBe = {
    'i': 'am',
    'he': 'is',
    'she': 'is',
    'it': 'is',
    'we': 'are',
    'you': 'are',
    'they': 'are',
  };

  // Simple past tense of "be"
  static const _pastBe = {
    'i': 'was',
    'he': 'was',
    'she': 'was',
    'it': 'was',
    'we': 'were',
    'you': 'were',
    'they': 'were',
  };

  // Nouns that typically need an article
  static const _needsArticle = {
    'engineer', 'computer', 'language', 'sign', 'day', 'way', 'word',
    'world', 'time', 'home', 'college', 'television', 'distance',
    'hand', 'name', 'age', 'type',
  };

  // Words that follow comparative adjectives
  static const _comparativeAdj = {'better', 'more', 'less', 'best', 'great'};

  /// Takes a raw list of predicted sign labels and returns a proper sentence.
  static String buildSentence(List<String> signs) {
    if (signs.isEmpty) return '';

    // ── 1. Normalise ─────────────────────────────────────────────────────────
    List<String> tokens =
    signs.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();

    // ── 2. De-duplicate consecutive same tokens ───────────────────────────────
    List<String> deduped = [];
    for (int i = 0; i < tokens.length; i++) {
      if (i == 0 || tokens[i] != tokens[i - 1]) deduped.add(tokens[i]);
    }

    // ── 3. Inject verb-to-be where missing ───────────────────────────────────
    // Pattern: <subject> <adjective/noun>  →  <subject> <is/am/are> <adj/noun>
    List<String> withBe = [];
    const subjects = {'i', 'he', 'she', 'it', 'we', 'you', 'they'};
    const adjectives = {
      'happy', 'sad', 'good', 'bad', 'busy', 'safe', 'beautiful',
      'pretty', 'great', 'best', 'better', 'wrong', 'alone',
    };

    for (int i = 0; i < deduped.length; i++) {
      withBe.add(deduped[i]);
      if (i < deduped.length - 1) {
        final cur = deduped[i];
        final nxt = deduped[i + 1];
        if (subjects.contains(cur) &&
            (adjectives.contains(nxt) || _needsArticle.contains(nxt)) &&
            !_verbToBe.containsKey(nxt) &&
            nxt != 'not' &&
            nxt != 'do' &&
            nxt != 'can') {
          final be = _verbToBe[cur] ?? 'is';
          withBe.add(be);
        }
      }
    }

    // ── 4. Inject articles (a/an) before bare nouns ───────────────────────────
    List<String> withArticles = [];
    const vowels = {'a', 'e', 'i', 'o', 'u'};
    for (int i = 0; i < withBe.length; i++) {
      final word = withBe[i];
      final prev = i > 0 ? withBe[i - 1] : '';
      // Skip if already has article or follows a possessive/determiner
      final prevIsDeterminer = {'my', 'your', 'his', 'her', 'our', 'their', 'a', 'an', 'the'}
          .contains(prev);
      if (_needsArticle.contains(word) && !prevIsDeterminer) {
        final article = vowels.contains(word[0]) ? 'an' : 'a';
        withArticles.add(article);
      }
      withArticles.add(word);
    }

    // ── 5. Handle "not" → contractions ───────────────────────────────────────
    List<String> contracted = [];
    for (int i = 0; i < withArticles.length; i++) {
      final word = withArticles[i];
      if (word == 'not' && i > 0) {
        final prev = contracted.isNotEmpty ? contracted.last : '';
        if (prev == 'do') {
          contracted[contracted.length - 1] = "don't";
          continue;
        } else if (prev == 'can') {
          contracted[contracted.length - 1] = "can't";
          continue;
        } else if (prev == 'is') {
          contracted[contracted.length - 1] = "isn't";
          continue;
        } else if (prev == 'are') {
          contracted[contracted.length - 1] = "aren't";
          continue;
        } else if (prev == 'am') {
          contracted[contracted.length - 1] = "am not";
          continue;
        }
      }
      contracted.add(word);
    }

    // ── 6. Fix "more" — ensure it has a following adjective/noun ─────────────
    // "more" alone at end → just keep; otherwise fine.
    // Nothing special needed beyond de-dup.

    // ── 7. Capitalise first word, add period ─────────────────────────────────
    if (contracted.isEmpty) return '';
    contracted[0] =
        contracted[0][0].toUpperCase() + contracted[0].substring(1);

    String sentence = contracted.join(' ');

    // Fix spacing before punctuation
    sentence = sentence.replaceAll(' .', '.').replaceAll(' ,', ',');

    // Add period if not already ending with punctuation
    if (!'.!?'.contains(sentence[sentence.length - 1])) sentence += '.';

    return sentence;
  }

  /// Applies very basic grammar fixes to a raw server sentence string.
  static String fixRawSentence(String raw) {
    if (raw.trim().isEmpty) return raw;
    final words = raw.trim().split(RegExp(r'\s+'));
    return buildSentence(words);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE CONFIG — 10 Indian languages + English
// ─────────────────────────────────────────────────────────────────────────────
class LangConfig {
  final String key;       // BCP-47 for STT
  final String name;      // English display name
  final String native;    // Native script name
  final String flag;
  final String ttsLocale; // BCP-47 for TTS
  final String transCode; // Google Translate code

  const LangConfig({
    required this.key,
    required this.name,
    required this.native,
    required this.flag,
    required this.ttsLocale,
    required this.transCode,
  });
}

const List<LangConfig> kLanguages = [
  LangConfig(key: 'en-US', name: 'English',    native: 'English',    flag: '🇬🇧', ttsLocale: 'en-US', transCode: 'en'),
  LangConfig(key: 'hi-IN', name: 'Hindi',      native: 'हिन्दी',      flag: '🇮🇳', ttsLocale: 'hi-IN', transCode: 'hi'),
  LangConfig(key: 'ta-IN', name: 'Tamil',      native: 'தமிழ்',      flag: '🇮🇳', ttsLocale: 'ta-IN', transCode: 'ta'),
  LangConfig(key: 'te-IN', name: 'Telugu',     native: 'తెలుగు',     flag: '🇮🇳', ttsLocale: 'te-IN', transCode: 'te'),
  LangConfig(key: 'ml-IN', name: 'Malayalam',  native: 'മലയാളം',    flag: '🇮🇳', ttsLocale: 'ml-IN', transCode: 'ml'),
  LangConfig(key: 'kn-IN', name: 'Kannada',    native: 'ಕನ್ನಡ',      flag: '🇮🇳', ttsLocale: 'kn-IN', transCode: 'kn'),
  LangConfig(key: 'mr-IN', name: 'Marathi',    native: 'मराठी',      flag: '🇮🇳', ttsLocale: 'mr-IN', transCode: 'mr'),
  LangConfig(key: 'gu-IN', name: 'Gujarati',   native: 'ગુજરાતી',   flag: '🇮🇳', ttsLocale: 'gu-IN', transCode: 'gu'),
  LangConfig(key: 'pa-IN', name: 'Punjabi',    native: 'ਪੰਜਾਬੀ',     flag: '🇮🇳', ttsLocale: 'pa-IN', transCode: 'pa'),
  LangConfig(key: 'bn-IN', name: 'Bengali',    native: 'বাংলা',      flag: '🇮🇳', ttsLocale: 'bn-IN', transCode: 'bn'),
  LangConfig(key: 'or-IN', name: 'Odia',       native: 'ଓଡ଼ିଆ',      flag: '🇮🇳', ttsLocale: 'or-IN', transCode: 'or'),
];

LangConfig langByKey(String key) =>
    kLanguages.firstWhere((l) => l.key == key, orElse: () => kLanguages.first);

// ─────────────────────────────────────────────────────────────────────────────
// API SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class ApiService {
  static const String baseUrl =
      'https://swaggeringly-superimproved-laney.ngrok-free.dev';

  Future<Map<String, dynamic>> predictSigns(File videoFile) async {
    if (!await videoFile.exists()) throw Exception('Video file does not exist');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/predict_signs/'),
    );
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      videoFile.path,
      filename: path.basename(videoFile.path),
    ));
    request.headers['Accept'] = 'application/json';

    final streamed = await request.send().timeout(
      const Duration(minutes: 10),
      onTimeout: () => throw Exception('Request timeout – video processing took too long'),
    );
    final response = await http.Response.fromStream(streamed);

    if (streamed.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;

      // ── Post-process the sentence from server ───────────────────────────────
      final rawSentence = body['sentence']?.toString() ?? '';
      final rawSigns    = (body['predicted_signs'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          [];

      // Build a proper grammatical sentence from the sign labels
      final fixedSentence = rawSigns.isNotEmpty
          ? GrammarEngine.buildSentence(rawSigns)
          : GrammarEngine.fixRawSentence(rawSentence);

      body['sentence']         = fixedSentence;
      body['sentence_raw']     = rawSentence; // keep original for debug
      return body;
    } else {
      try {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? err['detail'] ?? 'Server error');
      } catch (_) {
        throw Exception('Server error: ${streamed.statusCode}');
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIGN TO TEXT PAGE  (entry point)
// ─────────────────────────────────────────────────────────────────────────────
class SignToTextPage extends StatefulWidget {
  @override
  _SignToTextPageState createState() => _SignToTextPageState();
}

class _SignToTextPageState extends State<SignToTextPage> {
  List<CameraDescription>? _cameras;
  final ApiService _apiService = ApiService();
  final ImagePicker _picker   = ImagePicker();
  bool _isLoading             = true;
  bool _camerasInitialized    = false;

  // Selected output language for TTS / translation
  String _selectedLangKey = 'en-US';

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      setState(() { _camerasInitialized = true; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndProcessVideo() async {
    try {
      final XFile? videoFile =
      await _picker.pickVideo(source: ImageSource.gallery);
      if (videoFile == null) return;
      final video = File(videoFile.path);
      if (!await video.exists()) throw Exception('Selected file does not exist');
      final size = await video.length();
      if (size == 0) throw Exception('Selected file is empty');
      if (size > 100 * 1024 * 1024)
        throw Exception('Video too large (max 100 MB)');

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          videoPath: video.path,
          apiService: _apiService,
          outputLangKey: _selectedLangKey,
        ),
      ));
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _navigateToCamera() {
    if (_cameras == null || _cameras!.isEmpty) {
      _showError('No cameras available on this device');
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CameraScreen(
        cameras: _cameras!,
        apiService: _apiService,
        outputLangKey: _selectedLangKey,
      ),
    ));
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('Error', style: TextStyle(color: Colors.white)),
        ]),
        content: Text(message,
            style: const TextStyle(color: Color(0xFFa0a0b2))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: Color(0xFF4facfe))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sign Language to Text',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF4facfe)))
          : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0a0a0f), Color(0xFF1a1a2e)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 28),
                _buildLangSelector(),
                const SizedBox(height: 24),
                _buildFeatureCards(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Column(children: [
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFf093fb), Color(0xFFf5576c)]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFf093fb).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5)
        ],
      ),
      child: const Icon(Icons.videocam, size: 60, color: Colors.white),
    ),
    const SizedBox(height: 20),
    const Text('Convert Sign Language',
        style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white),
        textAlign: TextAlign.center),
    const SizedBox(height: 6),
    const Text('Record or upload a video to translate',
        style: TextStyle(fontSize: 13, color: Color(0xFFa0a0b2)),
        textAlign: TextAlign.center),
  ]);

  // ── Output language selector ───────────────────────────────────────────────
  Widget _buildLangSelector() {
    final lang = langByKey(_selectedLangKey);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.translate, color: Color(0xFF4facfe), size: 16),
        SizedBox(width: 6),
        Text('Output Language for Translation & Speech',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      // Horizontal scroll chips
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kLanguages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final l = kLanguages[i];
            final selected = _selectedLangKey == l.key;
            return GestureDetector(
              onTap: () => setState(() => _selectedLangKey = l.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                      colors: [Color(0xFFf093fb), Color(0xFFf5576c)])
                      : null,
                  color: selected ? null : const Color(0xFF1a1a2e),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : const Color(0xFF2a2a3e)),
                ),
                child: Text(
                  '${l.flag}  ${l.name}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                    color:
                    selected ? Colors.white : const Color(0xFF7c7c8a),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFf093fb).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFFf093fb).withOpacity(0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline,
              color: Color(0xFFf093fb), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Signs → English grammar fix → translated to ${lang.flag} ${lang.name} → spoken aloud',
              style: const TextStyle(
                  color: Color(0xFFa0a0b2), fontSize: 11),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Feature cards ──────────────────────────────────────────────────────────
  Widget _buildFeatureCards() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1a1a2e),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF2a2a3e)),
    ),
    child: Column(children: [
      _featureItem(Icons.video_library, 'Upload Video',
          'Select a pre-recorded sign language video',
          const Color(0xFF4facfe)),
      const Divider(height: 28, color: Color(0xFF2a2a3e)),
      _featureItem(Icons.videocam, 'Record Live',
          'Use your camera to record sign language',
          const Color(0xFFf5576c)),
      const Divider(height: 28, color: Color(0xFF2a2a3e)),
      _featureItem(Icons.psychology, 'AI + Grammar Fix',
          'Signs → grammatically correct sentence → translated',
          const Color(0xFF00f2fe)),
    ]),
  );

  Widget _featureItem(
      IconData icon, String title, String desc, Color color) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white)),
            const SizedBox(height: 3),
            Text(desc,
                style: const TextStyle(
                    color: Color(0xFFa0a0b2), fontSize: 12)),
          ]),
        ),
      ]);

  // ── Action buttons ─────────────────────────────────────────────────────────
  Widget _buildActionButtons() => Column(children: [
    GestureDetector(
      onTap: _camerasInitialized ? _navigateToCamera : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _camerasInitialized
              ? const LinearGradient(
              colors: [Color(0xFFf093fb), Color(0xFFf5576c)])
              : const LinearGradient(
              colors: [Color(0xFF7c7c8a), Color(0xFF5c5c6a)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFf093fb).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam, color: Colors.white),
              SizedBox(width: 8),
              Text('Record Video',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ]),
      ),
    ),
    const SizedBox(height: 14),
    GestureDetector(
      onTap: _pickAndProcessVideo,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4facfe), width: 2),
        ),
        child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, color: Color(0xFF4facfe)),
              SizedBox(width: 8),
              Text('Upload Video',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4facfe))),
            ]),
      ),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROCESSING SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ProcessingScreen extends StatefulWidget {
  final String videoPath;
  final ApiService apiService;
  final String outputLangKey;

  const ProcessingScreen({
    Key? key,
    required this.videoPath,
    required this.apiService,
    required this.outputLangKey,
  }) : super(key: key);

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  String _status = 'Uploading video…';
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    _animateDots();
    _processVideo();
  }

  void _animateDots() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return false;
      setState(() => _dots = (_dots + 1) % 4);
      return true;
    });
  }

  Future<void> _processVideo() async {
    try {
      setState(() => _status = 'Analysing signs…');
      final response =
      await widget.apiService.predictSigns(File(widget.videoPath));
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: response,
          videoPath: widget.videoPath,
          outputLangKey: widget.outputLangKey,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(color: Colors.white)),
          ]),
          content: Text(e.toString(),
              style: const TextStyle(color: Color(0xFFa0a0b2))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK',
                  style: TextStyle(color: Color(0xFF4facfe))),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF4facfe).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
                color: Color(0xFF4facfe), strokeWidth: 3),
          ),
          const SizedBox(height: 28),
          Text(
            _status + '.' * _dots,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('AI grammar engine will fix the sentence',
              style: TextStyle(color: Color(0xFFa0a0b2), fontSize: 13)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMERA SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ApiService apiService;
  final String outputLangKey;

  const CameraScreen({
    Key? key,
    required this.cameras,
    required this.apiService,
    required this.outputLangKey,
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
        widget.cameras.first, ResolutionPreset.high,
        enableAudio: false);
    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
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
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            videoPath: video.path,
            apiService: widget.apiService,
            outputLangKey: widget.outputLangKey,
          ),
        ));
      } catch (e) {
        debugPrint('Stop recording error: $e');
        setState(() => _isRecording = false);
      }
    } else {
      try {
        await _controller!.startVideoRecording();
        setState(() { _isRecording = true; _recordingSeconds = 0; });
        _startTimer();
      } catch (e) {
        debugPrint('Start recording error: $e');
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

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0a0a0f),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF4facfe))),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      appBar: AppBar(
        title: const Text('Record Sign Language',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: _isRecording ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            Center(child: CameraPreview(_controller!)),
            if (_isRecording)
              Positioned(
                top: 20, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2)
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fiber_manual_record,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(_fmt(_recordingSeconds),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed:
                  _isRecording ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close,
                      color: _isRecording
                          ? const Color(0xFF7c7c8a)
                          : Colors.white),
                  iconSize: 32,
                ),
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isRecording
                          ? const LinearGradient(
                          colors: [Colors.red, Colors.redAccent])
                          : const LinearGradient(colors: [
                        Color(0xFFf093fb),
                        Color(0xFFf5576c)
                      ]),
                      border:
                      Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                            color: (_isRecording
                                ? Colors.red
                                : const Color(0xFFf093fb))
                                .withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 3)
                      ],
                    ),
                    child: _isRecording
                        ? const Icon(Icons.stop,
                        color: Colors.white, size: 32)
                        : null,
                  ),
                ),
                const SizedBox(width: 48),
              ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final String videoPath;
  final String outputLangKey;

  const ResultScreen({
    Key? key,
    required this.result,
    required this.videoPath,
    required this.outputLangKey,
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // TTS
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  // Translation
  final GoogleTranslator _translator = GoogleTranslator();
  String _translatedText = '';
  bool _isTranslating = false;
  String _currentLangKey = 'en-US';

  // Sentence data
  String _englishSentence = '';
  List<String> _signs = [];

  @override
  void initState() {
    super.initState();
    _currentLangKey = widget.outputLangKey;
    _englishSentence = widget.result['sentence']?.toString() ?? '';
    _signs = (widget.result['predicted_signs'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        [];
    _initVideo();
    _initTts();
    _translateAndShow(_currentLangKey);
  }

  Future<void> _initVideo() async {
    try {
      _videoController =
          VideoPlayerController.file(File(widget.videoPath));
      await _videoController!.initialize();
      if (mounted) setState(() => _isVideoInitialized = true);
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_currentLangKey);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _tts.setErrorHandler((_) => setState(() => _isSpeaking = false));
  }

  // ── Translate to selected language ──────────────────────────────────────────
  Future<void> _translateAndShow(String langKey) async {
    if (_englishSentence.isEmpty) {
      setState(() => _translatedText = '');
      return;
    }

    final lang = langByKey(langKey);
    if (lang.transCode == 'en') {
      setState(() {
        _translatedText = _englishSentence;
        _currentLangKey = langKey;
      });
      return;
    }

    setState(() { _isTranslating = true; _currentLangKey = langKey; });
    try {
      final result = await _translator.translate(
        _englishSentence,
        from: 'en',
        to: lang.transCode,
      );
      if (mounted)
        setState(() {
          _translatedText = result.text;
          _isTranslating = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _translatedText = _englishSentence;
          _isTranslating = false;
        });
    }
  }

  // ── TTS speak ───────────────────────────────────────────────────────────────
  Future<void> _speak() async {
    final text =
    _translatedText.isNotEmpty ? _translatedText : _englishSentence;
    if (text.isEmpty) return;

    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    final lang = langByKey(_currentLangKey);
    await _tts.setLanguage(lang.ttsLocale);
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool success = widget.result['success'] ?? false;
    final lang = langByKey(_currentLangKey);
    final displayText =
    _translatedText.isNotEmpty ? _translatedText : _englishSentence;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0f),
      appBar: AppBar(
        title: const Text('Translation Result',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video player
            if (_isVideoInitialized && _videoController != null)
              _buildVideoPlayer()
            else
              const SizedBox(
                  height: 180,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4facfe)))),
            const SizedBox(height: 20),

            // Language output selector
            _buildOutputLangSelector(),
            const SizedBox(height: 20),

            // Result card
            _buildResultCard(success, displayText, lang),
            const SizedBox(height: 20),

            // English sentence (always visible)
            if (_currentLangKey != 'en-US' &&
                _englishSentence.isNotEmpty)
              _buildEnglishCard(),
            if (_currentLangKey != 'en-US' &&
                _englishSentence.isNotEmpty)
              const SizedBox(height: 20),

            // Signs list
            if (success && _signs.isNotEmpty) _buildSignsList(),
            const SizedBox(height: 20),

            _buildActionButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Video player ────────────────────────────────────────────────────────────
  Widget _buildVideoPlayer() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF2a2a3e), width: 2),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        Container(
          color: const Color(0xFF1a1a2e),
          padding: const EdgeInsets.all(10),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: const Color(0xFF4facfe),
                    size: 38,
                  ),
                  onPressed: () => setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  }),
                ),
              ]),
        ),
      ]),
    ),
  );

  // ── Output language selector ────────────────────────────────────────────────
  Widget _buildOutputLangSelector() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1a1a2e),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF2a2a3e)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Translate output to:',
          style: TextStyle(
              color: Color(0xFF7c7c8a),
              fontSize: 11,
              letterSpacing: 1)),
      const SizedBox(height: 10),
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kLanguages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final l = kLanguages[i];
            final selected = _currentLangKey == l.key;
            return GestureDetector(
              onTap: () => _translateAndShow(l.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(colors: [
                    Color(0xFFf093fb),
                    Color(0xFFf5576c)
                  ])
                      : null,
                  color: selected ? null : const Color(0xFF0d0e1a),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : const Color(0xFF2a2a3e)),
                ),
                child: Text(
                  '${l.flag}  ${l.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: selected
                        ? Colors.white
                        : const Color(0xFF7c7c8a),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]),
  );

  // ── Result card ─────────────────────────────────────────────────────────────
  Widget _buildResultCard(
      bool success, String displayText, LangConfig lang) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2a2a3e)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: success
                        ? [Colors.green, Colors.greenAccent]
                        : [Colors.orange, Colors.orangeAccent]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  success ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        success
                            ? 'Translation Complete'
                            : 'Translation Result',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(
                        'Grammar-corrected  •  ${lang.flag} ${lang.name}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7c7c8a))),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          const Text('Translated Text:',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7c7c8a),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          // Text box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF4facfe).withOpacity(0.08),
                const Color(0xFF00f2fe).withOpacity(0.08),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF4facfe).withOpacity(0.25)),
            ),
            child: _isTranslating
                ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Color(0xFF4facfe), strokeWidth: 2)))
                : Text(
              displayText.isEmpty ? '(no text detected)' : displayText,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          // Speak button
          GestureDetector(
            onTap: _speak,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: _isSpeaking
                        ? [const Color(0xFFf5576c), const Color(0xFFf093fb)]
                        : [const Color(0xFF4facfe), const Color(0xFF00f2fe)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: (_isSpeaking
                          ? const Color(0xFFf5576c)
                          : const Color(0xFF4facfe))
                          .withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _isSpeaking
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 22),
                    const SizedBox(width: 8),
                    Text(
                        _isSpeaking
                            ? 'Stop Speaking'
                            : 'Speak in ${lang.flag} ${lang.name}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ]),
            ),
          ),
        ]),
      );

  // ── English original (shown only for non-English output) ────────────────────
  Widget _buildEnglishCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0d1a0d),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: Colors.green.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.spellcheck_rounded,
            color: Colors.green, size: 14),
        SizedBox(width: 6),
        Text('Grammar-corrected English',
            style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 8),
      Text(_englishSentence,
          style: const TextStyle(
              color: Colors.white70, fontSize: 15, height: 1.4)),
    ]),
  );

  // ── Signs list ──────────────────────────────────────────────────────────────
  Widget _buildSignsList() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1a1a2e),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF2a2a3e)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.list_alt, color: Color(0xFF4facfe), size: 18),
        const SizedBox(width: 8),
        Text('Detected Signs  (${_signs.length})',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ]),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _signs.map((sign) {
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF4facfe).withOpacity(0.15),
                const Color(0xFF00f2fe).withOpacity(0.15),
              ]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF4facfe).withOpacity(0.35)),
            ),
            child: Text(sign,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          );
        }).toList(),
      ),
    ]),
  );

  // ── Back button ─────────────────────────────────────────────────────────────
  Widget _buildActionButton() => GestureDetector(
    onTap: () =>
        Navigator.of(context).popUntil((r) => r.isFirst),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF4facfe).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Back to Home',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ]),
    ),
  );
}