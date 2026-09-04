import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../data/models/fitness_level.dart';
import '../data/models/program_progress.dart';
import '../data/repositories/program_repository.dart';
import '../data/services/ai_program_service.dart';
import '../data/services/prompt_builder.dart';

/// يدير مكتبة الرياضات المحفوظة للمستخدم، وتوليد البرامج، وتتبّع التقدّم.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required ProgramRepository repository,
    required AiProgramService ai,
  })  : _repository = repository,
        _ai = ai;

  final ProgramRepository _repository;
  final AiProgramService _ai;

  String? _userId;
  String? _loadedUserId;
  List<SavedProgram> _entries = <SavedProgram>[];
  bool _loading = false;
  bool _generating = false;
  String? _error;
  String _generatingSport = '';

  List<SavedProgram> get entries => List.unmodifiable(_entries);
  bool get isLoading => _loading;
  bool get isGenerating => _generating;
  String get generatingSport => _generatingSport;
  String? get error => _error;
  bool get isEmpty => _entries.isEmpty;

  /// إجمالي الجلسات المكتملة عبر كل الرياضات.
  int get totalCompletedSessions =>
      _entries.fold<int>(0, (sum, e) => sum + e.progress.completedCount);

  int get totalSessions =>
      _entries.fold<int>(0, (sum, e) => sum + e.program.totalSessions);

  /// أطول سلسلة أيام متتالية عبر كل البرامج.
  int get bestStreak => _entries.isEmpty
      ? 0
      : _entries
          .map((e) => e.progress.streakDays)
          .reduce((a, b) => a > b ? a : b);

  int get sessionsThisWeek => _entries.fold<int>(
      0, (sum, e) => sum + e.progress.completedInLastDays(7),);

  double get overallRatio =>
      totalSessions == 0 ? 0 : totalCompletedSessions / totalSessions;

  SavedProgram? byId(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// آخر برنامج فُتح — يظهر كـ"استكمل تدريبك" في الرئيسية.
  SavedProgram? get activeProgram {
    if (_entries.isEmpty) return null;
    final unfinished = _entries.where((e) => !e.isComplete).toList();
    final pool = unfinished.isEmpty ? _entries : unfinished;
    pool.sort((a, b) {
      final aDate = a.progress.lastOpenedAt ?? a.program.createdAt;
      final bDate = b.progress.lastOpenedAt ?? b.program.createdAt;
      return bDate.compareTo(aDate);
    });
    return pool.first;
  }

  bool hasSport(String sport) => _entries.any(
        (e) =>
            e.program.sport.trim().toLowerCase() == sport.trim().toLowerCase(),
      );

  // ------------------------------------------------------------------
  // دورة الحياة
  // ------------------------------------------------------------------

  /// يحمّل مكتبة المستخدم مرة واحدة. مرّر [force] لإعادة التحميل من المصدر.
  Future<void> loadFor(String userId, {bool force = false}) async {
    if (!force && _loadedUserId == userId) return;
    _userId = userId;
    _loading = true;
    notifyListeners();
    try {
      _entries = await _repository.load(userId);
      _loadedUserId = userId;
    } catch (error) {
      debugPrint('Library load failed: $error');
      _entries = <SavedProgram>[];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _userId = null;
    _loadedUserId = null;
    _entries = <SavedProgram>[];
    _error = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // التوليد
  // ------------------------------------------------------------------

  /// يولّد برنامجاً جديداً ويحفظه. يُرجع البرنامج المحفوظ أو null عند الفشل.
  Future<SavedProgram?> generateProgram(ProgramRequest request) async {
    final userId = _userId;
    if (userId == null) {
      _error = AppException.unauthorized.message;
      notifyListeners();
      return null;
    }

    _generating = true;
    _generatingSport = request.sport;
    _error = null;
    notifyListeners();

    try {
      final program = await _ai.generate(request);
      final entry = SavedProgram(
        program: program,
        progress: ProgramProgress(lastOpenedAt: DateTime.now()),
      );
      _entries = <SavedProgram>[entry, ..._entries];
      await _repository.save(userId, entry);
      return entry;
    } on AppException catch (error) {
      _error = error.message;
      return null;
    } catch (error) {
      debugPrint('Program generation failed: $error');
      _error = AppException.aiFailed.message;
      return null;
    } finally {
      _generating = false;
      _generatingSport = '';
      notifyListeners();
    }
  }

  /// يعيد توليد برنامج لنفس الرياضة (مثلاً بعد تغيّر المستوى).
  Future<SavedProgram?> regenerate(
    SavedProgram entry, {
    FitnessLevel? level,
    TrainingGoal? goal,
    String notes = '',
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    await delete(entry.id);
    return generateProgram(
      ProgramRequest(
        sport: entry.program.sport,
        level: level ?? entry.program.level,
        goal: goal ?? entry.program.goal,
        notes: notes,
      ),
    );
  }

  // ------------------------------------------------------------------
  // التقدّم
  // ------------------------------------------------------------------

  Future<void> toggleSession(
    String programId,
    int weekIndex,
    int dayIndex,
  ) async {
    await _mutate(
      programId,
      (entry) => entry.copyWith(
        progress: entry.progress.toggle(weekIndex, dayIndex),
      ),
    );
  }

  Future<void> markOpened(String programId) async {
    await _mutate(
      programId,
      (entry) => entry.copyWith(progress: entry.progress.markOpened()),
      silent: true,
    );
  }

  Future<void> resetProgress(String programId) async {
    await _mutate(
      programId,
      (entry) => entry.copyWith(progress: entry.progress.reset()),
    );
  }

  Future<void> delete(String programId) async {
    final userId = _userId;
    if (userId == null) return;
    _entries = _entries.where((e) => e.id != programId).toList();
    notifyListeners();
    await _repository.delete(userId, programId);
  }

  Future<void> _mutate(
    String programId,
    SavedProgram Function(SavedProgram entry) transform, {
    bool silent = false,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final index = _entries.indexWhere((e) => e.id == programId);
    if (index == -1) return;

    final updated = transform(_entries[index]);
    _entries = List<SavedProgram>.from(_entries)..[index] = updated;
    if (!silent) notifyListeners();

    try {
      await _repository.save(userId, updated);
    } catch (error) {
      debugPrint('Progress save failed: $error');
    }
    if (silent) notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
