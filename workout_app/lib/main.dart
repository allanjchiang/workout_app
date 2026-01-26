import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const WorkoutTrackerApp());
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 22),
          bodyMedium: TextStyle(fontSize: 20),
          labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: const MainNavigationPage(),
    );
  }
}

// ============== DATA MODELS ==============

/// Individual exercise definition
class Exercise {
  final String id;
  final String name;
  final String? description;
  final String iconKey;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    this.iconKey = 'fitness_center',
  });

  IconData get icon => kExerciseIconMap[iconKey] ?? Icons.fitness_center;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'iconKey': iconKey,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        iconKey: (json['iconKey'] as String?) ??
            _iconKeyFromLegacy(json['iconCodePoint'] as int?),
      );

  Exercise copyWith({
    String? id,
    String? name,
    String? description,
    String? iconKey,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        iconKey: iconKey ?? this.iconKey,
      );
}

/// Exercise within a template with target reps/weight
class TemplateExercise {
  final Exercise exercise;
  final int targetReps;
  final double targetWeight;
  final int sets;

  const TemplateExercise({
    required this.exercise,
    this.targetReps = 10,
    this.targetWeight = 0,
    this.sets = 3,
  });

  Map<String, dynamic> toJson() => {
        'exercise': exercise.toJson(),
        'targetReps': targetReps,
        'targetWeight': targetWeight,
        'sets': sets,
      };

  factory TemplateExercise.fromJson(Map<String, dynamic> json) =>
      TemplateExercise(
        exercise: Exercise.fromJson(json['exercise'] as Map<String, dynamic>),
        targetReps: json['targetReps'] as int? ?? 10,
        targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 0,
        sets: json['sets'] as int? ?? 3,
      );

  TemplateExercise copyWith({
    Exercise? exercise,
    int? targetReps,
    double? targetWeight,
    int? sets,
  }) =>
      TemplateExercise(
        exercise: exercise ?? this.exercise,
        targetReps: targetReps ?? this.targetReps,
        targetWeight: targetWeight ?? this.targetWeight,
        sets: sets ?? this.sets,
      );
}

/// Workout template containing multiple exercises
class WorkoutTemplate {
  final String id;
  final String name;
  final String? description;
  final List<TemplateExercise> exercises;
  final DateTime createdAt;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.exercises,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) =>
      WorkoutTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        exercises: (json['exercises'] as List<dynamic>)
            .map((e) => TemplateExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  WorkoutTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<TemplateExercise>? exercises,
    DateTime? createdAt,
  }) =>
      WorkoutTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        exercises: exercises ?? this.exercises,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Logged set during a workout
