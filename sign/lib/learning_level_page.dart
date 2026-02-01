import 'package:flutter/material.dart';
import 'learning_path_page.dart';
import 'learning_lesson_page.dart';

class LearningLevelPage extends StatefulWidget {
  final LevelData level;

  const LearningLevelPage({Key? key, required this.level}) : super(key: key);

  @override
  _LearningLevelPageState createState() => _LearningLevelPageState();
}

class _LearningLevelPageState extends State<LearningLevelPage> {
  // Group lessons by category for a cleaner layout
  Map<String, List<Lesson>> get _groupedLessons {
    final map = <String, List<Lesson>>{};
    for (final lesson in widget.level.lessons) {
      map.putIfAbsent(lesson.category, () => []).add(lesson);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final pct = level.progress;
    final groups = _groupedLessons;

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
          level.title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── Top progress banner
          _buildProgressBanner(level, pct),
          // ── Scrollable lesson list
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groups.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category header
                      _buildCategoryHeader(entry.key, entry.value, level),
                      SizedBox(height: 10),
                      // Lesson grid / list
                      _buildLessonGrid(entry.value, level),
                      SizedBox(height: 24),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBanner(LevelData level, double pct) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: level.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(level.icon, size: 26, color: Colors.white),
              ),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    level.subtitle,
                    style:
                    TextStyle(fontSize: 13, color: Color(0xFFa0a0b2)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Color(0xFF2a2a3e),
              valueColor: AlwaysStoppedAnimation<Color>(level.accentColor),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '${level.completedCount} / ${level.lessons.length} completed  •  ${(pct * 100).toInt()}%',
            style: TextStyle(fontSize: 12, color: Color(0xFF7c7c8a)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(
      String category, List<Lesson> lessons, LevelData level) {
    final doneCount = lessons.where((l) => l.completed).length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          category,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: level.accentColor,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: level.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$doneCount / ${lessons.length}',
            style: TextStyle(
              fontSize: 12,
              color: level.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonGrid(List<Lesson> lessons, LevelData level) {
    // For Numbers & Alphabet use a compact grid; for Words/Sentences use a list
    final useGrid =
        lessons.first.category == 'Numbers' || lessons.first.category == 'Alphabet';

    if (useGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: lessons.length,
        itemBuilder: (_, i) => _LessonGridCell(
          lesson: lessons[i],
          level: level,
          onTap: () => _openLesson(lessons[i]),
        ),
      );
    } else {
      return Column(
        children: lessons
            .map((lesson) => Column(
          children: [
            _LessonListTile(
              lesson: lesson,
              level: level,
              onTap: () => _openLesson(lesson),
            ),
            SizedBox(height: 10),
          ],
        ))
            .toList(),
      );
    }
  }

  Future<void> _openLesson(Lesson lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LearningLessonPage(lesson: lesson),
      ),
    );
    // Refresh after returning (lesson may have been completed)
    setState(() {});
  }
}

// ═══════════════════════════════════════════════
//  Grid cell — compact square for numbers/alphabet
// ═══════════════════════════════════════════════

class _LessonGridCell extends StatelessWidget {
  final Lesson lesson;
  final LevelData level;
  final VoidCallback onTap;

  const _LessonGridCell(
      {Key? key,
        required this.lesson,
        required this.level,
        required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final done = lesson.completed;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: done
              ? Color(0xFF1a1a2e)
              : Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? level.accentColor.withOpacity(0.6)
                : Color(0xFF2a2a3e),
            width: done ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    lesson.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: done ? level.accentColor : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // checkmark badge
            if (done)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.check_circle,
                    color: level.accentColor, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  List tile — for words / sentences
// ═══════════════════════════════════════════════

class _LessonListTile extends StatelessWidget {
  final Lesson lesson;
  final LevelData level;
  final VoidCallback onTap;

  const _LessonListTile(
      {Key? key,
        required this.lesson,
        required this.level,
        required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final done = lesson.completed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done
                ? level.accentColor.withOpacity(0.5)
                : Color(0xFF2a2a3e),
            width: done ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // status circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? level.accentColor.withOpacity(0.2)
                    : Color(0xFF2a2a3e),
              ),
              child: Center(
                child: done
                    ? Icon(Icons.check, color: level.accentColor, size: 18)
                    : Icon(Icons.play_arrow,
                    color: Color(0xFF7c7c8a), size: 18),
              ),
            ),
            SizedBox(width: 14),
            // title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (lesson.words.length > 1)
                    SizedBox(height: 4),
                  if (lesson.words.length > 1)
                    Text(
                      '${lesson.words.length} signs',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF7c7c8a)),
                    ),
                ],
              ),
            ),
            // arrow
            Icon(Icons.arrow_forward_ios,
                color: Color(0xFF7c7c8a), size: 16),
          ],
        ),
      ),
    );
  }
}