import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'learning_path_page.dart';

class LearningLessonPage extends StatefulWidget {
  final Lesson lesson;

  const LearningLessonPage({Key? key, required this.lesson}) : super(key: key);

  @override
  _LearningLessonPageState createState() => _LearningLessonPageState();
}

class _LearningLessonPageState extends State<LearningLessonPage> {
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isDisposing = false;
  bool _isPlayingSequence = false;
  bool _sequenceCompleted = false;
  bool _hasPlayed = false; // true once the user has played at least once

  // Video queue
  List<String> _videoQueue = [];
  int _currentVideoIndex = 0;

  // ─── VIDEO_MAP (same as TextToSignPage) ────────────────────────────
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

  // ─── Resolve lesson.words → video file list ────────────────────────
  List<String> _resolveVideos(List<String> words) {
    final videos = <String>[];
    for (final w in words) {
      final lower = w.toLowerCase().trim();
      if (VIDEO_MAP.containsKey(lower)) {
        videos.add(VIDEO_MAP[lower]!);
      } else {
        // spell it out letter by letter
        for (final ch in lower.split('')) {
          if (VIDEO_MAP.containsKey(ch)) {
            videos.add(VIDEO_MAP[ch]!);
          }
        }
      }
    }
    return videos;
  }

  // ─── Video playback engine (same pattern as TextToSignPage) ─────────

  Future<void> _cleanupCurrentVideo() async {
    if (_videoController != null) {
      _isDisposing = true;
      try {
        _videoController!.removeListener(_videoListener);
        if (_videoController!.value.isPlaying) await _videoController!.pause();
        await _videoController!.dispose();
      } catch (e) {
        // ignore
      } finally {
        _videoController = null;
        _isDisposing = false;
      }
    }
  }

  Future<void> _startPlayback() async {
    await _cleanupCurrentVideo();

    setState(() {
      _isLoading = true;
      _isPlayingSequence = false;
      _sequenceCompleted = false;
      _isInitialized = false;
      _currentVideoIndex = 0;
    });

    _videoQueue = _resolveVideos(widget.lesson.words);

    if (_videoQueue.isEmpty) {
      setState(() => _isLoading = false);
      _showAlert('No Video', 'Could not find a sign video for this lesson.');
      return;
    }

    await Future.delayed(Duration(milliseconds: 80));
    await _playNextVideo();
  }