class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double weight;
  final DateTime timestamp;

  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    required this.weight,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'setNumber': setNumber,
        'reps': reps,
        'weight': weight,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
        exerciseId: json['exerciseId'] as String,
        exerciseName: json['exerciseName'] as String,
        setNumber: json['setNumber'] as int,
        reps: json['reps'] as int,
        weight: (json['weight'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Completed workout session
class WorkoutSession {
  final String id;
  final String templateId;
  final String templateName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final List<ExerciseLog> logs;

  const WorkoutSession({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.logs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateName': templateName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String,
        templateId: json['templateId'] as String,
        templateName: json['templateName'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        durationSeconds: json['durationSeconds'] as int,
        logs: (json['logs'] as List<dynamic>)
            .map((l) => ExerciseLog.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}

// Available icons for exercises (const to allow tree shaking)
const Map<String, IconData> kExerciseIconMap = {
  'fitness_center': Icons.fitness_center,
  'sports_gymnastics': Icons.sports_gymnastics,
  'accessibility_new': Icons.accessibility_new,
  'directions_run': Icons.directions_run,
  'self_improvement': Icons.self_improvement,
  'sports': Icons.sports,
  'arrow_upward': Icons.arrow_upward,
  'open_with': Icons.open_with,
  'arrow_forward': Icons.arrow_forward,
  'compare_arrows': Icons.compare_arrows,
  'keyboard_double_arrow_up': Icons.keyboard_double_arrow_up,
  'pan_tool': Icons.pan_tool,
};

const List<String> kExerciseIconKeys = [
  'fitness_center',
  'sports_gymnastics',
  'accessibility_new',
  'directions_run',
  'self_improvement',
  'sports',
  'arrow_upward',
  'open_with',
  'arrow_forward',
  'compare_arrows',
  'keyboard_double_arrow_up',
  'pan_tool',
];

String _iconKeyFromLegacy(int? codePoint) {
  if (codePoint == null) return 'fitness_center';
  for (final entry in kExerciseIconMap.entries) {
    if (entry.value.codePoint == codePoint) {
      return entry.key;
    }
  }
  return 'fitness_center';
}

// ============== MAIN NAVIGATION ==============

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  List<WorkoutTemplate> templates = [];
  List<WorkoutSession> history = [];
  Map<String, int> _pendingOldWorkouts = {};
  bool _postFrameInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureDefaultTemplateAndMigrate();
      }
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load templates
    final templatesJson = prefs.getString('workout_templates');
    if (templatesJson != null) {
      final List<dynamic> decoded = jsonDecode(templatesJson);
      setState(() {
        templates = decoded
            .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }

    // Load history
    final historyJson = prefs.getString('workout_history');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      setState(() {
        history = decoded
            .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }

    // MIGRATION: Check for old workout data from previous app version
    final oldWorkoutsJson = prefs.getString('workouts');
    if (oldWorkoutsJson != null) {
      _pendingOldWorkouts =
          Map<String, int>.from(jsonDecode(oldWorkoutsJson));
    }
  }

  Future<void> _ensureDefaultTemplateAndMigrate() async {
    if (_postFrameInitialized) return;
    _postFrameInitialized = true;

    final l10n = AppLocalizations.of(context)!;
    const defaultTemplateId = 'default_shoulder_workout';

    final hasDefault = templates.any((t) => t.id == defaultTemplateId);
    if (!hasDefault) {
      final shoulderTemplate = _createDefaultShoulderTemplate(l10n);
      setState(() {
        templates.insert(0, shoulderTemplate);
      });
      await _saveTemplates();
    }

    // If there's old workout data, create a history entry to preserve the rep counts
    if (_pendingOldWorkouts.isNotEmpty) {
      final migrationLogs = <ExerciseLog>[];
      final exerciseNames = {
        'shoulderPress': l10n.get('shoulderPress'),
        'lateralRaise': l10n.get('lateralRaise'),
        'frontRaise': l10n.get('frontRaise'),
        'reverseFly': l10n.get('reverseFly'),
        'shrugs': l10n.get('shrugs'),
      };

      for (final entry in _pendingOldWorkouts.entries) {
        final exerciseName = exerciseNames[entry.key] ?? entry.key;
        migrationLogs.add(ExerciseLog(
          exerciseId: entry.key,
          exerciseName: exerciseName,
          setNumber: 1,
          reps: entry.value,
          weight: 0,
          timestamp: DateTime.now(),
        ));
      }

      if (migrationLogs.isNotEmpty) {
        final defaultTemplate = templates.firstWhere(
          (t) => t.id == defaultTemplateId,
          orElse: () => _createDefaultShoulderTemplate(l10n),
        );
        final migrationSession = WorkoutSession(
          id: 'migrated_${DateTime.now().millisecondsSinceEpoch}',
          templateId: defaultTemplate.id,
          templateName:
              '${l10n.get('shoulderWorkoutTemplate')} (${l10n.get('previousData')})',
          startTime: DateTime.now().subtract(const Duration(minutes: 30)),
          endTime: DateTime.now(),
          durationSeconds: 1800,
          logs: migrationLogs,
        );
        setState(() {
          history.insert(0, migrationSession);
        });
        await _saveHistory();
      }

      // Clear old data format after migration
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('workouts');
      _pendingOldWorkouts = {};
    }
  }

  /// Creates the default Shoulder Workout template with the 5 original exercises
  WorkoutTemplate _createDefaultShoulderTemplate(AppLocalizations l10n) {
    return WorkoutTemplate(
      id: 'default_shoulder_workout',
      name: l10n.get('shoulderWorkoutTemplate'),
      description: l10n.get('shoulderWorkoutTemplateDesc'),
      exercises: [
        TemplateExercise(
          exercise: Exercise(
            id: 'shoulderPress',
            name: l10n.get('shoulderPress'),
            description: l10n.get('shoulderPressDesc'),
            iconKey: 'arrow_upward',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'lateralRaise',
            name: l10n.get('lateralRaise'),
            description: l10n.get('lateralRaiseDesc'),
            iconKey: 'open_with',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'frontRaise',
            name: l10n.get('frontRaise'),
            description: l10n.get('frontRaiseDesc'),
            iconKey: 'arrow_forward',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'reverseFly',
            name: l10n.get('reverseFly'),
            description: l10n.get('reverseFlyDesc'),
            iconKey: 'compare_arrows',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'shrugs',
            name: l10n.get('shrugs'),
            description: l10n.get('shrugsDesc'),
            iconKey: 'keyboard_double_arrow_up',
          ),
          targetReps: 10,
          sets: 3,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workout_templates',
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workout_history',
      jsonEncode(history.map((h) => h.toJson()).toList()),
    );
  }

  void _addTemplate(WorkoutTemplate template) {
    setState(() {
      templates.add(template);
    });
    _saveTemplates();
  }

  void _updateTemplate(WorkoutTemplate template) {
    setState(() {
      final index = templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        templates[index] = template;
      }
    });
    _saveTemplates();
  }

  void _deleteTemplate(String id) {
    setState(() {
      templates.removeWhere((t) => t.id == id);
    });
    _saveTemplates();
  }

  void _addSession(WorkoutSession session) {
    setState(() {
      history.insert(0, session);
    });
    _saveHistory();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final pages = [
      TemplatesPage(
        templates: templates,
        onAddTemplate: _addTemplate,
        onUpdateTemplate: _updateTemplate,
        onDeleteTemplate: _deleteTemplate,
        onStartWorkout: (template) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutPage(
                template: template,
                onComplete: _addSession,
                history: history,
              ),
            ),
          );
        },
      ),
      HistoryPage(history: history),
      StatisticsPage(history: history),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 80,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.fitness_center, size: 28),
            selectedIcon: Icon(Icons.fitness_center, size: 28, color: Colors.amber.shade700),
            label: l10n.get('workouts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history, size: 28),
            selectedIcon: Icon(Icons.history, size: 28, color: Colors.amber.shade700),
            label: l10n.get('history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart, size: 28),
            selectedIcon: Icon(Icons.bar_chart, size: 28, color: Colors.amber.shade700),
            label: l10n.get('statistics'),
          ),
        ],
      ),
    );
  }
}

// ============== TEMPLATES PAGE ==============

class TemplatesPage extends StatelessWidget {
  final List<WorkoutTemplate> templates;
  final Function(WorkoutTemplate) onAddTemplate;
  final Function(WorkoutTemplate) onUpdateTemplate;
  final Function(String) onDeleteTemplate;
  final Function(WorkoutTemplate) onStartWorkout;

  const TemplatesPage({
    super.key,
    required this.templates,
    required this.onAddTemplate,
    required this.onUpdateTemplate,
    required this.onDeleteTemplate,
    required this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      appBar: AppBar(
        backgroundColor: Colors.amber.shade300,
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('myWorkouts'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showAboutDialog(context, l10n),
            icon: const Icon(Icons.info_outline, size: 28),
            tooltip: l10n.aboutAndDisclaimer,
          ),
        ],
      ),
      body: SafeArea(
        child: templates.isEmpty
            ? _buildEmptyState(context, l10n)
            : _buildTemplateList(context, l10n),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTemplateDialog(context, l10n),
        backgroundColor: Colors.amber.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 28),
        label: Text(
          l10n.get('newWorkout'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 80,
              color: Colors.amber.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.get('noWorkoutsYet'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.get('tapToCreateFirst'),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context, AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _TemplateCard(
            template: template,
            onTap: () => onStartWorkout(template),
            onEdit: () => _showEditTemplateDialog(context, l10n, template),
            onDelete: () => _confirmDelete(context, l10n, template),
          ),
        );
      },
    );
  }

  void _showCreateTemplateDialog(BuildContext context, AppLocalizations l10n) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorPage(
          onSave: onAddTemplate,
        ),
      ),
    );
  }

  void _showEditTemplateDialog(
      BuildContext context, AppLocalizations l10n, WorkoutTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorPage(
          template: template,
          onSave: onUpdateTemplate,
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppLocalizations l10n, WorkoutTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.get('deleteWorkout'),
          style: const TextStyle(fontSize: 22),
        ),
        content: Text(
          '${l10n.get('deleteWorkoutConfirm')} "${template.name}"?',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteTemplate(template.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.get('delete'), style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, size: 32, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.aboutAndDisclaimer,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.get('workoutTrackerDesc'),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('importantDisclaimers'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('• ${l10n.get('disclaimer1')}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('• ${l10n.get('disclaimer2')}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('• ${l10n.get('disclaimer3')}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('• ${l10n.get('disclaimer4')}', style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('yourPrivacy'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('• ${l10n.get('privacy1')}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('• ${l10n.get('privacy2')}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('• ${l10n.get('privacy3')}', style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close, style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: '${template.name}, ${template.exercises.length} ${l10n.get('exercises')}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        size: 32,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${template.exercises.length} ${l10n.get('exercises')}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit, color: Colors.blue.shade600, size: 28),
                      tooltip: l10n.get('edit'),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete, color: Colors.red.shade600, size: 28),
                      tooltip: l10n.get('delete'),
                    ),
                  ],
                ),
                if (template.description != null && template.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    template.description!,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 16),
                // Start workout button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: Text(
                      l10n.get('startWorkout'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============== TEMPLATE EDITOR PAGE ==============

class TemplateEditorPage extends StatefulWidget {
  final WorkoutTemplate? template;
  final Function(WorkoutTemplate) onSave;

  const TemplateEditorPage({
    super.key,
    this.template,
    required this.onSave,
  });

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  List<TemplateExercise> exercises = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _descController =
        TextEditingController(text: widget.template?.description ?? '');
    if (widget.template != null) {
      exercises = List.from(widget.template!.exercises);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addExercise() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int selectedIconIndex = 0;
    int targetReps = 10;
    int sets = 3;
    double targetWeight = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            l10n.get('addExercise'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    labelText: l10n.get('exerciseName'),
                    hintText: l10n.get('exerciseNameHint'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: l10n.get('exerciseDescription'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // Target sets and reps
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.get('sets'), style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (sets > 1) {
                                    setDialogState(() => sets--);
                                  }
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$sets', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () => setDialogState(() => sets++),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.get('targetReps'), style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (targetReps > 1) {
                                    setDialogState(() => targetReps--);
                                  }
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$targetReps', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () => setDialogState(() => targetReps++),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Icon picker
                Text(l10n.get('chooseIcon'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(kExerciseIconKeys.length, (index) {
                    final isSelected = index == selectedIconIndex;
                    final iconKey = kExerciseIconKeys[index];
                    final iconData =
                        kExerciseIconMap[iconKey] ?? Icons.fitness_center;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIconIndex = index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.amber.shade200 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.amber.shade600 : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(iconData, size: 24, color: Colors.amber.shade800),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.get('enterExerciseName')),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                final exercise = Exercise(
                  id: 'ex_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  iconKey: kExerciseIconKeys[selectedIconIndex],
                );
                setState(() {
                  exercises.add(TemplateExercise(
                    exercise: exercise,
                    targetReps: targetReps,
                    targetWeight: targetWeight,
                    sets: sets,
                  ));
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.get('add'), style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTemplate() {
    final l10n = AppLocalizations.of(context)!;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('enterWorkoutName')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('addAtLeastOneExercise')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final template = WorkoutTemplate(
      id: widget.template?.id ?? 'template_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      exercises: exercises,
      createdAt: widget.template?.createdAt ?? DateTime.now(),
    );

    widget.onSave(template);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.template != null;

    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      appBar: AppBar(
        backgroundColor: Colors.amber.shade300,
        title: Text(
          isEditing ? l10n.get('editWorkout') : l10n.get('newWorkout'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: Text(
              l10n.get('save'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Template name
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  labelText: l10n.get('workoutName'),
                  hintText: l10n.get('workoutNameHint'),
                  labelStyle: const TextStyle(fontSize: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(20),
                  filled: true,
                  fillColor: Colors.white,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              // Description
              TextField(
                controller: _descController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: l10n.get('descriptionOptional'),
                  labelStyle: const TextStyle(fontSize: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(20),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              // Exercises header
              Text(
                l10n.get('exercises'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Exercise list
              ...exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final templateExercise = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseListItem(
                    templateExercise: templateExercise,
                    onDelete: () {
                      setState(() {
                        exercises.removeAt(index);
                      });
                    },
                  ),
                );
              }),
              // Add exercise button
              SizedBox(
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add, size: 28),
                  label: Text(
                    l10n.get('addExercise'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade400, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseListItem extends StatelessWidget {
  final TemplateExercise templateExercise;
  final VoidCallback onDelete;

  const _ExerciseListItem({
    required this.templateExercise,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final exercise = templateExercise.exercise;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(exercise.icon, size: 28, color: Colors.amber.shade800),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${templateExercise.sets} ${l10n.get('sets')} × ${templateExercise.targetReps} ${l10n.reps}',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete, color: Colors.red.shade600, size: 28),
          ),
        ],
      ),
    );
  }
}

// ============== ACTIVE WORKOUT PAGE ==============

class ActiveWorkoutPage extends StatefulWidget {
  final WorkoutTemplate template;
  final Function(WorkoutSession) onComplete;
  final List<WorkoutSession> history;

  const ActiveWorkoutPage({
    super.key,
    required this.template,
    required this.onComplete,
    required this.history,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  late DateTime startTime;
  Timer? workoutTimer;
  int elapsedSeconds = 0;
  int currentExerciseIndex = 0;
  int currentSet = 1;
  int currentReps = 0;
  double currentWeight = 0;
  List<ExerciseLog> logs = [];
  final AudioPlayer audioPlayer = AudioPlayer();

  // Rest timer
  Timer? restTimer;
  int restSeconds = 0;
  bool isResting = false;

  // Previous best reps for each exercise
  Map<String, int> previousBestReps = {};

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    _loadPreviousBestReps();
    _startWorkoutTimer();
    _initializeCurrentExercise();
  }

  void _loadPreviousBestReps() {
    // Find the best (highest) reps for each exercise from history
    for (final session in widget.history) {
      for (final log in session.logs) {
        final currentBest = previousBestReps[log.exerciseId] ?? 0;
        if (log.reps > currentBest) {
          previousBestReps[log.exerciseId] = log.reps;
        }
      }
    }
  }

  @override
  void dispose() {
    workoutTimer?.cancel();
    restTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  void _initializeCurrentExercise() {
    if (widget.template.exercises.isNotEmpty) {
      final current = widget.template.exercises[currentExerciseIndex];
      currentReps = current.targetReps;
      currentWeight = current.targetWeight;
    }
  }

  void _startWorkoutTimer() {
    workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        elapsedSeconds++;
      });
    });
  }

  void _logSet() {
    final current = widget.template.exercises[currentExerciseIndex];
    final log = ExerciseLog(
      exerciseId: current.exercise.id,
      exerciseName: current.exercise.name,
      setNumber: currentSet,
      reps: currentReps,
      weight: currentWeight,
      timestamp: DateTime.now(),
    );
    logs.add(log);

    // Move to next set or exercise
    if (currentSet < current.sets) {
      setState(() {
        currentSet++;
      });
      _startRestTimer();
    } else if (currentExerciseIndex < widget.template.exercises.length - 1) {
      setState(() {
        currentExerciseIndex++;
        currentSet = 1;
        _initializeCurrentExercise();
      });
      _startRestTimer();
    } else {
      _finishWorkout();
    }
  }

  void _startRestTimer() {
    setState(() {
      isResting = true;
      restSeconds = 60;
    });

    restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (restSeconds > 0) {
          restSeconds--;
        } else {
          timer.cancel();
          isResting = false;
          _playBeep();
        }
      });
    });
  }

  void _skipRest() {
    restTimer?.cancel();
    setState(() {
      isResting = false;
      restSeconds = 0;
    });
  }

  Future<void> _playBeep() async {
    try {
      await audioPlayer.play(AssetSource('audio/timer_beep.wav'));
    } catch (e) {
      // Ignore audio errors
    }
  }

  void _finishWorkout() {
    workoutTimer?.cancel();
    restTimer?.cancel();

    final session = WorkoutSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      templateId: widget.template.id,
      templateName: widget.template.name,
      startTime: startTime,
      endTime: DateTime.now(),
      durationSeconds: elapsedSeconds,
      logs: logs,
    );

    widget.onComplete(session);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout completed!', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmExit() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.get('endWorkout'), style: const TextStyle(fontSize: 22)),
        content: Text(l10n.get('endWorkoutConfirm'), style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (logs.isNotEmpty) {
                _finishWorkout();
              } else {
                workoutTimer?.cancel();
                restTimer?.cancel();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.get('endNow'), style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = widget.template.exercises[currentExerciseIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.amber.shade50,
        appBar: AppBar(
          backgroundColor: Colors.amber.shade300,
          title: Text(
            widget.template.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.close, size: 28),
          ),
          actions: [
            // Workout duration timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, size: 24, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(elapsedSeconds),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: isResting ? _buildRestScreen(l10n) : _buildExerciseScreen(l10n, current),
        ),
      ),
    );
  }

  Widget _buildRestScreen(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.get('rest'),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(restSeconds),
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: restSeconds <= 10 ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: _skipRest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  l10n.get('skipRest'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseScreen(AppLocalizations l10n, TemplateExercise current) {
    final completedExerciseIds = <String>{};
    for (final exercise in widget.template.exercises) {
      final completedSets = logs
          .where((log) => log.exerciseId == exercise.exercise.id)
          .map((log) => log.setNumber)
          .toSet()
          .length;
      if (completedSets >= exercise.sets) {
        completedExerciseIds.add(exercise.exercise.id);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${l10n.get('exercise')} ${currentExerciseIndex + 1}/${widget.template.exercises.length}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Text(
                  '${l10n.get('set')} $currentSet/${current.sets}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Current exercise
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(current.exercise.icon, size: 60, color: Colors.amber.shade700),
                const SizedBox(height: 16),
                Text(
                  current.exercise.name,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                // Show previous best reps if available
                if (previousBestReps.containsKey(current.exercise.id)) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 20, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '${l10n.get('previousBest')}: ${previousBestReps[current.exercise.id]} ${l10n.reps}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (current.exercise.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    current.exercise.description!,
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Workout plan overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('workoutPlan'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.get('tapToJump'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                ...widget.template.exercises.map((exercise) {
                  final isCurrent =
                      exercise.exercise.id == current.exercise.id;
                  final isCompleted =
                      completedExerciseIds.contains(exercise.exercise.id);
                  final isAvailable = !isResting;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      button: true,
                      label: '${exercise.exercise.name}, ${exercise.sets} ${l10n.get('sets')} × ${exercise.targetReps} ${l10n.reps}',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: isAvailable
                              ? () {
                                  final newIndex = widget.template.exercises
                                      .indexOf(exercise);
                                  setState(() {
                                    currentExerciseIndex = newIndex;
                                    currentSet = 1;
                                    _initializeCurrentExercise();
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Colors.amber.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrent
                                    ? Colors.amber.shade400
                                    : Colors.grey.shade300,
                                width: isCurrent ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isCompleted
                                      ? Colors.green.shade600
                                      : Colors.grey.shade500,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.exercise.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${exercise.sets} ${l10n.get('sets')} × ${exercise.targetReps} ${l10n.reps}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade300,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      l10n.get('current'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Reps counter
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  l10n.reps,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      icon: Icons.remove,
                      color: Colors.red.shade400,
                      onPressed: () {
                        if (currentReps > 0) {
                          setState(() => currentReps--);
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade400, width: 2),
                      ),
                      child: Text(
                        '$currentReps',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 24),
                    _RoundButton(
                      icon: Icons.add,
                      color: Colors.green.shade400,
                      onPressed: () => setState(() => currentReps++),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Log set button
          SizedBox(
            height: 70,
            child: ElevatedButton.icon(
              onPressed: currentReps > 0 ? _logSet : null,
              icon: const Icon(Icons.check, size: 30),
              label: Text(
                currentExerciseIndex == widget.template.exercises.length - 1 &&
                        currentSet == current.sets
                    ? l10n.get('finishWorkout')
                    : l10n.get('logSet'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Logged sets for this exercise
          if (logs.where((l) => l.exerciseId == current.exercise.id).isNotEmpty) ...[
            Text(
              l10n.get('completedSets'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...logs
                .where((l) => l.exerciseId == current.exercise.id)
                .map((log) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              '${l10n.get('set')} ${log.setNumber}: ${log.reps} ${l10n.reps}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    )),
          ],
        ],
      ),
    );
  }
}

// ============== HISTORY PAGE ==============

class HistoryPage extends StatelessWidget {
  final List<WorkoutSession> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      appBar: AppBar(
        backgroundColor: Colors.amber.shade300,
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('workoutHistory'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.amber.shade300),
                      const SizedBox(height: 24),
                      Text(
                        l10n.get('noHistoryYet'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.get('completeWorkoutToSee'),
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final session = history[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _HistoryCard(session: session),
                  );
                },
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final WorkoutSession session;

  const _HistoryCard({required this.session});

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalReps = session.logs.fold<int>(0, (sum, log) => sum + log.reps);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 28, color: Colors.green.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.templateName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDate(session.startTime),
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.timer,
                value: _formatDuration(session.durationSeconds),
                label: l10n.get('duration'),
              ),
              _StatItem(
                icon: Icons.fitness_center,
                value: '${session.logs.length}',
                label: l10n.get('sets'),
              ),
              _StatItem(
                icon: Icons.repeat,
                value: '$totalReps',
                label: l10n.reps,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.amber.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ============== STATISTICS PAGE ==============

class StatisticsPage extends StatelessWidget {
  final List<WorkoutSession> history;

  const StatisticsPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Calculate statistics
    final totalWorkouts = history.length;
    final totalDuration = history.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final totalReps = history.fold<int>(0, (sum, s) => sum + s.logs.fold<int>(0, (s2, l) => s2 + l.reps));

    // Workouts this week
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final workoutsThisWeek = history.where((s) => s.startTime.isAfter(weekStart)).length;

    // Most common exercises
    final exerciseCounts = <String, int>{};
    for (final session in history) {
      for (final log in session.logs) {
        exerciseCounts[log.exerciseName] = (exerciseCounts[log.exerciseName] ?? 0) + log.reps;
      }
    }
    final topExercises = exerciseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      appBar: AppBar(
        backgroundColor: Colors.amber.shade300,
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('statistics'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 80, color: Colors.amber.shade300),
                      const SizedBox(height: 24),
                      Text(
                        l10n.get('noStatsYet'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.get('completeWorkoutToSee'),
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overview stats
                    Text(
                      l10n.get('overview'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.fitness_center,
                            value: '$totalWorkouts',
                            label: l10n.get('totalWorkouts'),
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today,
                            value: '$workoutsThisWeek',
                            label: l10n.get('thisWeek'),
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.timer,
                            value: '${(totalDuration / 60).round()}',
                            label: l10n.get('totalMinutes'),
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.repeat,
                            value: '$totalReps',
                            label: l10n.get('totalReps'),
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Top exercises
                    if (topExercises.isNotEmpty) ...[
                      Text(
                        l10n.get('topExercises'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ...topExercises.take(5).map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.fitness_center, color: Colors.amber.shade700, size: 28),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    '${entry.value} ${l10n.reps}',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final MaterialColor color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color.shade600),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============== REUSABLE WIDGETS ==============

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          child: Icon(icon, size: 32, color: Colors.white),
        ),
      ),
    );
  }
}
