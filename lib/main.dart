import 'package:flutter/material.dart';

import 'reader.dart';
import 'store.dart';

const bg = Color(0xFFF7F2EA),
    brown = Color(0xFFB87A4B),
    green = Color(0xFF5A6B4F),
    ink = Color(0xFF2B2A28);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '3NDING',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: bg),
    ),
    home: const Shell(),
  );
}

void openBook(BuildContext c, Book b) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => ReaderPage(b)));

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: tab,
        children: const [HomeScreen(), FavoritesScreen(), StatsScreen()],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      backgroundColor: Colors.white,
      indicatorColor: brown.withValues(alpha: .18),
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.star_border),
          selectedIcon: Icon(Icons.star),
          label: 'Favorites',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Stats',
        ),
      ],
    ),
  );
}

// ---------- shared widgets ----------
class Cover extends StatelessWidget {
  final Book b;
  final double w;
  const Cover(this.b, this.w, {super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: w,
      height: w * 4 / 3,
      child: Image.network(
        b.cover,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: green,
          padding: const EdgeInsets.all(8),
          alignment: Alignment.bottomLeft,
          child: Text(
            b.title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget heading(String t, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 40,
            height: 3,
            color: brown,
          ),
        ],
      ),
      ?trailing,
    ],
  ),
);

