import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart';

class TextToSignPage extends StatefulWidget {
  @override
  _TextToSignPageState createState() => _TextToSignPageState();
}

class _TextToSignPageState extends State<TextToSignPage>
    with SingleTickerProviderStateMixin {
  TextEditingController _textController = TextEditingController();
  TextEditingController _originalTextController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Speech-to-text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Multi-language support
  final translator = GoogleTranslator();
  String _selectedLanguage = 'en-US';
  String _selectedLanguageName = 'English';

  // ── 10 major Indian languages + English ────────────────────────────────────
  final Map<String, Map<String, String>> _languages = {
    'en-US': {
      'name': 'English',
      'native': 'English',
      'code': 'en',
      'flag': '🇬🇧',
    },
    'hi-IN': {
      'name': 'Hindi',
      'native': 'हिन्दी',
      'code': 'hi',
      'flag': '🇮🇳',
    },
    'ta-IN': {
      'name': 'Tamil',
      'native': 'தமிழ்',
      'code': 'ta',
      'flag': '🇮🇳',
    },
    'te-IN': {
      'name': 'Telugu',
      'native': 'తెలుగు',
      'code': 'te',
      'flag': '🇮🇳',
    },
    'ml-IN': {
      'name': 'Malayalam',
      'native': 'മലയാളം',
      'code': 'ml',
      'flag': '🇮🇳',
    },
    'kn-IN': {
      'name': 'Kannada',
      'native': 'ಕನ್ನಡ',
      'code': 'kn',
      'flag': '🇮🇳',
    },
    'mr-IN': {
      'name': 'Marathi',
      'native': 'मराठी',
      'code': 'mr',
      'flag': '🇮🇳',
    },
    'gu-IN': {
      'name': 'Gujarati',
      'native': 'ગુજરાતી',
      'code': 'gu',
      'flag': '🇮🇳',
    },
    'pa-IN': {
      'name': 'Punjabi',
      'native': 'ਪੰਜਾਬੀ',
      'code': 'pa',
      'flag': '🇮🇳',
    },
    'bn-IN': {
      'name': 'Bengali',
      'native': 'বাংলা',
      'code': 'bn',
      'flag': '🇮🇳',
    },
    'or-IN': {
      'name': 'Odia',
      'native': 'ଓଡ଼ିଆ',
      'code': 'or',
      'flag': '🇮🇳',
    },
  };

  // Video queue management
  List<String> _videoQueue = [];
  int _currentVideoIndex = 0;
  bool _isPlayingSequence = false;
  bool _sequenceCompleted = false;
  bool _isDisposing = false;

  // Stopwords to filter out
  static const Set<String> STOP_WORDS = {
    'am', 'are', 'been', 'being', 'an', 'but', 'or', 'so',
    'does', 'did', 'would', 'shall', 'should', 'may',
    'might', 'must', 'were', 'a', 'the'
  };

  // Available video mappings
  static const Map<String, String> VIDEO_MAP = {
    '0': '0.mp4', '1': '1.mp4', '2': '2.mp4', '3': '3.mp4', '4': '4.mp4',
    '5': '5.mp4', '6': '6.mp4', '7': '7.mp4', '8': '8.mp4', '9': '9.mp4',
    'a': 'A.mp4', 'after': 'After.mp4', 'again': 'Again.mp4',
    'against': 'Against.mp4', 'age': 'Age.mp4', 'all': 'All.mp4',
    'alone': 'Alone.mp4', 'also': 'Also.mp4', 'and': 'And.mp4',
    'ask': 'Ask.mp4', 'at': 'At.mp4', 'b': 'B.mp4', 'be': 'Be.mp4',
    'beautiful': 'Beautiful.mp4', 'before': 'Before.mp4', 'best': 'Best.mp4',
    'better': 'Better.mp4', 'busy': 'Busy.mp4', 'bye': 'Bye.mp4',
    'c': 'C.mp4', 'can': 'Can.mp4', 'cannot': 'Cannot.mp4',
    'change': 'Change.mp4', 'college': 'College.mp4', 'come': 'Come.mp4',
    'computer': 'Computer.mp4', 'd': 'D.mp4', 'day': 'Day.mp4',
    'distance': 'Distance.mp4', 'do': 'Do.mp4', 'do not': 'Do Not.mp4',
    'does not': 'Does Not.mp4', 'e': 'E.mp4', 'eat': 'Eat.mp4',
    'engineer': 'Engineer.mp4', 'f': 'F.mp4', 'fight': 'Fight.mp4',
    'finish': 'Finish.mp4', 'from': 'From.mp4', 'g': 'G.mp4',
    'glitter': 'Glitter.mp4', 'go': 'Go.mp4', 'god': 'God.mp4',
    'gold': 'Gold.mp4', 'good': 'Good.mp4', 'great': 'Great.mp4',
    'h': 'H.mp4', 'hand': 'Hand.mp4', 'hands': 'Hands.mp4',
    'happy': 'Happy.mp4', 'hello': 'Hello.mp4', 'help': 'Help.mp4',
    'her': 'Her.mp4', 'here': 'Here.mp4', 'his': 'His.mp4',
    'home': 'Home.mp4', 'homepage': 'Homepage.mp4', 'how': 'How.mp4',
    'i': 'I.mp4', 'invent': 'Invent.mp4', 'it': 'It.mp4', 'j': 'J.mp4',
    'k': 'K.mp4', 'keep': 'Keep.mp4', 'l': 'L.mp4', 'language': 'Language.mp4',
    'laugh': 'Laugh.mp4', 'learn': 'Learn.mp4', 'm': 'M.mp4',
    'me': 'ME.mp4', 'more': 'More.mp4', 'my': 'My.mp4', 'n': 'N.mp4',
    'name': 'Name.mp4', 'next': 'Next.mp4', 'not': 'Not.mp4',
    'now': 'Now.mp4', 'o': 'O.mp4', 'of': 'Of.mp4', 'on': 'On.mp4',
    'our': 'Our.mp4', 'out': 'Out.mp4', 'p': 'P.mp4', 'pretty': 'Pretty.mp4',
    'q': 'Q.mp4', 'r': 'R.mp4', 'right': 'Right.mp4', 's': 'S.mp4',
    'sad': 'Sad.mp4', 'safe': 'Safe.mp4', 'see': 'See.mp4',
    'self': 'Self.mp4', 'sign': 'Sign.mp4', 'sing': 'Sing.mp4',
    'stay': 'Stay.mp4', 'study': 'Study.mp4', 't': 'T.mp4',
    'talk': 'Talk.mp4', 'television': 'Television.mp4', 'thank': 'Thank.mp4',
    'thank you': 'Thank You.mp4', 'that': 'That.mp4', 'they': 'They.mp4',
    'this': 'This.mp4', 'those': 'Those.mp4', 'time': 'Time.mp4',
    'to': 'To.mp4', 'type': 'Type.mp4', 'u': 'U.mp4', 'us': 'Us.mp4',
    'v': 'V.mp4', 'w': 'W.mp4', 'walk': 'Walk.mp4', 'wash': 'Wash.mp4',
    'way': 'Way.mp4', 'we': 'We.mp4', 'welcome': 'Welcome.mp4',
    'what': 'What.mp4', 'when': 'When.mp4', 'where': 'Where.mp4',
    'which': 'Which.mp4', 'who': 'Who.mp4', 'whole': 'Whole.mp4',
    'whose': 'Whose.mp4', 'why': 'Why.mp4', 'will': 'Will.mp4',
    'with': 'With.mp4', 'without': 'Without.mp4', 'words': 'Words.mp4',
    'work': 'Work.mp4', 'world': 'World.mp4', 'wrong': 'Wrong.mp4',
    'x': 'X.mp4', 'y': 'Y.mp4', 'you': 'You.mp4', 'your': 'Your.mp4',
    'yourself': 'Yourself.mp4', 'z': 'Z.mp4',
  };

  // ── Animation for language sheet ───────────────────────────────────────────
  late AnimationController _sheetAnim;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _sheetAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  // ── Language picker bottom sheet ───────────────────────────────────────────
  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LanguageSheet(
        languages: _languages,
        selectedKey: _selectedLanguage,
        onSelect: (key) {
          setState(() {
            _selectedLanguage = key;
            _selectedLanguageName = _languages[key]!['name']!;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Speech recognition ─────────────────────────────────────────────────────
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening') setState(() => _isListening = false);
        },
        onError: (val) {
          setState(() => _isListening = false);
          _showAlert('Error', 'Could not recognize speech. Please try again.');
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: _selectedLanguage,
          onResult: (val) async {
            final recognized = val.recognizedWords;
            setState(() => _originalTextController.text = recognized);

            if (_selectedLanguage != 'en-US') {
              try {
                final langCode = _languages[_selectedLanguage]!['code']!;
                final translation =
                await translator.translate(recognized, from: langCode, to: 'en');
                setState(() => _textController.text = translation.text);
              } catch (_) {
                setState(() => _textController.text = recognized);
              }
            } else {
              setState(() => _textController.text = recognized);
            }
          },
        );
      } else {
        _showAlert('Error', 'Speech recognition not available');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // ── Video helpers ──────────────────────────────────────────────────────────
  List<String> _getVideoFilesForText(String text) {
    List<String> videoFiles = [];
    text = text.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !STOP_WORDS.contains(w))
        .toList();
    for (final word in words) {
      if (VIDEO_MAP.containsKey(word)) {
        videoFiles.add(VIDEO_MAP[word]!);
        continue;
      }
      for (final char in word.split('')) {
        if (VIDEO_MAP.containsKey(char)) videoFiles.add(VIDEO_MAP[char]!);
      }
    }
    return videoFiles;
  }

  Future<void> _cleanupCurrentVideo() async {
    if (_videoController != null) {
      _isDisposing = true;
      try {
        _videoController!.removeListener(_videoListener);
        if (_videoController!.value.isPlaying) await _videoController!.pause();
        await _videoController!.dispose();
      } catch (_) {} finally {
        _videoController = null;
        _isDisposing = false;
      }
    }
  }

  Future<void> _generateAndPlayVideo() async {
    FocusScope.of(context).unfocus();
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showAlert('Please Enter Text', 'Type a message or use the microphone');
      return;
    }
    await _cleanupCurrentVideo();
    setState(() {
      _isLoading = true;
      _isPlayingSequence = false;
      _sequenceCompleted = false;
      _isInitialized = false;
      _videoQueue = [];
      _currentVideoIndex = 0;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    _videoQueue = _getVideoFilesForText(text);
    if (_videoQueue.isEmpty) {
      setState(() => _isLoading = false);
      _showAlert('No Videos Found',
          'Could not find sign language videos for this text');
      return;
    }
    _currentVideoIndex = 0;
    await _playNextVideo();
  }

  Future<void> _playNextVideo() async {
    if (_currentVideoIndex >= _videoQueue.length) {
      setState(() {
        _isPlayingSequence = false;
        _isLoading = false;
        _sequenceCompleted = true;
      });
      return;
    }
    final videoFile = _videoQueue[_currentVideoIndex];
    try {
      if (_videoController != null) {
        await _cleanupCurrentVideo();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      final data = await rootBundle.load('assets/videos/$videoFile');
      final tempDir = await getTemporaryDirectory();
      final tempVideo = File('${tempDir.path}/$videoFile');
      await tempVideo.writeAsBytes(data.buffer.asUint8List());
      _videoController = VideoPlayerController.file(tempVideo);
      await _videoController!.initialize();
      if (!mounted || _isDisposing) return;
      setState(() {
        _isPlayingSequence = true;
        _isLoading = false;
        _isInitialized = true;
      });
      _videoController!.addListener(_videoListener);
      await _videoController!.play();
    } catch (_) {
      _currentVideoIndex++;
      await _playNextVideo();
    }
  }

  void _videoListener() {
    if (_videoController != null &&
        !_isDisposing &&
        mounted &&
        _videoController!.value.isInitialized &&
        !_videoController!.value.isPlaying &&
        _videoController!.value.position >= _videoController!.value.duration) {
      _videoController!.removeListener(_videoListener);
      _currentVideoIndex++;
      _playNextVideo();
    }
  }

  Future<void> _replaySequence() async {
    if (_videoQueue.isEmpty) return;
    await _cleanupCurrentVideo();
    setState(() {
      _isLoading = true;
      _sequenceCompleted = false;
      _isInitialized = false;
      _currentVideoIndex = 0;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    await _playNextVideo();
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content:
        Text(message, style: const TextStyle(color: Color(0xFFa0a0b2))),
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
  void dispose() {
    _isDisposing = true;
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _textController.dispose();
    _originalTextController.dispose();
    _sheetAnim.dispose();
    _speech.stop();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isNonEnglish = _selectedLanguage != 'en-US';
    final hasOriginal = _originalTextController.text.isNotEmpty;

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
        title: const Text('Text to Sign Language',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero banner ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f3460)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                const Icon(Icons.sign_language,
                    size: 44, color: Color(0xFF4facfe)),
                const SizedBox(height: 10),
                const Text('Multi-Language Sign Translation',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  'Supports ${_languages.length - 1} Indian languages  •  Auto-translated to sign',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFa0a0b2)),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Language selector ────────────────────────────────
                    GestureDetector(
                      onTap: _showLanguagePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1a2e),
                          borderRadius: BorderRadius.circular(16),
                          border:
                          Border.all(color: const Color(0xFF2a2a3e)),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4facfe)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.language,
                                color: Color(0xFF4facfe), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('Speech Language',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF7c7c8a))),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    Text(
                                      _languages[_selectedLanguage]![
                                      'flag']! +
                                          '  ',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      _selectedLanguageName,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _languages[_selectedLanguage]![
                                      'native']!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF7c7c8a)),
                                    ),
                                  ]),
                                ]),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF4facfe), size: 26),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Language chips row ───────────────────────────────
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _languages.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final key = _languages.keys.elementAt(i);
                          final lang = _languages[key]!;
                          final selected = _selectedLanguage == key;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedLanguage = key;
                              _selectedLanguageName = lang['name']!;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? const LinearGradient(colors: [
                                  Color(0xFF4facfe),
                                  Color(0xFF00f2fe)
                                ])
                                    : null,
                                color: selected
                                    ? null
                                    : const Color(0xFF1a1a2e),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? Colors.transparent
                                      : const Color(0xFF2a2a3e),
                                ),
                              ),
                              child: Text(
                                '${lang['flag']}  ${lang['name']}',
                                style: TextStyle(
                                  fontSize: 12,
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
                    const SizedBox(height: 20),

                    // ── Original spoken text (non-English) ───────────────
                    if (isNonEnglish && hasOriginal) ...[
                      _sectionLabel(
                          Icons.record_voice_over,
                          'What You Spoke  ·  $_selectedLanguageName',
                          const Color(0xFFffa726)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1a2e),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFffa726), width: 1.5),
                        ),
                        child: Text(_originalTextController.text,
                            style: const TextStyle(
                                color: Color(0xFFffa726),
                                fontSize: 16,
                                height: 1.5)),
                      ),
                      const SizedBox(height: 14),
                      const Center(
                        child: Icon(Icons.arrow_downward_rounded,
                            color: Color(0xFF4facfe), size: 22),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── English translation input ─────────────────────────
                    _sectionLabel(
                      Icons.edit_rounded,
                      isNonEnglish
                          ? 'English Translation  (used for sign)'
                          : 'English Text  (for sign language)',
                      const Color(0xFF4facfe),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a2e),
                        borderRadius: BorderRadius.circular(16),
                        border:
                        Border.all(color: const Color(0xFF2a2a3e)),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: 4,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(18),
                          hintText: isNonEnglish
                              ? 'Translated English text will appear here…'
                              : 'Type or speak your message…',
                          hintStyle: const TextStyle(
                              color: Color(0xFF7c7c8a)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Action buttons ───────────────────────────────────
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap:
                          _isLoading ? null : _generateAndPlayVideo,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: _isLoading
                                  ? const LinearGradient(colors: [
                                Color(0xFF5c5c6a),
                                Color(0xFF4a4a58)
                              ])
                                  : const LinearGradient(colors: [
                                Color(0xFF4facfe),
                                Color(0xFF00f2fe)
                              ]),
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                                  : const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      color: Colors.white, size: 22),
                                  SizedBox(width: 8),
                                  Text('Generate Sign Language',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mic button
                      GestureDetector(
                        onTap: _listen,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isListening
                                ? const LinearGradient(colors: [
                              Colors.redAccent,
                              Colors.red
                            ])
                                : const LinearGradient(colors: [
                              Color(0xFF4facfe),
                              Color(0xFF00f2fe)
                            ]),
                            boxShadow: [
                              BoxShadow(
                                  color: (_isListening
                                      ? Colors.red
                                      : const Color(0xFF4facfe))
                                      .withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2)
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // ── Video player ─────────────────────────────────────
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1a2e),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF2a2a3e), width: 2),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _isInitialized &&
                              _videoController != null &&
                              _videoController!.value.isInitialized &&
                              !_isDisposing
                              ? Stack(children: [
                            SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController!
                                      .value.size.width,
                                  height: _videoController!
                                      .value.size.height,
                                  child: VideoPlayer(
                                      _videoController!),
                                ),
                              ),
                            ),
                            if (_sequenceCompleted)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black54,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: _replaySequence,
                                      child: Container(
                                        padding:
                                        const EdgeInsets.all(20),
                                        decoration:
                                        const BoxDecoration(
                                          color: Color(0xFF4facfe),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.replay_rounded,
                                            color: Colors.white,
                                            size: 48),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ])
                              : Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4facfe)
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person,
                                    size: 50,
                                    color: Color(0xFF4facfe)),
                              ),
                              const SizedBox(height: 16),
                              const Text('AI Avatar Ready',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight:
                                      FontWeight.w600)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Your sign language avatar\nwill appear here',
                                  style: TextStyle(
                                      color: Color(0xFF7c7c8a),
                                      fontSize: 13),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
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

  Widget _sectionLabel(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Language bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageSheet extends StatelessWidget {
  final Map<String, Map<String, String>> languages;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  const _LanguageSheet({
    required this.languages,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0d0e1a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2a2b3e),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Select Speech Language',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
                '10 Indian languages supported  •  Auto-translated to English for sign',
                style:
                TextStyle(color: Color(0xFF5a5b7a), fontSize: 12)),
          ),
          const SizedBox(height: 16),
          // Grid of language tiles
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: languages.length,
            itemBuilder: (_, i) {
              final key = languages.keys.elementAt(i);
              final lang = languages[key]!;
              final selected = selectedKey == key;
              return GestureDetector(
                onTap: () => onSelect(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(colors: [
                      Color(0xFF4facfe),
                      Color(0xFF00f2fe)
                    ])
                        : null,
                    color:
                    selected ? null : const Color(0xFF1a1b2e),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : const Color(0xFF2a2b3e),
                    ),
                  ),
                  child: Row(children: [
                    Text(lang['flag']!,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Text(lang['name']!,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFFd0d0e0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis),
                            Text(lang['native']!,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white70
                                        : const Color(0xFF5a5b7a),
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ]),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 16),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}