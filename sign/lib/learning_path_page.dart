import 'package:flutter/material.dart';
import 'learning_level_page.dart';

// ─────────────────────────────────────────────
// Shared data layer — single source of truth for
// every level, lesson, and completion state.
// ─────────────────────────────────────────────

enum LevelDifficulty { basic, intermediate, expert }

class Lesson {
  final String id;        // unique key, e.g. "basic_num_0"
  final String title;     // display name, e.g. "0" or "Hello"
  final String category;  // "Numbers" / "Alphabet" / "Words" / "Sentences"
  final List<String> words; // words fed to the video-queue engine
  bool completed;

  Lesson({
    required this.id,
    required this.title,
    required this.category,
    required this.words,
    this.completed = false,
  });
}

class LevelData {
  final LevelDifficulty difficulty;
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Color accentColor;
  final List<Lesson> lessons;

  LevelData({
    required this.difficulty,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.accentColor,
    required this.lessons,
  });

  int get completedCount => lessons.where((l) => l.completed).length;
  double get progress => lessons.isEmpty ? 0 : completedCount / lessons.length;
}

// ─── Build lesson lists ───

List<Lesson> _buildBasicLessons() {
  final lessons = <Lesson>[];
  // Numbers 0-9
  for (int i = 0; i <= 9; i++) {
    lessons.add(Lesson(
      id: 'basic_num_$i',
      title: '$i',
      category: 'Numbers',
      words: ['$i'],
    ));
  }
  // Alphabet A-Z
  for (int c = 65; c <= 90; c++) {
    final letter = String.fromCharCode(c);
    lessons.add(Lesson(
      id: 'basic_alpha_${letter.toLowerCase()}',
      title: letter,
      category: 'Alphabet',
      words: [letter.toLowerCase()],
    ));
  }
  return lessons;
}

List<Lesson> _buildIntermediateLessons() {
  // Common single words that exist in VIDEO_MAP
  final wordList = [
    'Hello', 'Bye', 'Thank You', 'Help', 'Good', 'Bad',
    'Happy', 'Sad', 'Beautiful', 'Best', 'Better',
    'Yes', 'No', 'Not', 'Come', 'Go', 'Eat', 'Walk',
    'Talk', 'Learn', 'Study', 'Work', 'Play', 'Sing',
    'Laugh', 'Stay', 'Safe', 'Welcome', 'Right', 'Wrong',
    'Home', 'School', 'College', 'Computer', 'Television',
    'Name', 'Time', 'Day', 'Now', 'Next',
    'More', 'Great', 'Pretty', 'Gold', 'Glitter',
  ];

  return wordList.mapIndexed((i, w) => Lesson(
    id: 'inter_word_$i',
    title: w,
    category: 'Words',
    words: [w.toLowerCase()],
  )).toList();
}

List<Lesson> _buildExpertLessons() {
  // Multi-word sentences — the engine will play each word's video in order
  final sentences = [
    { 'title': 'Hello, how are you?',        'words': ['hello', 'how', 'you'] },
    { 'title': 'Thank you very much',        'words': ['thank', 'you', 'more'] },
    { 'title': 'My name is…',               'words': ['my', 'name', 'is'] },
    { 'title': 'I am happy today',           'words': ['i', 'happy', 'day'] },
    { 'title': 'Please help me',             'words': ['help', 'me'] },
    { 'title': 'I want to learn',            'words': ['i', 'learn'] },
    { 'title': 'Where do you work?',         'words': ['where', 'you', 'work'] },
    { 'title': 'I go to college',            'words': ['i', 'go', 'college'] },
    { 'title': 'Come here now',              'words': ['come', 'here', 'now'] },
    { 'title': 'Stay safe at home',          'words': ['stay', 'safe', 'home'] },
    { 'title': 'Do not go out',              'words': ['do', 'not', 'go', 'out'] },
    { 'title': 'I like to eat',              'words': ['i', 'eat'] },
    { 'title': 'How are you doing?',         'words': ['how', 'you', 'do'] },
    { 'title': 'I want to talk',             'words': ['i', 'talk'] },
    { 'title': 'See you next time',          'words': ['see', 'you', 'next', 'time'] },
    { 'title': 'We are the best',            'words': ['we', 'best'] },
    { 'title': 'Walk to the right',          'words': ['walk', 'right'] },
    { 'title': 'I sing every day',           'words': ['i', 'sing', 'day'] },
    { 'title': 'Welcome to our world',       'words': ['welcome', 'our', 'world'] },
    { 'title': 'Goodbye, see you later',     'words': ['bye', 'see', 'you'] },
  ];

  return sentences.mapIndexed((i, s) => Lesson(
    id: 'expert_sent_$i',
    title: s['title'] as String,
    category: 'Sentences',
    words: s['words'] as List<String>,
  )).toList();
}

// ─── Global singleton so progress persists across navigation ───

class LearningData {
  static final LearningData instance = LearningData();

