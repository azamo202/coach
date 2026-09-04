import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/app_exception.dart';
import '../models/program_progress.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';

/// عقد تخزين مكتبة البرامج الخاصة بالمستخدم.
abstract class ProgramRepository {
  Future<List<SavedProgram>> load(String userId);

  Future<void> save(String userId, SavedProgram entry);

  Future<void> saveAll(String userId, List<SavedProgram> entries);

  Future<void> delete(String userId, String programId);
}

// ---------------------------------------------------------------------------
// تخزين محلي (يُستخدم دائماً كذاكرة مؤقتة، وكمصدر وحيد في الوضع المحلي)
// ---------------------------------------------------------------------------

class LocalProgramRepository implements ProgramRepository {
  LocalProgramRepository(this._store);

  final LocalStore _store;

  @override
  Future<List<SavedProgram>> load(String userId) async {
    final raw = _store.getJsonList(_store.libraryKey(userId));
    final entries = <SavedProgram>[];
    for (final item in raw) {
      try {
        entries.add(SavedProgram.fromJson(item));
      } catch (error) {
        debugPrint('Skipping corrupt program entry: $error');
      }
    }
    entries.sort(
      (a, b) => b.program.createdAt.compareTo(a.program.createdAt),
    );
    return entries;
  }

  @override
  Future<void> save(String userId, SavedProgram entry) async {
    final entries = await load(userId);
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      entries.insert(0, entry);
    } else {
      entries[index] = entry;
    }
    await saveAll(userId, entries);
  }

  @override
  Future<void> saveAll(String userId, List<SavedProgram> entries) async {
    final trimmed = entries.take(AppConfig.maxSavedSports).toList();
    await _store.setJsonList(
      _store.libraryKey(userId),
      trimmed.map((e) => e.toJson()).toList(),
    );
  }

  @override
  Future<void> delete(String userId, String programId) async {
    final entries = await load(userId);
    entries.removeWhere((e) => e.id == programId);
    await saveAll(userId, entries);
  }
}

// ---------------------------------------------------------------------------
// تخزين على السيرفر مع مزامنة محلية (offline-first)
// ---------------------------------------------------------------------------

class RemoteProgramRepository implements ProgramRepository {
  RemoteProgramRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalProgramRepository _cache;

  @override
  Future<List<SavedProgram>> load(String userId) async {
    try {
      final response = await _api.get('/programs');
      final raw = response['programs'];
      if (raw is! List) return _cache.load(userId);

      final entries = raw
          .whereType<Map>()
          .map(
            (e) => SavedProgram.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList()
        ..sort((a, b) => b.program.createdAt.compareTo(a.program.createdAt));

      // نحدّث الذاكرة المحلية حتى يعمل التطبيق بدون إنترنت.
      await _cache.saveAll(userId, entries);
      return entries;
    } on AppException catch (error) {
      debugPrint('Falling back to cached programs: ${error.message}');
      return _cache.load(userId);
    }
  }

  @override
  Future<void> save(String userId, SavedProgram entry) async {
    await _cache.save(userId, entry);
    try {
      await _api.put('/programs/${entry.id}', body: entry.toJson());
    } on AppException catch (error) {
      debugPrint('Program sync deferred: ${error.message}');
    }
  }

  @override
  Future<void> saveAll(String userId, List<SavedProgram> entries) async {
    await _cache.saveAll(userId, entries);
    try {
      await _api.post(
        '/programs/sync',
        body: <String, dynamic>{
          'programs': entries.map((e) => e.toJson()).toList(),
        },
      );
    } on AppException catch (error) {
      debugPrint('Bulk sync deferred: ${error.message}');
    }
  }

  @override
  Future<void> delete(String userId, String programId) async {
    await _cache.delete(userId, programId);
    try {
      await _api.delete('/programs/$programId');
    } on AppException catch (error) {
      debugPrint('Program delete sync deferred: ${error.message}');
    }
  }
}
