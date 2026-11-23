import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CvAtsApp());
}

class CvAtsApp extends StatelessWidget {
  const CvAtsApp({super.key});

  static const Color ink = Color(0xFF0F172A);
  static const Color primary = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color background = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      surface: Colors.white,
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'CV ATS Analysis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: ink,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.all(16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const LandingScreen(),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'CV ATS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 42),
          const Chip(label: Text('CV insights • Academic prototype')),
          const SizedBox(height: 24),
          Text(
            'Know how your CV performs before you apply.',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: CvAtsApp.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Understand ATS compatibility, compare your CV with a job description, and discover truthful improvements.',
            style: TextStyle(fontSize: 17, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NewAnalysisScreen()),
            ),
            icon: const Icon(Icons.upload_file),
            label: const Text('Analyze my CV'),
          ),
          const SizedBox(height: 28),
          const FeatureCard(
            icon: Icons.description_outlined,
            title: 'ATS compatibility',
            subtitle: 'Structure, readability, formatting and keyword coverage.',
          ),
          const FeatureCard(
            icon: Icons.track_changes_outlined,
            title: 'Job Match',
            subtitle: 'Skills, education, experience and role-specific requirements.',
          ),
          const FeatureCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Actionable improvements',
            subtitle: 'Evidence-based suggestions. Never invent experience.',
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: CvAtsApp.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewAnalysisScreen extends StatefulWidget {
  const NewAnalysisScreen({super.key});

  @override
  State<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends State<NewAnalysisScreen> {
  final _jobDescription = TextEditingController();
  final _jobTitle = TextEditingController();

  @override
  void dispose() {
    _jobDescription.dispose();
    _jobTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'New analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analyze your application',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Upload your CV and add a job description.',
              style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF93C5FD), width: 2),
            ),
            child: const Column(children: [
              Icon(Icons.upload_file_rounded, size: 48, color: CvAtsApp.primary),
              SizedBox(height: 12),
              Text('CV upload', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('PDF or DOCX • up to 10 MB', style: TextStyle(color: Color(0xFF64748B))),
              SizedBox(height: 12),
              Text('File selection will be connected to secure storage next.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _jobTitle,
            decoration: const InputDecoration(labelText: 'Job title (optional)'),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _jobDescription,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Job description', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          const Text('Real analysis is not enabled yet. The backend integration will be added next.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          const FilledButton(
            onPressed: null,
            child: Text('Analyze my application'),
          ),
        ],
      ),
    );
  }
}