  final List<LevelData> levels = [
    LevelData(
      difficulty: LevelDifficulty.basic,
      title: 'Basic',
      subtitle: 'Numbers & Alphabet',
      icon: Icons.looks_one,
      gradient: LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
      accentColor: Color(0xFF4facfe),
      lessons: _buildBasicLessons(),
    ),
    LevelData(
      difficulty: LevelDifficulty.intermediate,
      title: 'Intermediate',
      subtitle: 'Common Words',
      icon: Icons.looks_two,
      gradient: LinearGradient(colors: [Color(0xFFffa726), Color(0xFFff7043)]),
      accentColor: Color(0xFFffa726),
      lessons: _buildIntermediateLessons(),
    ),
    LevelData(
      difficulty: LevelDifficulty.expert,
      title: 'Expert',
      subtitle: 'Full Sentences',
      icon: Icons.looks_3,
      gradient: LinearGradient(colors: [Color(0xFFf093fb), Color(0xFFf5576c)]),
      accentColor: Color(0xFFf093fb),
      lessons: _buildExpertLessons(),
    ),
  ];

  void markCompleted(String lessonId) {
    for (final level in levels) {
      for (final lesson in level.lessons) {
        if (lesson.id == lessonId) {
          lesson.completed = true;
          return;
        }
      }
    }
  }

  void resetAll() {
    for (final level in levels) {
      for (final lesson in level.lessons) {
        lesson.completed = false;
      }
    }
  }
}

// ─── Extension helper used above ───

extension IterableIndexed<T> on Iterable<T> {
  List<R> mapIndexed<R>(R Function(int index, T element) f) {
    final result = <R>[];
    int i = 0;
    for (final e in this) {
      result.add(f(i++, e));
    }
    return result;
  }
}

// ═══════════════════════════════════════════════
//  LearningPathPage   –  three level cards
// ═══════════════════════════════════════════════

class LearningPathPage extends StatefulWidget {
  @override
  _LearningPathPageState createState() => _LearningPathPageState();
}

class _LearningPathPageState extends State<LearningPathPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );
    _slideAnims = List.generate(3, (i) {
      final start = (i * 0.15);
      final end = start + 0.55;
      return Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = LearningData.instance;
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
          'Learning Path',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF7c7c8a)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Color(0xFF1a1a2e),
                  title: Text('Reset Progress',
                      style: TextStyle(color: Colors.white)),
                  content: Text(
                      'Are you sure you want to reset all progress?',
                      style: TextStyle(color: Color(0xFFa0a0b2))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: TextStyle(color: Color(0xFF7c7c8a))),
                    ),
                    TextButton(
                      onPressed: () {
                        data.resetAll();
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('Reset',
                          style: TextStyle(color: Color(0xFFf5576c))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header
            _buildPageHeader(data),
            SizedBox(height: 28),
            // ── Level cards
            ...data.levels.mapIndexed((i, level) {
              return Column(children: [
                SlideTransition(
                  position: _slideAnims[i],
                  child: _LevelCard(
                    level: level,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LearningLevelPage(level: level)),
                      ).then((_) => setState(() {}));
                    },
                  ),
                ),
                SizedBox(height: 20),
              ]);
            }),
            SizedBox(height: 12),
            // ── Overall progress
            _buildOverallProgress(data),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(LearningData data) {
    final totalLessons =
    data.levels.fold(0, (sum, l) => sum + l.lessons.length);
    final totalDone =
    data.levels.fold(0, (sum, l) => sum + l.completedCount);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2a2a3e)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, color: Color(0xFF43e97b), size: 28),
              SizedBox(width: 10),
              Text(
                'Sign Language Journey',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            'Master sign language one step at a time',
            style: TextStyle(fontSize: 13, color: Color(0xFFa0a0b2)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          // mini progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalLessons == 0 ? 0 : totalDone / totalLessons,
              minHeight: 8,
              backgroundColor: Color(0xFF2a2a3e),
              valueColor:
              AlwaysStoppedAnimation<Color>(Color(0xFF43e97b)),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '$totalDone / $totalLessons lessons completed',
            style: TextStyle(fontSize: 12, color: Color(0xFF7c7c8a)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress(LearningData data) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2a2a3e)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: data.levels.map((level) {
          return Column(
            children: [
              Text(
                '${level.completedCount}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: level.accentColor,
                ),
              ),
              Text(
                level.title,
                style:
                TextStyle(fontSize: 11, color: Color(0xFFa0a0b2)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Reusable level card widget ───

class _LevelCard extends StatelessWidget {
  final LevelData level;
  final VoidCallback onTap;

  const _LevelCard({Key? key, required this.level, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pct = level.progress;
    final isComplete = pct >= 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isComplete
                ? Color(0xFF43e97b).withOpacity(0.5)
                : Color(0xFF2a2a3e),
            width: isComplete ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // top row: icon  +  info  +  arrow
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: level.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(level.icon, size: 32, color: Colors.white),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            level.title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (isComplete) ...[
                            SizedBox(width: 8),
                            Icon(Icons.check_circle,
                                color: Color(0xFF43e97b), size: 18),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        level.subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFFa0a0b2)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Color(0xFF7c7c8a), size: 18),
              ],
            ),
            SizedBox(height: 16),
            // progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Color(0xFF2a2a3e),
                valueColor: AlwaysStoppedAnimation<Color>(level.accentColor),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${level.completedCount} / ${level.lessons.length} lessons',
                  style:
                  TextStyle(fontSize: 12, color: Color(0xFF7c7c8a)),
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: level.accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}