BoxDecoration card() => BoxDecoration(
  color: Colors.white.withValues(alpha: .75),
  borderRadius: BorderRadius.circular(20),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: .04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

// ---------- HOME ----------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String q = '';
  String? author;
  bool searching = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final recent =
          store.books.where((b) => store.progress.containsKey(b.id)).toList()
            ..sort(
              (a, b) => store.progress[b.id]!['t'].compareTo(
                store.progress[a.id]!['t'],
              ),
            );
      final lib = store.books
          .where(
            (b) =>
                (author == null || b.author == author) &&
                (q.isEmpty ||
                    '${b.title} ${b.author}'.toLowerCase().contains(
                      q.toLowerCase(),
                    )),
          )
          .toList();
      return RefreshIndicator(
        onRefresh: store.refresh,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories, color: brown, size: 34),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3NDING',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                        Text(
                          'READ MORE · DISCOVER MORE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() {
                      searching = !searching;
                      if (!searching) q = '';
                    }),
                    icon: Icon(searching ? Icons.close : Icons.search),
                  ),
                  SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _filter,
                    icon: Badge(
                      isLabelVisible: author != null,
                      child: const Icon(Icons.tune),
                    ),
                  ),
                ],
              ),
            ),
            if (searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'Search title or author',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            if (recent.isNotEmpty) ...[
              heading('Recently Read'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [for (final b in recent.take(4)) _recentCard(b)],
                ),
              ),
            ],
            heading(
              'Library',
              trailing: author != null
                  ? InputChip(
                      label: Text(author!),
                      onDeleted: () => setState(() => author = null),
                    )
                  : null,
            ),
            if (store.loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (store.error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(store.error!, textAlign: TextAlign.center),
              ),
            if (!store.loading && store.error == null && lib.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No books match your filters.')),
              ),
            for (final b in lib) _libraryCard(b),
          ],
        ),
      );
    },
  );

  Widget _recentCard(Book b) {
    final p = store.progress[b.id]!, pct = (p['p'] as num).toDouble();
    return GestureDetector(
      onTap: () => openBook(context, b),
      child: Container(
        decoration: card(),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(b, 58),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    b.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const Spacer(),
                  Text(
                    '${(pct * 100).round()}% · Ch. ${p['ch'] + 1}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      color: brown,
                      backgroundColor: brown.withValues(alpha: .15),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Continue →',
                    style: TextStyle(
                      color: brown,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _libraryCard(Book b) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    padding: const EdgeInsets.all(14),
    decoration: card(),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cover(b, 92),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 92 * 4 / 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.author,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Added: ${b.added}',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => store.toggleFav(b),
                      icon: Icon(
                        store.isFav(b) ? Icons.star : Icons.star_border,
                        color: brown,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: () => openBook(context, b),
                    label: Text(
                      store.progress.containsKey(b.id)
                          ? 'Continue'
                          : 'Read Book',
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    iconAlignment: IconAlignment.end,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  void _filter() {
    final authors = store.books.map((b) => b.author).toSet().toList()..sort();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by author',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: author == null,
                  onSelected: (_) {
                    setState(() => author = null);
                    Navigator.pop(context);
                  },
                ),
                for (final a in authors)
                  ChoiceChip(
                    label: Text(a),
                    selected: author == a,
                    onSelected: (_) {
                      setState(() => author = a);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- FAVORITES ----------
enum Sort { added, title, author, opened }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Sort sort = Sort.added;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final list = store.books.where(store.isFav).toList();
      int opened(Book b) => store.progress[b.id]?['t'] ?? 0;
      list.sort(
        (a, b) => switch (sort) {
          Sort.added => store.favs[b.id]!.compareTo(store.favs[a.id]!),
          Sort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          Sort.author => a.author.toLowerCase().compareTo(
            b.author.toLowerCase(),
          ),
          Sort.opened => opened(b).compareTo(opened(a)),
        },
      );
      return ListView(
        children: [
          heading(
            'My Favorites',
            trailing: PopupMenuButton<Sort>(
              icon: const Icon(Icons.sort),
              initialValue: sort,
              onSelected: (s) => setState(() => sort = s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: Sort.added, child: Text('Date added')),
                PopupMenuItem(value: Sort.title, child: Text('Title')),
                PopupMenuItem(value: Sort.author, child: Text('Author')),
                PopupMenuItem(value: Sort.opened, child: Text('Last opened')),
              ],
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.star_border, size: 56, color: brown),
                  SizedBox(height: 12),
                  Text(
                    'No favorites yet.\nTap the star on any book to save it here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final b in list) _tile(b),
        ],
      );
    },
  );

  Widget _tile(Book b) {
    final done = store.finished.contains(b.id),
        pct = (store.progress[b.id]?['p'] ?? 0).toDouble();
    return GestureDetector(
      onTap: () => openBook(context, b),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(12),
        decoration: card(),
        child: Row(
          children: [
            Cover(b, 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(b.author, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  if (done)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.check_circle, color: green, size: 18),
                      label: Text('Finished'),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        color: brown,
                        backgroundColor: brown.withValues(alpha: .15),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) =>
                  v == 'done' ? store.toggleFinished(b) : store.toggleFav(b),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'done',
                  child: Text(done ? 'Mark as unfinished' : 'Mark as finished'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from favorites'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- STATS (placeholder + suggested features) ----------
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      Widget tile(String n, String l, IconData i) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: card(),
          child: Column(
            children: [
              Icon(i, color: brown),
              const SizedBox(height: 8),
              Text(
                n,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
      const ideas = [
        (
          Icons.local_fire_department,
          'Reading streak',
          'Days in a row you opened a book',
        ),
        (Icons.timer_outlined, 'Time read', 'Daily and weekly reading minutes'),
        (
          Icons.flag_outlined,
          'Goals',
          'Set a yearly book or daily minutes target',
        ),
        (
          Icons.emoji_events_outlined,
          'Badges',
          'Milestones for finishing books',
        ),
      ];
      return ListView(
        children: [
          heading('Stats'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 10,
              children: [
                tile('${store.progress.length}', 'Started', Icons.auto_stories),
                tile(
                  '${store.finished.length}',
                  'Finished',
                  Icons.check_circle_outline,
                ),
                tile('${store.favs.length}', 'Favorites', Icons.star_outline),
              ],
            ),
          ),
          heading('Coming soon'),
          for (final e in ideas)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              decoration: card(),
              child: ListTile(
                leading: Icon(e.$1, color: brown),
                title: Text(e.$2),
                subtitle: Text(e.$3),
              ),
            ),
        ],
      );
    },
  );
}
