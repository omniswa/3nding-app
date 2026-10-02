import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where books.json and the books/*.zip files are hosted. Must end with "/".
const baseUrl = 'https://3nding.top/';

const _months = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

class Book {
  final int id;
  final String title, author, added, cover, zip;
  Book(Map j)
    : id = int.tryParse('${j['id']}') ?? 0,
      title = '${j['title'] ?? 'Untitled'}',
      author = '${j['author'] ?? 'Unknown'}',
      added = '${j['added'] ?? ''}',
      cover = '${j['cover'] ?? ''}',
      zip = '${j['zip'] ?? ''}';

  DateTime get date {
    final m = RegExp(r'(\w+)\s+(\d+),\s*(\d+)').firstMatch(added);
    if (m == null) return DateTime(1970);
    return DateTime(
      int.parse(m[3]!),
      _months.indexOf(m[1]!.toLowerCase()) + 1,
      int.parse(m[2]!),
    );
  }
}

class Prefs {
  int theme = 0, align = 0;
  String font = 'serif';
  double size = 18, height = 1.7, margin = 24;
  Map toJson() => {
    'theme': theme,
    'align': align,
    'font': font,
    'size': size,
    'height': height,
    'margin': margin,
  };
  void load(Map j) {
    theme = j['theme'] ?? 0;
    align = j['align'] ?? 0;
    font = j['font'] ?? 'serif';
    size = (j['size'] ?? 18).toDouble();
    height = (j['height'] ?? 1.7).toDouble();
    margin = (j['margin'] ?? 24).toDouble();
  }
}

class Store extends ChangeNotifier {
  List<Book> books = [];
  bool loading = true;
  String? error;
  Map<int, int> favs = {}; // bookId -> ms added to favorites
  Set<int> finished = {};
  Map<int, Map> progress = {}; // bookId -> {ch, f, p, t}
  final prefs = Prefs();
  late SharedPreferences _sp;

  Future<void> init() async {
    _sp = await SharedPreferences.getInstance();
    final raw = _sp.getString('state');
    if (raw != null) {
      final j = jsonDecode(raw);
      favs = (j['favs'] as Map).map((k, v) => MapEntry(int.parse(k), v as int));
      finished = (j['finished'] as List).cast<int>().toSet();
      progress = (j['progress'] as Map).map(
        (k, v) => MapEntry(int.parse(k), v as Map),
      );
      prefs.load(j['prefs'] ?? {});
    }
    refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await http.get(Uri.parse('${baseUrl}books.json'));
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      var data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is Map) {
        data = data['books'] ?? data.values.whereType<List>().firstOrNull ?? [];
      }
      books = (data as List).whereType<Map>().map((e) => Book(e)).toList()
        ..sort((a, b) {
          final c = b.date.compareTo(a.date);
          return c != 0
              ? c
              : b.id.compareTo(a.id); // same date: newer = higher id first
        });
    } catch (e) {
      error = 'Could not load library: $e';
    }
    loading = false;
    notifyListeners();
  }

  void _save() {
    _sp.setString(
      'state',
      jsonEncode({
        'favs': favs.map((k, v) => MapEntry('$k', v)),
        'finished': finished.toList(),
        'progress': progress.map((k, v) => MapEntry('$k', v)),
        'prefs': prefs.toJson(),
      }),
    );
    notifyListeners();
  }

  bool isFav(Book b) => favs.containsKey(b.id);
  void toggleFav(Book b) {
    isFav(b)
        ? favs.remove(b.id)
        : favs[b.id] = DateTime.now().millisecondsSinceEpoch;
    if (!isFav(b)) finished.remove(b.id);
    _save();
  }

  void toggleFinished(Book b) {
    finished.contains(b.id) ? finished.remove(b.id) : finished.add(b.id);
    _save();
  }

  void setPrefs(VoidCallback fn) {
    fn();
    _save();
  }

  void saveProgress(int id, int ch, double f, int total) {
    progress[id] = {
      'ch': ch,
      'f': f,
      'p': ((ch + f) / total).clamp(0.0, 1.0),
      't': DateTime.now().millisecondsSinceEpoch,
    };
    _save();
  }

  /// Downloads + extracts the zip once and caches chapters on disk when possible
  /// (mobile/desktop). If file storage is unavailable (e.g. web), it falls back to memory.
  Future<List<String>> chapters(Book b) async {
    Directory? dir;
    try {
      final root = await getApplicationDocumentsDirectory();
      dir = Directory('${root.path}/books/${b.id}');
    } catch (_) {}
    int n(String name) => int.tryParse(name.replaceAll('.txt', '')) ?? 0;
    final data = <String, List<int>>{};
    try {
      if (dir != null && dir.existsSync()) {
        for (final f in dir.listSync().whereType<File>()) {
          data[f.uri.pathSegments.last] = f.readAsBytesSync();
        }
      }
    } catch (_) {}
    if (data.isEmpty) {
      final r = await http.get(Uri.parse('$baseUrl${b.zip}'));
      if (r.statusCode != 200) throw 'Download failed (HTTP ${r.statusCode})';
      for (final f in ZipDecoder().decodeBytes(r.bodyBytes)) {
        final name = f.name.split('/').last;
        if (!f.isFile ||
            !name.endsWith('.txt') ||
            name.startsWith('.') ||
            f.name.contains('__MACOSX')) {
          continue;
        }
        data[name] = f.content as List<int>;
      }
      try {
        if (dir != null) {
          dir.createSync(recursive: true);
          data.forEach((k, v) => File('${dir!.path}/$k').writeAsBytesSync(v));
        }
      } catch (_) {}
    }
    final names = data.keys.toList()..sort((a, b) => n(a).compareTo(n(b)));
    return names
        .map((k) => utf8.decode(data[k]!, allowMalformed: true).trim())
        .toList();
  }
}

final store = Store();