  Future<void> _playNextVideo() async {
    if (_currentVideoIndex >= _videoQueue.length) {
      // sequence finished
      setState(() {
        _isPlayingSequence = false;
        _isLoading = false;
        _sequenceCompleted = true;
        _hasPlayed = true;
      });
      // auto-mark completed
      if (!widget.lesson.completed) {
        LearningData.instance.markCompleted(widget.lesson.id);
        setState(() {});
      }
      return;
    }

    final videoFile = _videoQueue[_currentVideoIndex];

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
      print('Video error: $e');
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

  // ─── UI helpers ─────────────────────────────────────────────────────

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
            child: Text('OK', style: TextStyle(color: Color(0xFF4facfe))),
          ),
        ],
      ),
    );
  }

  Color get _levelAccent {
    final id = widget.lesson.id;
    if (id.startsWith('basic')) return Color(0xFF4facfe);
    if (id.startsWith('inter')) return Color(0xFFffa726);
    return Color(0xFFf093fb);
  }

  Gradient get _levelGradient {
    final id = widget.lesson.id;
    if (id.startsWith('basic'))
      return LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]);
    if (id.startsWith('inter'))
      return LinearGradient(colors: [Color(0xFFffa726), Color(0xFFff7043)]);
    return LinearGradient(colors: [Color(0xFFf093fb), Color(0xFFf5576c)]);
  }

  String get _levelLabel {
    final id = widget.lesson.id;
    if (id.startsWith('basic')) return 'Basic';
    if (id.startsWith('inter')) return 'Intermediate';
    return 'Expert';
  }

  @override
  void dispose() {
    _isDisposing = true;
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final isSentence = lesson.words.length > 1;

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
          lesson.title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (lesson.completed)
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.check_circle,
                  color: Color(0xFF43e97b), size: 22),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Info card
            _buildInfoCard(lesson, isSentence),
            SizedBox(height: 20),

            // ── Video display
            _buildVideoPlayer(),
            SizedBox(height: 20),

            // ── Controls
            _buildControls(lesson),
            SizedBox(height: 20),

            // ── Current sign label (during playback)
            if (_isInitialized && _isPlayingSequence && isSentence)
              _buildCurrentSignLabel(),

            // ── Completed banner
            if (lesson.completed && _hasPlayed)
              _buildCompletedBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(Lesson lesson, bool isSentence) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFF2a2a3e)),
      ),
      child: Column(
        children: [
          // level badge + category
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: _levelGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _levelLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(0xFF2a2a3e),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lesson.category,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFa0a0b2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // main title
          Text(
            lesson.title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          // description
          Text(
            isSentence
                ? 'Watch the avatar perform each sign in the sentence in order.'
                : 'Watch the avatar perform this sign carefully.',
            style: TextStyle(fontSize: 13, color: Color(0xFFa0a0b2)),
            textAlign: TextAlign.center,
          ),
          // word chips for sentences
          if (isSentence) ...[
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: lesson.words.map((w) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _levelAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border:
                    Border.all(color: _levelAccent.withOpacity(0.4)),
                  ),
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 13,
                      color: _levelAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final size = MediaQuery.of(context).size.width - 32;

    return Container(
      width: size,
      height: size,
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
            // replay overlay when sequence finished
            if (_sequenceCompleted)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: GestureDetector(
                      onTap: _startPlayback,
                      child: Container(
                        padding: EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _levelAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.replay,
                            color: Colors.white, size: 40),
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
              Icon(Icons.person,
                  size: 56, color: Color(0xFF7c7c8a)),
              SizedBox(height: 16),
              Text(
                _isLoading ? 'Loading…' : 'Press Learn to watch',
                style: TextStyle(
                  color:
                  _isLoading ? Color(0xFF4facfe) : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!_isLoading)
                ...[
                  SizedBox(height: 6),
                  Text(
                    'The avatar will show you the sign',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF7c7c8a)),
                    textAlign: TextAlign.center,
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(Lesson lesson) {
    return Row(
      children: [
        // ── Learn / Play button
        Expanded(
          child: GestureDetector(
            onTap: _isLoading ? null : _startPlayback,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _isLoading
                    ? LinearGradient(
                    colors: [Color(0xFF7c7c8a), Color(0xFF5c5c6a)])
                    : _levelGradient,
              ),
              child: Center(
                child: _isLoading
                    ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasPlayed ? Icons.replay : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _hasPlayed ? 'Replay' : 'Learn',
                      style: TextStyle(
                        fontSize: 18,
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
      ],
    );
  }

  Widget _buildCurrentSignLabel() {
    if (_currentVideoIndex >= _videoQueue.length) return SizedBox();
    // show which word is currently playing
    final currentWord =
    _currentVideoIndex < widget.lesson.words.length
        ? widget.lesson.words[_currentVideoIndex]
        : '';

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _levelAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _levelAccent.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility, color: _levelAccent, size: 16),
              SizedBox(width: 6),
              Text(
                'Now showing: "$currentWord"',
                style: TextStyle(
                  fontSize: 14,
                  color: _levelAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        // mini progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.lesson.words.length, (i) {
            final active = i == _currentVideoIndex;
            final done = i < _currentVideoIndex;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: active ? 22 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: done
                      ? _levelAccent
                      : active
                      ? _levelAccent.withOpacity(0.6)
                      : Color(0xFF2a2a3e),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompletedBanner() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF43e97b).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF43e97b).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star, color: Color(0xFF43e97b), size: 26),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lesson Completed!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF43e97b),
                ),
              ),
              Text(
                'Great job! This sign is now marked as learned.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFa0a0b2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}