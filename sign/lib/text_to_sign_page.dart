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

class _TextToSignPageState extends State<TextToSignPage> {
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

  // Available languages
  final Map<String, Map<String, String>> _languages = {
    'en-US': {'name': 'English', 'code': 'en'},
    'ta-IN': {'name': 'தமிழ் (Tamil)', 'code': 'ta'},
    'hi-IN': {'name': 'हिन्दी (Hindi)', 'code': 'hi'},
    'te-IN': {'name': 'తెలుగు (Telugu)', 'code': 'te'},
    'ml-IN': {'name': 'മലയാളം (Malayalam)', 'code': 'ml'},
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

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1a1a2e),
        title: Text(
          'Select Language',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _languages.entries.map((entry) {
              bool isSelected = _selectedLanguage == entry.key;
              return ListTile(
                title: Text(
                  entry.value['name']!,
                  style: TextStyle(
                    color: isSelected ? Color(0xFF4facfe) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Color(0xFF4facfe) : Color(0xFF7c7c8a),
                ),
                onTap: () {
                  setState(() {
                    _selectedLanguage = entry.key;
                    _selectedLanguageName = entry.value['name']!;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening') setState(() => _isListening = false);
        },
        onError: (val) {
          setState(() => _isListening = false);
          _showAlert("Error", "Could not recognize speech. Please try again.");
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: _selectedLanguage,
          onResult: (val) async {
            String recognizedText = val.recognizedWords;

            // Store original text
            setState(() {
              _originalTextController.text = recognizedText;
            });

            // If not English, translate to English
            if (_selectedLanguage != 'en-US') {
              try {
                String languageCode = _languages[_selectedLanguage]!['code']!;
                var translation = await translator.translate(
                  recognizedText,
                  from: languageCode,
                  to: 'en',
                );
                setState(() {
                  _textController.text = translation.text;
                });
              } catch (e) {
                print("Translation error: $e");
                setState(() {
                  _textController.text = recognizedText;
                });
              }
            } else {
              setState(() {
                _textController.text = recognizedText;
              });
            }
          },
        );
      } else {
        _showAlert("Error", "Speech recognition not available");
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  List<String> _getVideoFilesForText(String text) {
    List<String> videoFiles = [];
    text = text.toLowerCase().trim();
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    List<String> words = text.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !STOP_WORDS.contains(w))
        .toList();
    for (String word in words) {
      if (VIDEO_MAP.containsKey(word)) {
        videoFiles.add(VIDEO_MAP[word]!);
        continue;
      }
      for (int i = 0; i < word.length; i++) {
        String char = word[i];
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
      } catch (e) {
        print("Error disposing video: $e");
      } finally {
        _videoController = null;
        _isDisposing = false;
      }
    }
  }

  Future<void> _generateAndPlayVideo() async {
    FocusScope.of(context).unfocus();
    String text = _textController.text.trim();
    if (text.isEmpty) {
      _showAlert("Please Enter Text", "Type a message or use the microphone");
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

    await Future.delayed(Duration(milliseconds: 100));

    _videoQueue = _getVideoFilesForText(text);

    if (_videoQueue.isEmpty) {
      setState(() => _isLoading = false);
      _showAlert("No Videos Found", "Could not find sign language videos for this text");
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

    String videoFile = _videoQueue[_currentVideoIndex];

    try {
      if (_videoController != null) {
        await _cleanupCurrentVideo();
        await Future.delayed(Duration(milliseconds: 50));
      }

      final ByteData data = await rootBundle.load('assets/videos/$videoFile');
      final Directory tempDir = await getTemporaryDirectory();
      final File tempVideo = File('${tempDir.path}/$videoFile');
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
    } catch (e) {
      print("Video error: $e");
      _currentVideoIndex++;
      await _playNextVideo();
    }
  }

  void _videoListener() {
    if (_videoController != null &&
        !_isDisposing &&
        mounted &&
        _videoController!.value.isInitialized) {
      if (!_videoController!.value.isPlaying &&
          _videoController!.value.position >= _videoController!.value.duration) {
        _videoController!.removeListener(_videoListener);
        _currentVideoIndex++;
        _playNextVideo();
      }
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

    await Future.delayed(Duration(milliseconds: 100));
    await _playNextVideo();
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF1a1a2e),
        title: Text(title, style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Color(0xFFa0a0b2))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: Color(0xFF4facfe))),
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
    _speech.stop();
    super.dispose();
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
          'Text to Sign Language',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.sign_language, size: 48, color: Color(0xFF4facfe)),
                  SizedBox(height: 12),
                  Text(
                    "Multi-Language Sign Translation",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Speak in any language, translate to sign language",
                    style: TextStyle(fontSize: 13, color: Color(0xFFa0a0b2)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Language Selector
                    GestureDetector(
                      onTap: _showLanguageDialog,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Color(0xFF1a1a2e),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFF2a2a3e)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.language, color: Color(0xFF4facfe), size: 24),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Speech Language",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7c7c8a),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _selectedLanguageName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Icon(Icons.arrow_drop_down, color: Color(0xFF4facfe), size: 28),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Original Spoken Text Section (only show if not English and has text)
                    if (_selectedLanguage != 'en-US' && _originalTextController.text.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.record_voice_over, color: Color(0xFFffa726), size: 20),
                              SizedBox(width: 8),
                              Text(
                                "What You Spoke ($_selectedLanguageName)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFF1a1a2e),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Color(0xFFffa726), width: 1.5),
                            ),
                            child: Text(
                              _originalTextController.text,
                              style: TextStyle(
                                color: Color(0xFFffa726),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          // Translation arrow
                          Center(
                            child: Icon(
                              Icons.arrow_downward,
                              color: Color(0xFF4facfe),
                              size: 24,
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),

                    // English Translation Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit, color: Color(0xFF4facfe), size: 20),
                            SizedBox(width: 8),
                            Text(
                              _selectedLanguage != 'en-US'
                                  ? "English Translation (for sign language)"
                                  : "English Text (for sign language)",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF1a1a2e),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFF2a2a3e)),
                          ),
                          child: TextField(
                            controller: _textController,
                            maxLines: 4,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.all(20),
                              hintText: _selectedLanguage != 'en-US'
                                  ? "Translated English text will appear here..."
                                  : "Type or speak your message...",
                              hintStyle: TextStyle(color: Color(0xFF7c7c8a)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLoading ? null : _generateAndPlayVideo,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: _isLoading
                                    ? LinearGradient(colors: [Color(0xFF7c7c8a), Color(0xFF5c5c6a)])
                                    : LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      "Generate Sign Language",
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
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: _isListening
                                ? LinearGradient(colors: [Colors.redAccent, Colors.red])
                                : LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 32,
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                            ),
                            onPressed: _listen,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Video Display
                    Container(
                      width: MediaQuery.of(context).size.width - 32,
                      height: MediaQuery.of(context).size.width - 32,
                      decoration: BoxDecoration(
                        color: Color(0xFF1a1a2e),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFF2a2a3e), width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _isInitialized &&
                            _videoController != null &&
                            _videoController!.value.isInitialized &&
                            !_isDisposing
                            ? Stack(
                          children: [
                            SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController!.value.size.width,
                                  height: _videoController!.value.size.height,
                                  child: VideoPlayer(_videoController!),
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
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF4facfe),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.replay,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                            : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person, size: 50, color: Color(0xFF7c7c8a)),
                              SizedBox(height: 20),
                              Text(
                                "AI Avatar Ready",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Your sign language avatar\nwill appear here",
                                style: TextStyle(
                                  color: Color(0xFF7c7c8a),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}