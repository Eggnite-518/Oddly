import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

// ── State ──────────────────────────────────────────────────────────────────

enum MirrorPhase { loading, empty, observing, ready }

class MirrorState {
  final MirrorPhase phase;
  final List<PersonaCurrent> currents;
  final int totalThoughts;
  final List<CognitivePatternStat> cognitivePatternStats;

  const MirrorState({
    this.phase = MirrorPhase.loading,
    this.currents = const [],
    this.totalThoughts = 0,
    this.cognitivePatternStats = const [],
  });

  MirrorState copyWith({
    MirrorPhase? phase,
    List<PersonaCurrent>? currents,
    int? totalThoughts,
    List<CognitivePatternStat>? cognitivePatternStats,
  }) =>
      MirrorState(
        phase: phase ?? this.phase,
        currents: currents ?? this.currents,
        totalThoughts: totalThoughts ?? this.totalThoughts,
        cognitivePatternStats:
            cognitivePatternStats ?? this.cognitivePatternStats,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class MirrorNotifier extends StateNotifier<MirrorState> {
  final AppDatabase _db = AppDatabase.instance;

  MirrorNotifier() : super(const MirrorState()) {
    _load();
  }

  Future<void> _load() async {
    final currents = await _db.getAllCurrents();
    final thoughts = await _db.getAllThoughts();
    final analyzedCount = thoughts.where((t) => t.isAnalyzed).length;
    final patternStats = await _db.getAllCognitivePatternStats();

    MirrorPhase phase;
    if (analyzedCount == 0) {
      phase = MirrorPhase.empty;
    } else if (currents.where((c) => c.strength >= 2).isEmpty) {
      phase = MirrorPhase.observing;
    } else {
      phase = MirrorPhase.ready;
    }

    state = state.copyWith(
      phase: phase,
      currents: currents,
      totalThoughts: analyzedCount,
      cognitivePatternStats: patternStats,
    );
  }

  Future<void> reload() => _load();

  Future<void> confirmCurrent(String id, bool confirmed) async {
    await _db.updateCurrentConfirmed(id, confirmed);
    await _load();
  }

  Future<void> renameCurrent(String id, String newName) async {
    await _db.updateCurrentName(id, newName);
    await _load();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final mirrorProvider =
    StateNotifierProvider<MirrorNotifier, MirrorState>(
  (_) => MirrorNotifier(),
);
