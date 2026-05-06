import 'package:flutter/material.dart';

/// App localizations class for multi-language support
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  /// English catalog / default exercise names → Traditional Chinese labels.
  /// Keys must match stored names in templates and logs ([kCommonExerciseNames] in main.dart) plus defaults like Shoulder Press.
  static const Map<String, String> _exerciseNameEnToZhHant = {
    'Abductor': '大腿外展',
    'Adductor': '大腿內收',
    'Ankle Eversion': '踝外翻',
    'Assisted Pull-Up': '輔助引體向上',
    'Balance': '平衡訓練',
    'Balancing on One Leg': '單腳平衡',
    'Bench Press': '槓鈴臥推',
    'Bent-Over Row': '俯身划船',
    'Bicep Curl': '二頭彎舉',
    'Bicycle Crunch': '空中腳踏車捲腹',
    'Bird Dog': '鳥狗式',
    'Calf Raise': '小腿提踵',
    'Cable Fly': '滑輪飛鳥',
    'Chest Fly': '胸飛鳥',
    'Chin-Up': '反手引體向上',
    'Chest Press': '胸推',
    'Clamshell': '蛤蜊式',
    'Crunch': '捲腹',
    'Dead Bug': '死蟲式',
    'Deadlift': '硬舉',
    'Dumbbell Fly': '啞鈴飛鳥',
    'Face Pull': '臉拉',
    'Farmer\'s Carry': '農夫走路',
    'Farmer\'s Carries': '農夫走路',
    'Front Raise': '前平舉',
    'Goblet Squat': '高腳杯深蹲',
    'Hack Squat': '哈克深蹲',
    'Hammer Curl': '錘式彎舉',
    'High Row': '高位划船',
    'Hip Thrust': '臀推',
    'Incline Bench Press': '上斜臥推',
    'Lat Pulldown': '滑輪下拉',
    'Lateral Raise': '側平舉',
    'Leg Curl': '腿彎舉',
    'Leg Extension': '腿伸展',
    'Leg Press': '腿推',
    'Leg Raise': '抬腿',
    'Lunge': '弓步',
    'Lying Leg Curl': '俯臥腿彎舉',
    'Overhead Press': '過頭推舉',
    'Overhead Tricep Extension': '過頭三頭伸展',
    'Pec Deck': '蝴蝶機夾胸',
    'Plank': '棒式',
    'Preacher Curl': '牧師椅彎舉',
    'Pull-Up': '引體向上',
    'Push-Up': '伏地挺身',
    'Rear Delt Fly': '後三角飛鳥',
    'Reverse Fly': '反向飛鳥',
    'Row': '划船',
    'Romanian Deadlift': '羅馬尼亞硬舉',
    'Seated Calf Raise': '坐姿小腿提踵',
    'Seated Row': '坐姿划船',
    'Side Plank': '側棒式',
    'Single-Arm Row': '單臂划船',
    'Skullcrusher': '碎顱式',
    'Skullcrusher (Single Arm)': '碎顱式（單臂）',
    'Squat': '深蹲',
    'T-Bar Row': 'T槓划船',
    'Tibialis Posterior': '脛後肌訓練',
    'Toe Curl': '捲趾',
    'Toe Raise': '抬趾',
    'Tricep Dip': '三頭撐體',
    'Tricep Pushdown': '三頭下壓',
    'Upright Row': '直立划船',
    'Walking Lunge': '行走弓步',
    'Shoulder Press': '肩推',
    'Shrugs': '聳肩',
  };

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ), // Chinese Traditional
  ];

  // Get localized strings based on locale
  late final Map<String, String> _localizedStrings = _getLocalizedStrings();

  Map<String, String> _getLocalizedStrings() {
    if (locale.scriptCode == 'Hant' || locale.languageCode == 'zh') {
      return _zhHantStrings;
    }
    return _enStrings;
  }

  String get(String key) => _localizedStrings[key] ?? key;

  bool get _isZhLocale =>
      locale.scriptCode == 'Hant' || locale.languageCode == 'zh';

  /// Display label for a stored exercise name (templates, logs). Known English names map to zh-Hant when locale is Chinese; other strings are unchanged.
  String localizeExerciseName(String storedName) {
    if (!_isZhLocale) return storedName;
    return _exerciseNameEnToZhHant[storedName] ?? storedName;
  }

  /// English workout template titles (as stored) → zh-Hant for display when locale is Chinese.
  static const Map<String, String> _workoutTemplateNameEnToZhHant = {
    // Bundled defaults (saved with English app locale)
    'Beginner Upper Body Day': '入門上半身日',
    'Beginner Legs Day': '入門腿部日',
    'Shoulder Workout (Previous data)': '肩部運動（舊資料）',
    // Common / user templates
    'Upper Body (Home) [Dumbbells]': '上半身（居家）啞鈴',
    'Upper body (Home) Dumbbells': '上半身（居家）啞鈴',
    'Leg Day': '腿部日',
    'Upper Body @ Gym': '上半身（健身房）',
    'Rehab': '復健',
    'Full Body @ Gym': '全身（健身房）',
    'Full Body @ Gym (Soft)': '全身（健身房・輕量）',
    'Full Body @ Taiwan Gym': '全身（台灣健身房）',
  };

  String localizeWorkoutTemplateName(String storedName) {
    if (!_isZhLocale) return storedName;
    return _workoutTemplateNameEnToZhHant[storedName] ?? storedName;
  }

  // English strings
  static const Map<String, String> _enStrings = {
    // App title
    'appTitle': 'Workout Tracker',
    'shoulderWorkout': 'Shoulder Workout',

    // Navigation
    'workouts': 'Workouts',
    'history': 'History',
    'statistics': 'Statistics',

    // Templates page
    'myWorkouts': 'My Workouts',
    'noWorkoutsYet': 'No workouts yet',
    'tapToCreateFirst':
        'Tap the button below to create your first workout template',
    'newWorkout': 'New Workout',
    'startWorkout': 'Start Workout',
    'deleteWorkout': 'Delete Workout',
    'deleteWorkoutConfirm': 'Are you sure you want to delete',
    'editWorkout': 'Edit Workout',

    // Template editor
    'workoutName': 'Workout Name',
    'workoutNameHint': 'e.g., Upper Body, Leg Day',
    'descriptionOptional': 'Description (optional)',
    'exercises': 'Exercises',
    'addAtLeastOneExercise': 'Please add at least one exercise',
    'enterWorkoutName': 'Please enter a workout name',

    // Exercise
    'addExercise': 'Add Exercise',
    'editExercise': 'Edit Exercise',
    'deleteExercise': 'Delete Exercise',
    'exerciseName': 'Exercise Name',
    'exerciseDescription': 'Description (optional)',
    'exerciseNameHint': 'e.g., Bicep Curl',
    'exerciseDescHint': 'e.g., Stand on band, curl arms up',
    'enterExerciseName': 'Please enter an exercise name',
    'exercise': 'Exercise',
    'sets': 'Sets',
    'set': 'Set',
    'targetReps': 'Target Reps',
    'chooseIcon': 'Choose Icon:',
    'suggestions': 'Suggestions',
    'durationBasedExercise': 'Hold by time (not reps)',
    'durationBasedExerciseDesc':
        'Log how long you held each set (e.g. plank, balance). Enter time like 0:30 or 1:00.',
    'holdTime': 'Hold time',
    'durationHint': 'e.g. 0:30 or 1:00',
    'invalidDuration': 'Enter a valid time (e.g. 0:30, 1:00, or 90 seconds)',
    'previousBestDuration': 'Previous best hold',
    'restBetweenSetsTitle': 'Rest between sets',
    'warmup': 'Warm-up',
    'warmupOff': 'Off',
    'warmupBeforeHold': 'Warm-up before hold',
    'warmupBeforeHoldSubtitle':
        'Counts down before the first timed hold starts — time to settle in.',
    'warmupSubtitle': 'Hold starts when this reaches zero',
    'holdTimeRemaining': 'Time left — stay strong',
    'restBetweenSetsStretchHint':
        'Stretches and mobility moves often need little or no rest. Pick what feels right.',
    'restOptionDefault': 'Use workout default',
    'restOptionDefaultSub': 'Same as Rest timer in Settings ({time})',
    'restOptionNoRest': 'No rest',
    'restOptionNoRestSub': 'Go to the next set right away',
    'restOptionCustom': 'Custom rest time',
    'restOptionCustomSub': 'Set how long to rest after each set (tap − / +)',
    'restHintDefault': 'Rest: same as settings ({time})',
    'restHintNone': 'Rest: none — next set right away',
    'restHintCustom': 'Rest: {time} after each set',

    // Active workout
    'endWorkout': 'End Workout?',
    'endWorkoutConfirm': 'Your progress will be saved. End workout now?',
    'endNow': 'End Now',
    'rest': 'Rest',
    'skipRest': 'Skip Rest',
    'pause': 'Pause',
    'resumeWorkout': 'Resume Workout',
    'pauseRestTimer': 'Pause rest',
    'resumeRestTimer': 'Resume rest',
    'setsRemainingLabel': 'sets remaining',
    'logSet': 'Log Set',
    'nextExercise': 'Next Exercise',
    'finishWorkout': 'Finish Workout',
    'draftResumeTitle': 'Resume workout?',
    'draftResumeBody':
        'You have an unfinished "{name}" from {time}. Resume where you left off?',
    'draftResume': 'Resume',
    'draftDiscard': 'Discard',
    'draftConflictTitle': 'Unfinished workout',
    'draftConflictBody':
        'You already have a workout in progress. Resume it, or discard it to start this one.',
    'draftDiscardAndStart': 'Discard & start new',
    'completedSets': 'Completed Sets',
    'workoutComplete': 'Workout Complete!',
    'addExerciseToWorkout': 'Add Exercise',
    'whereToAddExercise': 'Add this exercise to:',
    'addToThisWorkoutOnly': 'This workout only',
    'addToWorkoutTemplate': 'Workout template (save for future)',

    // History
    'workoutHistory': 'Workout History',
    'noHistoryYet': 'No workout history yet',
    'deleteFromHistory': 'Delete from history',
    'deleteWorkoutFromHistoryConfirm':
        'Remove this workout from history? Statistics will update. This cannot be undone.',
    'remove': 'Remove',
    'completeWorkoutToSee':
        'Complete a workout to see your history and statistics',
    'duration': 'Duration',

    // Statistics
    'noStatsYet': 'No statistics yet',
    'overview': 'Overview',
    'totalWorkouts': 'Total Workouts',
    'thisWeek': 'This Week',
    'totalMinutes': 'Total Minutes',
    'totalReps': 'Total Reps',
    'topExercises': 'Top Exercises',

    // Common actions
    'save': 'Save',
    'add': 'Add',
    'delete': 'Delete',
    'edit': 'Edit',
    'close': 'Close',
    'ok': 'OK',
    'cancel': 'Cancel',
    'deleteAll': 'Delete All',

    // Band indicator
    'yellowBand': 'Yellow Band (Lightest)',
    'bandDescription':
        'Current resistance band: Yellow, which is the lightest resistance level',

    // Exercises
    'selectExercise': 'Select Exercise:',
    'shoulderPress': 'Shoulder Press',
    'shoulderPressDesc': 'Stand on band, press handles overhead',
    'lateralRaise': 'Lateral Raise',
    'lateralRaiseDesc': 'Stand on band, raise arms to sides',
    'frontRaise': 'Front Raise',
    'frontRaiseDesc': 'Stand on band, raise arms forward',
    'reverseFly': 'Reverse Fly',
    'reverseFlyDesc': 'Bend forward, pull band apart',
    'shrugs': 'Shrugs',
    'shrugsDesc': 'Stand on band, lift shoulders up',

    // Rep counter
    'howManyReps': 'How many reps?',
    'reps': 'reps',
    'lastReps': 'Last:',
    'decreaseReps': 'Decrease reps',
    'increaseReps': 'Increase reps',

    // Timer
    'restTimer': 'Rest Timer',
    'restTimeOver': 'Rest Time Over!',
    'timeForNextSet': 'Time to do your next set!',
    'secondsRemaining': 'seconds remaining',
    'timerStopped': 'Timer stopped',
    'saveAndStartTimer': 'Save & Start Rest Timer',
    'stopTimer': 'Stop Timer',

    // Messages
    'saved': 'Saved',
    'savedWithReps': 'Saved: {exercise} - {reps} reps',
    'restTimerStarted': 'Rest timer started for 1 minute.',
    'noDataToExport': 'No workout data to export yet!',
    'copiedToClipboard': 'Copied to clipboard!',
    'sharingData': 'Sharing workout data',
    'allDataDeleted': 'All data deleted',

    // About dialog
    'aboutAndDisclaimer': 'About & Disclaimer',
    'workoutTrackerDesc':
        'A simple app to track your workouts and measure your progress.',

    // Disclaimers
    'importantDisclaimers': 'Important Disclaimers',
    'disclaimer1': 'This app is for informational and tracking purposes only.',
    'disclaimer2':
        'Consult a healthcare professional before starting any exercise program.',
    'disclaimer3':
        'Not intended to diagnose, treat, cure, or prevent any medical condition.',
    'disclaimer4': 'Use at your own risk.',

    // Privacy
    'yourPrivacy': 'Your Privacy',
    'privacy1': 'All data is stored locally on your device',
    'privacy2': 'We do not collect, transmit, or sell your data',
    'privacy3': 'You can export or delete your data anytime',

    // Open Source
    'openSource': 'Open Source',
    'licensedUnderMIT': 'Licensed under MIT License',
    'version': 'Version',
    'viewLicenses': 'View Open Source Licenses',

    // Contact
    'contact': 'Contact',

    // Delete dialog
    'deleteAllData': 'Delete All Data?',
    'deleteWarning':
        'This will delete all your saved workout data.\n\nThis cannot be undone!',

    // Accessibility
    'aboutAndDisclaimerButton': 'About and Disclaimer',
    'exportDataButton': 'Export workout data',
    'deleteDataButton': 'Delete all workout data',
    'currentlySelected': 'currently selected',
    'lastRecorded': 'last recorded',
    'selected': 'Selected',
    'saveButtonDisabled': 'Save button disabled, add reps first',

    // Exercise management
    'manageExercises': 'Manage Exercises',
    'customExercise': 'Custom',
    'defaultExercise': 'Default',
    'confirmDeleteExercise': 'Delete this exercise?',
    'deleteExerciseWarning': 'This will remove the exercise from your list.',
    'exerciseAdded': 'Exercise added',
    'exerciseUpdated': 'Exercise updated',
    'exerciseDeleted': 'Exercise deleted',
    'yourExercises': 'Your Exercises',
    'tapToSelect': 'Tap an exercise to select it',
    'swipeToDelete': 'Swipe left to delete custom exercises',
    'noExercises': 'No exercises yet. Add your first one!',
    'previousBest': 'Previous best',
    'pastHistory': 'Past history',
    'noPastWorkoutsForExercise': 'No past workouts for this exercise',
    'workoutOn': 'Workout on',
    'workoutPlan': 'Workout Plan',
    'current': 'Current',
    'tapToJump': 'Tap an exercise to jump to it',
    'longPressToReorder': 'Long-press and drag to reorder',
    'shoulderWorkoutTemplate': 'Shoulder Workout',
    'shoulderWorkoutTemplateDesc': 'Resistance Band - 5 shoulder exercises',
    'fiveShoulderExercises': '5 shoulder exercises',
    'beginnerUpperBodyDay': 'Beginner Upper Body Day',
    'beginnerUpperBodyDayDesc': 'Chest, shoulders, back, and arms — 6 exercises, 3×10',
    'beginnerLegsDay': 'Beginner Legs Day',
    'beginnerLegsDayDesc': 'Lower body starter — 4 exercises, 3×10',
    'previousData': 'Previous data',

    // Settings
    'settings': 'Settings',
    'timerBeepVolume': 'Timer beep volume',
    'timerBeepVolumeDesc':
        'Applies to rest, warm-up, and hold countdown sounds. 0 is silent.',
    'previewTimerBeep': 'Preview beep',
    'appearance': 'Appearance',
    'theme': 'Theme',
    'systemDefault': 'System default',
    'lightMode': 'Light',
    'darkMode': 'Dark',
    'themeDescription': 'Choose how the app looks',
    'about': 'About',

    // Rest timer
    'defaultRestTimer': 'Default rest time',
    'defaultRestTimerDesc': 'Rest time after each set. Tap ±30 to change.',
    'add30Seconds': '+ 30 sec',
    'subtract30Seconds': '− 30 sec',
    'viewWorkoutPlan': 'View workout plan',
    'backToRestTimer': 'Back to rest timer',
    'restTimerWorkout': 'Workout',

    // Weight tracking
    'weight': 'Weight (kg)',
    'weightLbs': 'Weight (lbs)',
    'weightShort': 'kg',
    'weightShortLbs': 'lbs',
    'minusWeight': 'assisted',
    'minusWeightKg': 'Assisted weight (kg)',
    'minusWeightLbs': 'Assisted weight (lbs)',
    'weightUnit': 'Weight unit',
    'weightUnitDesc': 'Default unit for weight',
    'noWeight': 'No weight',
    'tapToEdit': 'Tap to type',
    'enterValue': 'Enter Value',

    // Progress Chart
    'progressChart': 'Progress Chart',
    'repsOverTime': 'Reps',
    'weightOverTime': 'Weight',
    'bothOverTime': 'Both',
    'estimated1RM': 'Est. 1RM',
    'fromSet': 'From set',
    'noDataForExercise': 'No data yet for this exercise',
    'date': 'Date',
    'allExercises': 'All Exercises',

    // Data Backup
    'dataBackup': 'Data Backup',
    'exportData': 'Export Data',
    'exportDataDesc': 'Save your workout data to a file',
    'importData': 'Import Data',
    'importDataDesc': 'Restore data from a backup file',
    'exportSuccess': 'Data exported successfully!',
    'exportFailed': 'Failed to export data',
    'importSuccess': 'Data imported successfully!',
    'importFailed': 'Failed to import data',
    'importWarning': 'Warning: This will replace your current data',
    'confirmImport': 'Import and Replace',
    'invalidBackupFile': 'Invalid backup file',
    'backupFileShared': 'Backup file ready to share',
  };

  // Chinese Traditional strings
  static const Map<String, String> _zhHantStrings = {
    // App title
    'appTitle': '運動追蹤器',
    'shoulderWorkout': '肩部運動',

    // Navigation
    'workouts': '運動',
    'history': '歷史',
    'statistics': '統計',

    // Templates page
    'myWorkouts': '我的運動',
    'noWorkoutsYet': '還沒有運動',
    'tapToCreateFirst': '點擊下方按鈕建立您的第一個運動模板',
    'newWorkout': '新運動',
    'startWorkout': '開始運動',
    'deleteWorkout': '刪除運動',
    'deleteWorkoutConfirm': '確定要刪除',
    'editWorkout': '編輯運動',

    // Template editor
    'workoutName': '運動名稱',
    'workoutNameHint': '例如：上半身、腿部訓練',
    'descriptionOptional': '說明（選填）',
    'exercises': '動作',
    'addAtLeastOneExercise': '請至少新增一個動作',
    'enterWorkoutName': '請輸入運動名稱',

    // Exercise
    'addExercise': '新增動作',
    'editExercise': '編輯動作',
    'deleteExercise': '刪除動作',
    'exerciseName': '動作名稱',
    'exerciseDescription': '說明（選填）',
    'exerciseNameHint': '例如：二頭彎舉',
    'exerciseDescHint': '例如：站在彈力帶上，手臂向上彎曲',
    'enterExerciseName': '請輸入動作名稱',
    'exercise': '動作',
    'sets': '組',
    'set': '組',
    'targetReps': '目標次數',
    'chooseIcon': '選擇圖示：',
    'suggestions': '建議',
    'durationBasedExercise': '以時間計（非次數）',
    'durationBasedExerciseDesc':
        '記錄每組維持多久（如棒式、平衡）。時間可輸入 0:30 或 1:00。',
    'holdTime': '維持時間',
    'durationHint': '例如 0:30 或 1:00',
    'invalidDuration': '請輸入有效時間（如 0:30、1:00 或 90 秒）',
    'previousBestDuration': '上次最佳維持',
    'restBetweenSetsTitle': '組間休息',
    'warmup': '暖身',
    'warmupOff': '關閉',
    'warmupBeforeHold': '維持前暖身',
    'warmupBeforeHoldSubtitle':
        '第一次計時開始前會先倒數暖身時間，可先站穩準備。',
    'warmupSubtitle': '倒數為零後開始計時維持',
    'holdTimeRemaining': '剩餘時間 — 再堅持一下',
    'restBetweenSetsStretchHint':
        '伸展與活動度動作常不需要長休息，可依身體感受選擇。',
    'restOptionDefault': '使用預設休息時間',
    'restOptionDefaultSub': '與「設定」中的休息計時相同（{time}）',
    'restOptionNoRest': '不休息',
    'restOptionNoRestSub': '做完一組後直接下一組（適合伸展）',
    'restOptionCustom': '自訂休息時間',
    'restOptionCustomSub': '每組之間休息多久（按 −／＋調整）',
    'restHintDefault': '休息：與設定相同（{time}）',
    'restHintNone': '休息：無 — 直接下一組',
    'restHintCustom': '休息：每組之間 {time}',

    // Active workout
    'endWorkout': '結束運動？',
    'endWorkoutConfirm': '您的進度將被儲存。確定要結束嗎？',
    'endNow': '立即結束',
    'rest': '休息',
    'skipRest': '跳過休息',
    'pause': '暫停',
    'resumeWorkout': '繼續運動',
    'pauseRestTimer': '暫停休息',
    'resumeRestTimer': '繼續休息',
    'setsRemainingLabel': '組剩餘',
    'logSet': '記錄這組',
    'nextExercise': '下一個動作',
    'finishWorkout': '完成運動',
    'draftResumeTitle': '要繼續運動嗎？',
    'draftResumeBody': '您有未完成的「{name}」（{time}）。要從上次進度繼續嗎？',
    'draftResume': '繼續',
    'draftDiscard': '捨棄',
    'draftConflictTitle': '有未完成的運動',
    'draftConflictBody': '您已有進行中的運動。請繼續該次，或捨棄後再開始這個。',
    'draftDiscardAndStart': '捨棄並開始新的',
    'completedSets': '已完成的組數',
    'workoutComplete': '運動完成！',
    'addExerciseToWorkout': '新增動作',
    'whereToAddExercise': '要加入哪裡？',
    'addToThisWorkoutOnly': '僅這次運動',
    'addToWorkoutTemplate': '加入運動範本（之後也可用）',

    // History
    'workoutHistory': '運動歷史',
    'noHistoryYet': '還沒有運動歷史',
    'deleteFromHistory': '從歷史刪除',
    'deleteWorkoutFromHistoryConfirm': '確定要從歷史中移除此筆運動？統計將會更新，且無法復原。',
    'remove': '移除',
    'completeWorkoutToSee': '完成運動後即可查看歷史和統計',
    'duration': '時長',

    // Statistics
    'noStatsYet': '還沒有統計資料',
    'overview': '總覽',
    'totalWorkouts': '總運動次數',
    'thisWeek': '本週',
    'totalMinutes': '總分鐘數',
    'totalReps': '總次數',
    'topExercises': '熱門動作',

    // Common actions
    'save': '儲存',
    'add': '新增',
    'delete': '刪除',
    'edit': '編輯',
    'close': '關閉',
    'ok': '確定',
    'cancel': '取消',
    'deleteAll': '全部刪除',

    // Band indicator
    'yellowBand': '黃色彈力帶（最輕）',
    'bandDescription': '目前使用的彈力帶：黃色，阻力最輕',

    // Exercises
    'selectExercise': '選擇運動：',
    'shoulderPress': '肩推',
    'shoulderPressDesc': '站在彈力帶上，將把手往頭頂推',
    'lateralRaise': '側平舉',
    'lateralRaiseDesc': '站在彈力帶上，手臂向兩側舉起',
    'frontRaise': '前平舉',
    'frontRaiseDesc': '站在彈力帶上，手臂向前舉起',
    'reverseFly': '反向飛鳥',
    'reverseFlyDesc': '身體前傾，將彈力帶向兩側拉開',
    'shrugs': '聳肩',
    'shrugsDesc': '站在彈力帶上，將肩膀向上提起',

    // Rep counter
    'howManyReps': '做了幾下？',
    'reps': '下',
    'lastReps': '上次：',
    'decreaseReps': '減少次數',
    'increaseReps': '增加次數',

    // Timer
    'restTimer': '休息計時器',
    'restTimeOver': '休息時間結束！',
    'timeForNextSet': '開始下一組吧！',
    'secondsRemaining': '秒剩餘',
    'timerStopped': '計時器已停止',
    'saveAndStartTimer': '儲存並開始休息計時',
    'stopTimer': '停止計時',

    // Messages
    'saved': '已儲存',
    'savedWithReps': '已儲存：{exercise} - {reps} 下',
    'restTimerStarted': '休息計時器已開始，時間為 1 分鐘。',
    'noDataToExport': '目前沒有運動資料可以匯出！',
    'copiedToClipboard': '已複製到剪貼簿！',
    'sharingData': '正在分享運動資料',
    'allDataDeleted': '所有資料已刪除',

    // About dialog
    'aboutAndDisclaimer': '關於與免責聲明',
    'workoutTrackerDesc': '一款簡單的運動追蹤應用程式，幫助您記錄並追蹤進度。',

    // Disclaimers
    'importantDisclaimers': '重要聲明',
    'disclaimer1': '本應用程式僅供資訊和追蹤用途。',
    'disclaimer2': '開始任何運動計畫前，請諮詢醫療專業人員。',
    'disclaimer3': '本應用程式不用於診斷、治療、治癒或預防任何醫療狀況。',
    'disclaimer4': '使用風險自負。',

    // Privacy
    'yourPrivacy': '您的隱私',
    'privacy1': '所有資料都儲存在您的裝置上',
    'privacy2': '我們不會收集、傳輸或出售您的資料',
    'privacy3': '您可以隨時匯出或刪除您的資料',

    // Open Source
    'openSource': '開源軟體',
    'licensedUnderMIT': '採用 MIT 授權條款',
    'version': '版本',
    'viewLicenses': '檢視開源授權',

    // Contact
    'contact': '聯絡方式',

    // Delete dialog
    'deleteAllData': '刪除所有資料？',
    'deleteWarning': '這將刪除您所有儲存的運動資料。\n\n此操作無法復原！',

    // Accessibility
    'aboutAndDisclaimerButton': '關於與免責聲明',
    'exportDataButton': '匯出運動資料',
    'deleteDataButton': '刪除所有運動資料',
    'currentlySelected': '目前選擇',
    'lastRecorded': '上次記錄',
    'selected': '已選擇',
    'saveButtonDisabled': '儲存按鈕已停用，請先新增次數',

    // Exercise management
    'manageExercises': '管理動作',
    'customExercise': '自訂',
    'defaultExercise': '預設',
    'confirmDeleteExercise': '確定刪除這個動作？',
    'deleteExerciseWarning': '這將從您的清單中移除這個動作。',
    'exerciseAdded': '動作已新增',
    'exerciseUpdated': '動作已更新',
    'exerciseDeleted': '動作已刪除',
    'yourExercises': '您的動作',
    'tapToSelect': '點擊動作以選擇',
    'swipeToDelete': '向左滑動以刪除自訂動作',
    'noExercises': '還沒有動作。新增您的第一個吧！',
    'previousBest': '上次最佳',
    'pastHistory': '過去紀錄',
    'noPastWorkoutsForExercise': '此動作尚無過往運動紀錄',
    'workoutOn': '運動日期',
    'workoutPlan': '運動計畫',
    'current': '目前',
    'tapToJump': '點擊動作即可跳轉',
    'longPressToReorder': '長按並拖動以調整順序',
    'shoulderWorkoutTemplate': '肩部運動',
    'shoulderWorkoutTemplateDesc': '彈力帶 - 5 個肩部動作',
    'fiveShoulderExercises': '5 個肩部動作',
    'beginnerUpperBodyDay': '入門上半身日',
    'beginnerUpperBodyDayDesc': '胸、肩、背與手臂 — 6 個動作，各 3 組 × 10 下',
    'beginnerLegsDay': '入門腿部日',
    'beginnerLegsDayDesc': '下肢入門 — 4 個動作，各 3 組 × 10 下',
    'previousData': '舊資料',

    // Settings
    'settings': '設定',
    'timerBeepVolume': '計時提示音量',
    'timerBeepVolumeDesc':
        '適用於休息、暖身與維持倒數提示音。設為 0 則靜音。',
    'previewTimerBeep': '試聽提示音',
    'appearance': '外觀',
    'theme': '主題',
    'systemDefault': '跟隨系統',
    'lightMode': '淺色',
    'darkMode': '深色',
    'themeDescription': '選擇應用程式外觀',
    'about': '關於',

    // Rest timer
    'defaultRestTimer': '預設休息時間',
    'defaultRestTimerDesc': '每組後的休息時間。點擊 ±30 可調整。',
    'add30Seconds': '+ 30 秒',
    'subtract30Seconds': '− 30 秒',
    'viewWorkoutPlan': '查看運動計畫',
    'backToRestTimer': '返回休息計時',
    'restTimerWorkout': '運動',

    // Progress Chart
    // Weight tracking
    'weight': '重量 (公斤)',
    'weightLbs': '重量 (磅)',
    'weightShort': '公斤',
    'weightShortLbs': '磅',
    'minusWeight': '輔助',
    'minusWeightKg': '輔助重量 (公斤)',
    'minusWeightLbs': '輔助重量 (磅)',
    'weightUnit': '重量單位',
    'weightUnitDesc': '重量的預設單位',
    'noWeight': '無重量',
    'tapToEdit': '點擊輸入',
    'enterValue': '輸入數值',

    'progressChart': '進度圖表',
    'repsOverTime': '次數',
    'weightOverTime': '重量',
    'bothOverTime': '兩者',
    'estimated1RM': '預估1RM',
    'fromSet': '來自',
    'noDataForExercise': '此動作暫無資料',
    'date': '日期',
    'allExercises': '所有動作',

    // Data Backup
    'dataBackup': '資料備份',
    'exportData': '匯出資料',
    'exportDataDesc': '將運動資料儲存到檔案',
    'importData': '匯入資料',
    'importDataDesc': '從備份檔案還原資料',
    'exportSuccess': '資料匯出成功！',
    'exportFailed': '資料匯出失敗',
    'importSuccess': '資料匯入成功！',
    'importFailed': '資料匯入失敗',
    'importWarning': '警告：這將會取代您目前的資料',
    'confirmImport': '匯入並取代',
    'invalidBackupFile': '無效的備份檔案',
    'backupFileShared': '備份檔案已準備好分享',
  };

  // Convenience getters for common strings
  String get appTitle => get('appTitle');
  String get shoulderWorkout => get('shoulderWorkout');
  String get yellowBand => get('yellowBand');
  String get selectExercise => get('selectExercise');
  String get howManyReps => get('howManyReps');
  String get reps => get('reps');
  String get saveAndStartTimer => get('saveAndStartTimer');
  String get stopTimer => get('stopTimer');
  String get restTimer => get('restTimer');
  String get restTimeOver => get('restTimeOver');
  String get timeForNextSet => get('timeForNextSet');
  String get aboutAndDisclaimer => get('aboutAndDisclaimer');
  String get close => get('close');
  String get ok => get('ok');
  String get cancel => get('cancel');
  String get deleteAll => get('deleteAll');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
