import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// ── Data models ────────────────────────────────────────────────────────────

class Thought {
  final int? id;
  final String content;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? weather;
  final int? temperature;
  final List<String> emotionTags;
  final bool isAnalyzed;

  const Thought({
    this.id,
    required this.content,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.locationName,
    this.weather,
    this.temperature,
    this.emotionTags = const [],
    this.isAnalyzed = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName,
        'weather': weather,
        'temperature': temperature,
        'emotion_tags': emotionTags.join(','),
        'is_analyzed': isAnalyzed ? 1 : 0,
      };

  factory Thought.fromMap(Map<String, dynamic> m) => Thought(
        id: m['id'] as int,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        latitude: m['latitude'] as double?,
        longitude: m['longitude'] as double?,
        locationName: m['location_name'] as String?,
        weather: m['weather'] as String?,
        temperature: m['temperature'] as int?,
        emotionTags: (m['emotion_tags'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        isAnalyzed: (m['is_analyzed'] as int) == 1,
      );
}

class AiConversation {
  final int? id;
  final int thoughtId;
  final int round;
  final String question;
  final String? answer;
  final bool wasSkipped;
  final DateTime createdAt;

  const AiConversation({
    this.id,
    required this.thoughtId,
    required this.round,
    required this.question,
    this.answer,
    this.wasSkipped = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'thought_id': thoughtId,
        'round': round,
        'question': question,
        'answer': answer,
        'was_skipped': wasSkipped ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory AiConversation.fromMap(Map<String, dynamic> m) => AiConversation(
        id: m['id'] as int,
        thoughtId: m['thought_id'] as int,
        round: m['round'] as int,
        question: m['question'] as String,
        answer: m['answer'] as String?,
        wasSkipped: (m['was_skipped'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class InsightCard {
  final int? id;
  final int thoughtId;
  final String interpretation;
  final String psychologyTheory;
  final String psychologyExplanation;
  final List<String> actionGuide;
  final String corePattern;
  final DateTime createdAt;
  // 视角索引：0 = 主视角，1/2 = 备选视角
  final int perspectiveIndex;
  // 仅在 perspectiveIndex == 0 时有意义，记录 AI 推荐的后续框架顺序
  final List<String> recommendedFrameworks;

  // 仅在 perspectiveIndex == 0 时有意义，记录本条想法检测到的思维惯性
  final List<String> cognitivePatterns;

  const InsightCard({
    this.id,
    required this.thoughtId,
    required this.interpretation,
    required this.psychologyTheory,
    required this.psychologyExplanation,
    required this.actionGuide,
    required this.corePattern,
    required this.createdAt,
    this.perspectiveIndex = 0,
    this.recommendedFrameworks = const [],
    this.cognitivePatterns = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'thought_id': thoughtId,
        'interpretation': interpretation,
        'psychology_theory': psychologyTheory,
        'psychology_explanation': psychologyExplanation,
        'action_guide': actionGuide.join('|||'),
        'core_pattern': corePattern,
        'created_at': createdAt.toIso8601String(),
        'perspective_index': perspectiveIndex,
        'recommended_frameworks': recommendedFrameworks.join(','),
        'cognitive_patterns': cognitivePatterns.join(','),
      };

  factory InsightCard.fromMap(Map<String, dynamic> m) => InsightCard(
        id: m['id'] as int,
        thoughtId: m['thought_id'] as int,
        interpretation: m['interpretation'] as String,
        psychologyTheory: m['psychology_theory'] as String,
        psychologyExplanation: m['psychology_explanation'] as String,
        actionGuide: (m['action_guide'] as String)
            .split('|||')
            .where((s) => s.isNotEmpty)
            .toList(),
        corePattern: m['core_pattern'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
        perspectiveIndex: m['perspective_index'] as int? ?? 0,
        recommendedFrameworks: (m['recommended_frameworks'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        cognitivePatterns: (m['cognitive_patterns'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

// ── PersonaCurrent ──────────────────────────────────────────────────────────

class PersonaCurrent {
  final String id;
  final String name;
  final String description;
  final int strength;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final List<String> linkedTheories;
  final List<String> linkedEmotions;
  final List<int> thoughtIds;
  // null = 未确认, true = 用户认可, false = 用户否定
  final bool? confirmed;

  const PersonaCurrent({
    required this.id,
    required this.name,
    required this.description,
    required this.strength,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.linkedTheories,
    required this.linkedEmotions,
    required this.thoughtIds,
    this.confirmed,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'strength': strength,
        'first_seen_at': firstSeenAt.toIso8601String(),
        'last_seen_at': lastSeenAt.toIso8601String(),
        'linked_theories': linkedTheories.join(','),
        'linked_emotions': linkedEmotions.join(','),
        'thought_ids': thoughtIds.join(','),
        'confirmed': confirmed == null ? null : (confirmed! ? 1 : 0),
      };

  factory PersonaCurrent.fromMap(Map<String, dynamic> m) => PersonaCurrent(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String,
        strength: m['strength'] as int,
        firstSeenAt: DateTime.parse(m['first_seen_at'] as String),
        lastSeenAt: DateTime.parse(m['last_seen_at'] as String),
        linkedTheories: (m['linked_theories'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        linkedEmotions: (m['linked_emotions'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        thoughtIds: (m['thought_ids'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .map(int.parse)
                .toList() ??
            [],
        confirmed: m['confirmed'] == null
            ? null
            : (m['confirmed'] as int) == 1,
      );

  PersonaCurrent copyWith({
    String? name,
    String? description,
    int? strength,
    DateTime? lastSeenAt,
    List<String>? linkedTheories,
    List<String>? linkedEmotions,
    List<int>? thoughtIds,
    bool? Function()? confirmed,
  }) =>
      PersonaCurrent(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        strength: strength ?? this.strength,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        linkedTheories: linkedTheories ?? this.linkedTheories,
        linkedEmotions: linkedEmotions ?? this.linkedEmotions,
        thoughtIds: thoughtIds ?? this.thoughtIds,
        confirmed: confirmed != null ? confirmed() : this.confirmed,
      );
}

// ── CognitivePatternStat ────────────────────────────────────────────────────

class CognitivePatternStat {
  final String name;
  final int count;
  final List<int> thoughtIds;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  const CognitivePatternStat({
    required this.name,
    required this.count,
    required this.thoughtIds,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  bool get isHighFrequency => count >= 3;

  Map<String, dynamic> toMap() => {
        'name': name,
        'count': count,
        'thought_ids': thoughtIds.join(','),
        'first_seen_at': firstSeenAt.toIso8601String(),
        'last_seen_at': lastSeenAt.toIso8601String(),
      };

  factory CognitivePatternStat.fromMap(Map<String, dynamic> m) =>
      CognitivePatternStat(
        name: m['name'] as String,
        count: m['count'] as int,
        thoughtIds: (m['thought_ids'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
        firstSeenAt: DateTime.parse(m['first_seen_at'] as String),
        lastSeenAt: DateTime.parse(m['last_seen_at'] as String),
      );
}

// ── Database ────────────────────────────────────────────────────────────────

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'oddly.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE insight_cards ADD COLUMN core_pattern TEXT NOT NULL DEFAULT ""');
      await db.execute('''
        CREATE TABLE persona_currents (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          strength INTEGER NOT NULL DEFAULT 1,
          first_seen_at TEXT NOT NULL,
          last_seen_at TEXT NOT NULL,
          linked_theories TEXT NOT NULL DEFAULT '',
          linked_emotions TEXT NOT NULL DEFAULT '',
          thought_ids TEXT NOT NULL DEFAULT '',
          confirmed INTEGER
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE insight_cards ADD COLUMN perspective_index INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE insight_cards ADD COLUMN recommended_frameworks TEXT NOT NULL DEFAULT ""');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE insight_cards ADD COLUMN cognitive_patterns TEXT NOT NULL DEFAULT ""');
      await db.execute('''
        CREATE TABLE cognitive_pattern_stats (
          name TEXT PRIMARY KEY,
          count INTEGER NOT NULL DEFAULT 1,
          thought_ids TEXT NOT NULL DEFAULT '',
          first_seen_at TEXT NOT NULL,
          last_seen_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE thoughts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        location_name TEXT,
        weather TEXT,
        temperature INTEGER,
        emotion_tags TEXT NOT NULL DEFAULT '',
        is_analyzed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        thought_id INTEGER NOT NULL REFERENCES thoughts(id),
        round INTEGER NOT NULL,
        question TEXT NOT NULL,
        answer TEXT,
        was_skipped INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE insight_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        thought_id INTEGER NOT NULL REFERENCES thoughts(id) ON DELETE CASCADE,
        interpretation TEXT NOT NULL,
        psychology_theory TEXT NOT NULL,
        psychology_explanation TEXT NOT NULL,
        action_guide TEXT NOT NULL,
        core_pattern TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        perspective_index INTEGER NOT NULL DEFAULT 0,
        recommended_frameworks TEXT NOT NULL DEFAULT '',
        cognitive_patterns TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE thought_links (
        thought_id_a INTEGER NOT NULL REFERENCES thoughts(id),
        thought_id_b INTEGER NOT NULL REFERENCES thoughts(id),
        similarity_score REAL NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (thought_id_a, thought_id_b)
      )
    ''');

    await db.execute('''
      CREATE TABLE persona_currents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        strength INTEGER NOT NULL DEFAULT 1,
        first_seen_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        linked_theories TEXT NOT NULL DEFAULT '',
        linked_emotions TEXT NOT NULL DEFAULT '',
        thought_ids TEXT NOT NULL DEFAULT '',
        confirmed INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE cognitive_pattern_stats (
        name TEXT PRIMARY KEY,
        count INTEGER NOT NULL DEFAULT 1,
        thought_ids TEXT NOT NULL DEFAULT '',
        first_seen_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL
      )
    ''');
  }

  // ── Thoughts ────────────────────────────────────────────────────────────

  Future<int> insertThought(Thought thought) async {
    final d = await db;
    return d.insert('thoughts', thought.toMap());
  }

  Future<Thought?> getThought(int id) async {
    final d = await db;
    final rows = await d.query('thoughts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Thought.fromMap(rows.first);
  }

  Future<List<Thought>> getAllThoughts() async {
    final d = await db;
    final rows = await d.query('thoughts', orderBy: 'created_at DESC');
    return rows.map(Thought.fromMap).toList();
  }

  Future<List<Thought>> getThoughtsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final d = await db;
    final placeholders = ids.map((_) => '?').join(',');
    final rows = await d.rawQuery(
      'SELECT * FROM thoughts WHERE id IN ($placeholders) ORDER BY created_at DESC',
      ids,
    );
    return rows.map(Thought.fromMap).toList();
  }

  Future<void> updateThoughtContext(
    int id, {
    double? latitude,
    double? longitude,
    String? locationName,
    String? weather,
    int? temperature,
  }) async {
    final d = await db;
    await d.update(
      'thoughts',
      {
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName,
        'weather': weather,
        'temperature': temperature,
      }..removeWhere((_, v) => v == null),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateEmotionTags(int id, List<String> tags) async {
    final d = await db;
    await d.update(
      'thoughts',
      {'emotion_tags': tags.join(',')},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 级联删除：thoughts + ai_conversations + insight_cards + thought_links
  Future<void> deleteThought(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('ai_conversations', where: 'thought_id = ?', whereArgs: [id]);
      await txn.delete('insight_cards', where: 'thought_id = ?', whereArgs: [id]);
      await txn.delete(
        'thought_links',
        where: 'thought_id_a = ? OR thought_id_b = ?',
        whereArgs: [id, id],
      );
      await txn.delete('thoughts', where: 'id = ?', whereArgs: [id]);
    });

    // 同步更新暗流强度：从所有引用了该 thought 的暗流里移除 id，重算强度
    // 若某条暗流的 thought_ids 因此归零，则直接删除该暗流
    await _syncCurrentsAfterDelete(id);
  }

  Future<void> _syncCurrentsAfterDelete(int deletedThoughtId) async {
    final d = await db;
    final rows = await d.query('persona_currents');
    for (final row in rows) {
      final currentId = row['id'] as String;
      final thoughtIds = (row['thought_ids'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .map(int.parse)
          .toList();

      if (!thoughtIds.contains(deletedThoughtId)) continue;

      final updated = thoughtIds.where((t) => t != deletedThoughtId).toList();

      if (updated.isEmpty) {
        // 这条暗流的所有来源都删了，暗流本身也清掉
        await d.delete('persona_currents',
            where: 'id = ?', whereArgs: [currentId]);
      } else {
        final newStrength = updated.length.clamp(1, 5);
        await d.update(
          'persona_currents',
          {
            'thought_ids': updated.join(','),
            'strength': newStrength,
          },
          where: 'id = ?',
          whereArgs: [currentId],
        );
      }
    }
  }

  Future<void> markThoughtAnalyzed(int id, List<String> emotionTags) async {
    final d = await db;
    await d.update(
      'thoughts',
      {'emotion_tags': emotionTags.join(','), 'is_analyzed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── AI Conversations ────────────────────────────────────────────────────

  Future<int> insertConversation(AiConversation conv) async {
    final d = await db;
    return d.insert('ai_conversations', conv.toMap());
  }

  Future<void> saveAnswer(int convId, String answer) async {
    final d = await db;
    await d.update(
      'ai_conversations',
      {'answer': answer},
      where: 'id = ?',
      whereArgs: [convId],
    );
  }

  Future<void> markSkipped(int convId) async {
    final d = await db;
    await d.update(
      'ai_conversations',
      {'was_skipped': 1},
      where: 'id = ?',
      whereArgs: [convId],
    );
  }

  Future<List<AiConversation>> getConversationsForThought(int thoughtId) async {
    final d = await db;
    final rows = await d.query(
      'ai_conversations',
      where: 'thought_id = ?',
      whereArgs: [thoughtId],
      orderBy: 'round ASC',
    );
    return rows.map(AiConversation.fromMap).toList();
  }

  // ── Insight Cards ────────────────────────────────────────────────────────

  Future<int> insertInsightCard(InsightCard card) async {
    final d = await db;
    return d.insert('insight_cards', card.toMap());
  }

  /// 获取主视角洞察卡片（perspective_index = 0）
  Future<InsightCard?> getInsightCard(int thoughtId) async {
    final d = await db;
    final rows = await d.query(
      'insight_cards',
      where: 'thought_id = ? AND perspective_index = 0',
      whereArgs: [thoughtId],
      limit: 1,
    );
    return rows.isEmpty ? null : InsightCard.fromMap(rows.first);
  }

  /// 获取指定视角的洞察卡片
  Future<InsightCard?> getInsightCardByPerspective(
      int thoughtId, int perspectiveIndex) async {
    final d = await db;
    final rows = await d.query(
      'insight_cards',
      where: 'thought_id = ? AND perspective_index = ?',
      whereArgs: [thoughtId, perspectiveIndex],
      limit: 1,
    );
    return rows.isEmpty ? null : InsightCard.fromMap(rows.first);
  }

  // ── Persona Currents ────────────────────────────────────────────────────

  Future<List<PersonaCurrent>> getAllCurrents() async {
    final d = await db;
    final rows = await d.query(
      'persona_currents',
      orderBy: 'strength DESC, last_seen_at DESC',
    );
    return rows.map(PersonaCurrent.fromMap).toList();
  }

  Future<void> upsertCurrent(PersonaCurrent current) async {
    final d = await db;
    await d.insert(
      'persona_currents',
      current.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCurrentConfirmed(String id, bool? confirmed) async {
    final d = await db;
    await d.update(
      'persona_currents',
      {'confirmed': confirmed == null ? null : (confirmed ? 1 : 0)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCurrentName(String id, String name) async {
    final d = await db;
    await d.update(
      'persona_currents',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Cognitive Pattern Stats ──────────────────────────────────────────────

  Future<List<CognitivePatternStat>> getAllCognitivePatternStats() async {
    final d = await db;
    final rows = await d.query(
      'cognitive_pattern_stats',
      orderBy: 'count DESC',
    );
    return rows.map(CognitivePatternStat.fromMap).toList();
  }

  Future<CognitivePatternStat?> getCognitivePatternStat(String name) async {
    final d = await db;
    final rows = await d.query(
      'cognitive_pattern_stats',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : CognitivePatternStat.fromMap(rows.first);
  }

  /// 记录一次思维惯性出现，若已有则累加 count 并合并 thoughtId
  Future<void> upsertCognitivePatternStat(
      String name, int thoughtId) async {
    final d = await db;
    final existing = await getCognitivePatternStat(name);
    final now = DateTime.now().toIso8601String();

    if (existing == null) {
      await d.insert('cognitive_pattern_stats', {
        'name': name,
        'count': 1,
        'thought_ids': '$thoughtId',
        'first_seen_at': now,
        'last_seen_at': now,
      });
    } else {
      final ids = {...existing.thoughtIds, thoughtId}.toList();
      await d.update(
        'cognitive_pattern_stats',
        {
          'count': ids.length,
          'thought_ids': ids.join(','),
          'last_seen_at': now,
        },
        where: 'name = ?',
        whereArgs: [name],
      );
    }
  }
}
