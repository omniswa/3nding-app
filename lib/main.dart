import 'package:flutter/material.dart';

import 'reader.dart';
import 'store.dart';

// Palette: cool mist background, deep ink text, indigo primary, peach for progress.
const bg = Color(0xFFF2F4F8),
    ink = Color(0xFF14182B),
    muted = Color(0xFF6B7186),
    primary = Color(0xFF4B4FE0),
    tint = Color(0xFFE4E5FB),
    peach = Color(0xFFFF9E73);

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
      colorScheme: ColorScheme.fromSeed(seedColor: primary, surface: bg),
      textTheme: Typography.blackCupertino,
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
      bottom: false,
      child: IndexedStack(
        index: tab,
        children: const [HomeScreen(), FavoritesScreen(), StatsScreen()],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      height: 68,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: tint,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore, color: primary),
          label: 'Discover',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite, color: primary),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights, color: primary),
          label: 'Progress',
        ),
      ],
    ),
  );
}

// ---------- shared widgets ----------
class Cover extends StatelessWidget {
  final Book b;
  final double? w;
  const Cover(this.b, [this.w, Key? key]) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final img = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: .18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          b.cover,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, p) =>
              p == null ? child : Container(color: tint),
          errorBuilder: (_, _, _) => Container(
            color: primary,
            padding: const EdgeInsets.all(10),
            alignment: Alignment.bottomLeft,
            child: Text(
              b.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
    return w == null
        ? AspectRatio(aspectRatio: 3 / 4, child: img)
        : SizedBox(width: w, height: w! * 4 / 3, child: img);
  }
}

Widget heading(String t, {String? sub, Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            if (sub != null)
              Text(sub, style: const TextStyle(color: muted, fontSize: 13)),
          ],
        ),
      ),
      ?trailing,
    ],
  ),
);

