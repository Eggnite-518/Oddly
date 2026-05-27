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
  final DateTime createdAt;

  const InsightCard({
    this.id,
    required this.thoughtId,
    required this.interpretation,
    required this.psychologyTheory,
    required this.psychologyExplanation,
    required this.actionGuide,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'thought_id': thoughtId,
        'interpretation': interpretation,
        'psychology_theory': psychologyTheory,
        'psychology_explanation': psychologyExplanation,
        'action_guide': actionGuide.join('|||'),
        'created_at': createdAt.toIso8601String(),
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
        createdAt: DateTime.parse(m['created_at'] as String),
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
    return openDatabase(path, version: 1, onCreate: _onCreate);
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
        created_at TEXT NOT NULL
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

  Future<InsightCard?> getInsightCard(int thoughtId) async {
    final d = await db;
    final rows = await d.query(
      'insight_cards',
      where: 'thought_id = ?',
      whereArgs: [thoughtId],
    );
    return rows.isEmpty ? null : InsightCard.fromMap(rows.first);
  }
}
