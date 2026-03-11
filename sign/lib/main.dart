import 'package:flutter/material.dart';
import 'text_to_sign_page.dart';
import 'sign_to_text_page.dart';
import 'learning_path_page.dart';
import 'random_video_call_page.dart';
import 'practice_page.dart'; // ← renamed

void main() {
  runApp(SignLanguageApp());
}

class SignLanguageApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sign Language AI Translator',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0a0a0f),
        primaryColor: Color(0xFF4facfe),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0a0a0f),
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 40),
                  _buildHeader(),
                  SizedBox(height: 40),
                  _buildFeatureCards(),
                  SizedBox(height: 40),
                  _buildFooter(),
                  SizedBox(height: 20),
                ],
              ),
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
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient:
            LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF4facfe).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.sign_language,
            size: 80,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Sign Language',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'AI Translator',
          style: TextStyle(
            fontSize: 20,
            color: Color(0xFF4facfe),
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 12),
        Text(
          'Bridge the communication gap with AI',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFa0a0b2),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      children: [
        _buildFeatureCard(
          icon: Icons.text_fields,
          title: 'Text to Sign',
          description: 'Convert text or speech into sign language animations',
          gradient: LinearGradient(
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TextToSignPage()),
            );
          },
        ),
        SizedBox(height: 20),
        _buildFeatureCard(
          icon: Icons.videocam,
          title: 'Sign to Text',
          description: 'Record or upload sign language videos for translation',
          gradient: LinearGradient(
            colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SignToTextPage()),
            );
          },
        ),
        SizedBox(height: 20),
        _buildFeatureCard(
          icon: Icons.school,
          title: 'Learning Path',
          description:
          'Learn sign language step by step — Basic, Intermediate & Expert',
          gradient: LinearGradient(
            colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LearningPathPage()),
            );
          },
        ),
        SizedBox(height: 20),
        _buildFeatureCard(
          icon: Icons.people_alt_rounded,
          title: 'Random Video Call',
          description:
          'Instantly connect with a random partner for live sign language practice',
          gradient: LinearGradient(
            colors: [Color(0xFF6a11cb), Color(0xFF2575fc)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const RandomVideoCallPage()),
            );
          },
          badge: 'LIVE',
        ),
        SizedBox(height: 20),

        // ───── PRACTICE CARD (replaces Test Model) ─────
        _buildFeatureCard(
          icon: Icons.sports_esports_rounded,
          title: 'Practice',
          description:
          'Challenge yourself with guided sign prompts, build sentences freely, and track your progress',
          gradient: LinearGradient(
            colors: [Color(0xFF7c6bf8), Color(0xFFa78bfa)],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PracticePage()),
            );
          },
          badge: 'NEW',
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF2a2a3e), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 40, color: Colors.white),
                ),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badge == 'NEW'
                            ? const Color(0xFF7c6bf8)
                            : badge == 'LIVE'
                            ? Colors.red
                            : const Color(0xFF11998e),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFa0a0b2),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF7c7c8a),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatCard('50+', 'Signs'),
            SizedBox(width: 16),
            _buildStatCard('AI', 'Powered'),
            SizedBox(width: 16),
            _buildStatCard('Real', 'Time'),
          ],
        ),
        SizedBox(height: 20),
        Text(
          'Powered by Advanced Machine Learning',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF7c7c8a),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2a2a3e)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4facfe),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFa0a0b2),
            ),
          ),
        ],
      ),
    );
  }
}