BoxDecoration card({double r = 24}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(r),
  boxShadow: [
    BoxShadow(
      color: ink.withValues(alpha: .05),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ],
);

Widget bar(double v, {double h = 6, Color color = peach}) => ClipRRect(
  borderRadius: BorderRadius.circular(h),
  child: LinearProgressIndicator(
    value: v,
    minHeight: h,
    color: color,
    backgroundColor: color.withValues(alpha: .2),
  ),
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

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 18
        ? 'Good afternoon'
        : 'Good evening';
  }

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
      final authors = store.books.map((b) => b.author).toSet().toList()..sort();
      final browsing = q.isEmpty && author == null;

      return RefreshIndicator(
        onRefresh: store.refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(color: muted, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'What will you\nread today?',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: (v) => setState(() => q = v),
                      decoration: InputDecoration(
                        hintText: 'Search titles or authors',
                        hintStyle: const TextStyle(color: muted),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search, color: muted),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 58,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: authors.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final a = i == 0 ? null : authors[i - 1];
                    return ChoiceChip(
                      label: Text(a ?? 'All books'),
                      selected: author == a,
                      showCheckmark: false,
                      selectedColor: primary,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: author == a ? Colors.white : ink,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => author = a),
                    );
                  },
                ),
              ),
            ),
            if (recent.isNotEmpty && browsing) ...[
              SliverToBoxAdapter(child: heading('Continue reading')),
              SliverToBoxAdapter(child: _hero(recent.first)),
              if (recent.length > 1) ...[
                SliverToBoxAdapter(child: heading('Pick up again')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.length - 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => _recentTile(recent[i + 1]),
                    ),
                  ),
                ),
              ],
            ],
            SliverToBoxAdapter(
              child: heading(
                browsing ? 'Library' : 'Results',
                sub: '${lib.length} ${lib.length == 1 ? 'book' : 'books'}',
              ),
            ),
            if (store.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (store.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(store.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: store.refresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!store.loading && store.error == null && lib.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text('Nothing found. Try a different search.'),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 18,
                  childAspectRatio: .56,
                ),
                itemCount: lib.length,
                itemBuilder: (_, i) => _gridItem(lib[i]),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _hero(Book b) {
    final p = store.progress[b.id]!, pct = (p['p'] as num).toDouble();
    return GestureDetector(
      onTap: () => openBook(context, b),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [primary, Color(0xFF2C2FA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: .35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Cover(b, 92),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 92 * 4 / 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.author,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    Text(
                      '${(pct * 100).round()}% read · Chapter ${p['ch'] + 1}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    bar(pct, h: 6, color: peach),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primary,
                          minimumSize: const Size(0, 42),
                        ),
                        onPressed: () => openBook(context, b),
                        child: const Text('Resume'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentTile(Book b) {
    final pct = (store.progress[b.id]!['p'] as num).toDouble();
    return GestureDetector(
      onTap: () => openBook(context, b),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(b, 110),
            const SizedBox(height: 10),
            bar(pct, h: 4),
            const SizedBox(height: 6),
            Text(
              b.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridItem(Book b) {
    final started = store.progress.containsKey(b.id);
    return GestureDetector(
      onTap: () => openBook(context, b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Cover(b),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => store.toggleFav(b),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white.withValues(alpha: .92),
                    child: Icon(
                      store.isFav(b) ? Icons.favorite : Icons.favorite_border,
                      size: 19,
                      color: store.isFav(b) ? Colors.redAccent : ink,
                    ),
                  ),
                ),
              ),
              if (started)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: bar(
                    (store.progress[b.id]!['p'] as num).toDouble(),
                    h: 5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            b.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            b.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ],
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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          heading(
            'Saved',
            sub: '${list.length} ${list.length == 1 ? 'book' : 'books'}',
            trailing: PopupMenuButton<Sort>(
              icon: const Icon(Icons.swap_vert),
              initialValue: sort,
              onSelected: (s) => setState(() => sort = s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: Sort.added, child: Text('Recently saved')),
                PopupMenuItem(value: Sort.title, child: Text('Title')),
                PopupMenuItem(value: Sort.author, child: Text('Author')),
                PopupMenuItem(value: Sort.opened, child: Text('Last opened')),
              ],
            ),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: tint,
                    child: const Icon(
                      Icons.favorite_border,
                      size: 32,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nothing saved yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the heart on any book to keep it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        padding: const EdgeInsets.all(12),
        decoration: card(),
        child: Row(
          children: [
            Cover(b, 66),
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
                  Text(b.author, style: const TextStyle(color: muted)),
                  const SizedBox(height: 10),
                  if (done)
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Finished',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  else
                    bar(pct),
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
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- PROGRESS ----------
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final started = store.progress.length, done = store.finished.length;
      Widget tile(String n, String l, IconData i) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: card(r: 20),
          child: Column(
            children: [
              Icon(i, color: primary),
              const SizedBox(height: 8),
              Text(
                n,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(l, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
      );
      const ideas = [
        (
          Icons.local_fire_department_outlined,
          'Reading streak',
          'Days in a row you opened a book',
        ),
        (Icons.timer_outlined, 'Time read', 'Daily and weekly reading minutes'),
        (Icons.flag_outlined, 'Goals', 'Set a yearly book or daily target'),
        (
          Icons.emoji_events_outlined,
          'Badges',
          'Milestones for finishing books',
        ),
      ];
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          heading('Progress'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(22),
            decoration: card(r: 28),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: started == 0 ? 0 : done / started,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          color: primary,
                          backgroundColor: tint,
                        ),
                      ),
                      Text(
                        '$done/$started',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Text(
                    started == 0
                        ? 'Open a book to start tracking your progress.'
                        : done == started
                        ? 'You finished everything you started. Pick a new one!'
                        : '${started - done} in progress. Keep going!',
                    style: const TextStyle(fontSize: 16, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              spacing: 10,
              children: [
                tile('$started', 'Started', Icons.auto_stories),
                tile('$done', 'Finished', Icons.check_circle_outline),
                tile('${store.favs.length}', 'Saved', Icons.favorite_border),
              ],
            ),
          ),
          heading('Coming soon'),
          for (final e in ideas)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              decoration: card(r: 20),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: tint,
                  child: Icon(e.$1, color: primary),
                ),
                title: Text(
                  e.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(e.$3),
              ),
            ),
        ],
      );
    },
  );
}
