import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'store.dart';

const kThemes = [
  [Color(0xFFFFFFFF), Color(0xFF222222)], // light
  [Color(0xFFF4ECD8), Color(0xFF5B4636)], // sepia
  [Color(0xFF1E1F22), Color(0xFFD6D6D6)], // dark
  [Color(0xFF000000), Color(0xFFB0B0B0)], // black
];
const kThemeNames = ['Light', 'Sepia', 'Dark', 'Black'];
const kFonts = {'Serif': 'serif', 'Sans': 'sans-serif', 'Mono': 'monospace'};
const kAligns = [TextAlign.left, TextAlign.justify, TextAlign.center];

// Saved prefs keep the old keys, so existing users' settings still work.
const _families = {
  'serif': 'Literata',
  'sans-serif': 'Inter',
  'monospace': 'JetBrains Mono',
};

TextStyle fontStyle(String key, TextStyle base) =>
    GoogleFonts.getFont(_families[key] ?? 'Literata', textStyle: base);
const _accent = Color(0xFF4B4FE0);

class ReaderPage extends StatefulWidget {
  final Book book;
  const ReaderPage(this.book, {super.key});
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  List<String>? ch;
  String? err;
  int i = 0;
  double restore = 0;
  bool chrome = true; // top + bottom bars visible
  double? drag; // chapter slider value while dragging
  final sc = ScrollController();
  final frac = ValueNotifier<double>(0); // scroll position within chapter

  @override
  void initState() {
    super.initState();
    final p = store.progress[widget.book.id];
    i = p?['ch'] ?? 0;
    restore = (p?['f'] ?? 0).toDouble();
    sc.addListener(() {
      if (!sc.hasClients) return;
      final m = sc.position.maxScrollExtent;
      frac.value = m <= 0 ? 0 : (sc.offset / m).clamp(0.0, 1.0);
    });
    store
        .chapters(widget.book)
        .then((c) {
          if (c.isEmpty) throw 'No chapters found';
          setState(() {
            ch = c;
            i = i.clamp(0, c.length - 1);
          });
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (sc.hasClients) {
                sc.jumpTo(restore * sc.position.maxScrollExtent);
              }
            }),
          );
        })
        .catchError((e) => setState(() => err = '$e'));
  }

  void _save() {
    if (ch == null || !sc.hasClients) return;
    final m = sc.position.maxScrollExtent;
    store.saveProgress(
      widget.book.id,
      i,
      m <= 0 ? 0.0 : (sc.offset / m).clamp(0.0, 1.0),
      ch!.length,
    );
  }

  void _go(int n) {
    setState(() => i = n);
    if (sc.hasClients) sc.jumpTo(0);
    frac.value = 0;
    store.saveProgress(widget.book.id, n, 0, ch!.length);
  }

  void _toggleChrome() {
    setState(() => chrome = !chrome);
    SystemChrome.setEnabledSystemUIMode(
      chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  @override
  void dispose() {
    _save();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    sc.dispose();
    frac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final p = store.prefs, t = kThemes[p.theme], bgc = t[0], fg = t[1];
      final dark = ThemeData.estimateBrightnessForColor(bgc) == Brightness.dark;
      final pad = MediaQuery.paddingOf(context);
      final style = fontStyle(
        p.font,
        TextStyle(fontSize: p.size, height: p.height, color: fg),
      );

      Widget body;
      if (err != null) {
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(err!, style: style, textAlign: TextAlign.center),
          ),
        );
      } else if (ch == null) {
        body = Center(child: CircularProgressIndicator(color: fg));
      } else {
        final paras = ch![i]
            .split(RegExp(r'\n\s*\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final last = i == ch!.length - 1;
        body = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleChrome,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              _save();
              return false;
            },
            child: SingleChildScrollView(
              controller: sc,
              padding: EdgeInsets.fromLTRB(
                p.margin,
                pad.top + 80,
                p.margin,
                pad.bottom + 110,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chapter ${i + 1}',
                    style: fontStyle(
                      p.font,
                      TextStyle(
                        fontSize: p.size * 1.7,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(width: 36, height: 3, color: _accent),
                  const SizedBox(height: 28),
                  for (final s in paras)
                    Padding(
                      padding: EdgeInsets.only(bottom: p.size * .8),
                      child: Text(s, textAlign: kAligns[p.align], style: style),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      if (!last) return _go(i + 1);
                      if (!store.finished.contains(widget.book.id)) {
                        store.toggleFinished(widget.book);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(last ? 'Finish book' : 'Next chapter'),
                  ),
                  if (i > 0)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: fg),
                      onPressed: () => _go(i - 1),
                      child: const Text('Previous chapter'),
                    ),
                ],
              ),
            ),
          ),
        );
      }

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
        child: Scaffold(
          backgroundColor: bgc,
          body: Stack(
            children: [
              Positioned.fill(child: body),
              // thin chapter progress line, always visible
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder(
                  valueListenable: frac,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: ch == null ? 0 : v,
                    minHeight: 3,
                    color: _accent,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              _bar(top: true, bgc: bgc, fg: fg, pad: pad, child: _topBar(fg)),
              if (ch != null)
                _bar(
                  top: false,
                  bgc: bgc,
                  fg: fg,
                  pad: pad,
                  child: _bottomBar(fg),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _bar({
    required bool top,
    required Color bgc,
    required Color fg,
    required EdgeInsets pad,
    required Widget child,
  }) => Positioned(
    top: top ? 0 : null,
    bottom: top ? null : 0,
    left: 0,
    right: 0,
    child: IgnorePointer(
      ignoring: !chrome,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: chrome ? Offset.zero : Offset(0, top ? -1 : 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: chrome ? 1 : 0,
          child: Container(
            padding: EdgeInsets.only(
              top: top ? pad.top : 8,
              bottom: top ? 4 : pad.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: bgc.withValues(alpha: .97),
              border: Border(
                top: top ? BorderSide.none : BorderSide(color: _line(fg)),
                bottom: top ? BorderSide(color: _line(fg)) : BorderSide.none,
              ),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );

  Color _line(Color fg) => fg.withValues(alpha: .1);

  Widget _topBar(Color fg) => Row(
    children: [
      IconButton(
        color: fg,
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      Expanded(
        child: Text(
          widget.book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (ch != null)
        IconButton(
          color: fg,
          tooltip: 'Chapters',
          icon: const Icon(Icons.list),
          onPressed: _chapterList,
        ),
      IconButton(
        color: fg,
        tooltip: 'Reading settings',
        icon: const Icon(Icons.text_fields),
        onPressed: _settings,
      ),
    ],
  );

  Widget _bottomBar(Color fg) {
    final n = ch!.length;
    final v = drag ?? i.toDouble();
    final shown = v.round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chapter ${shown + 1} of $n',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                ValueListenableBuilder(
                  valueListenable: frac,
                  builder: (_, f, _) => Text(
                    '${(((i + f) / n).clamp(0.0, 1.0) * 100).round()}% of book',
                    style: TextStyle(color: fg.withValues(alpha: .6)),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                color: fg,
                icon: const Icon(Icons.skip_previous),
                onPressed: i > 0 ? () => _go(i - 1) : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: fg,
                    inactiveTrackColor: fg.withValues(alpha: .2),
                    thumbColor: fg,
                  ),
                  child: Slider(
                    min: 0,
                    max: (n - 1).clamp(1, 9999).toDouble(),
                    divisions: n > 1 ? n - 1 : null,
                    value: v.clamp(0, (n - 1).clamp(1, 9999).toDouble()),
                    onChanged: n > 1 ? (x) => setState(() => drag = x) : null,
                    onChangeEnd: (x) {
                      setState(() => drag = null);
                      if (x.round() != i) _go(x.round());
                    },
                  ),
                ),
              ),
              IconButton(
                color: fg,
                icon: const Icon(Icons.skip_next),
                onPressed: i < n - 1 ? () => _go(i + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _chapterList() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            'Chapters',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ch!.length,
            itemBuilder: (_, n) => ListTile(
              leading: Icon(
                n < i
                    ? Icons.check_circle
                    : n == i
                    ? Icons.menu_book
                    : Icons.circle_outlined,
                color: n <= i ? _accent : Colors.black26,
              ),
              title: Text(
                'Chapter ${n + 1}',
                style: TextStyle(
                  fontWeight: n == i ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              selected: n == i,
              selectedColor: _accent,
              onTap: () {
                Navigator.pop(context);
                _go(n);
              },
            ),
          ),
        ),
      ],
    ),
  );

  void _settings() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.prefs;
        Widget slider(
          String l,
          IconData icon,
          double v,
          double min,
          double max,
          String Function(double) fmt,
          void Function(double) f,
        ) => Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            SizedBox(width: 90, child: Text('  $l')),
            Expanded(
              child: Slider(
                value: v,
                min: min,
                max: max,
                onChanged: (x) => store.setPrefs(() => f(x)),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                fmt(v),
                textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var n = 0; n < kThemes.length; n++)
                    GestureDetector(
                      onTap: () => store.setPrefs(() => p.theme = n),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kThemes[n][0],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: p.theme == n ? _accent : Colors.black26,
                                width: p.theme == n ? 3 : 1,
                              ),
                            ),
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: kThemes[n][1],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            kThemeNames[n],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final e in kFonts.entries)
                    ButtonSegment(
                      value: e.value,
                      label: Text(
                        e.key,
                        style: fontStyle(e.value, const TextStyle()),
                      ),
                    ),
                ],
                selected: {p.font},
                onSelectionChanged: (s) =>
                    store.setPrefs(() => p.font = s.first),
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.format_align_left)),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.format_align_justify),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.format_align_center),
                  ),
                ],
                selected: {p.align},
                onSelectionChanged: (s) =>
                    store.setPrefs(() => p.align = s.first),
              ),
              const SizedBox(height: 6),
              slider(
                'Size',
                Icons.format_size,
                p.size,
                12,
                32,
                (v) => '${v.round()}',
                (x) => p.size = x,
              ),
              slider(
                'Spacing',
                Icons.format_line_spacing,
                p.height,
                1.2,
                2.4,
                (v) => v.toStringAsFixed(1),
                (x) => p.height = x,
              ),
              slider(
                'Margin',
                Icons.width_normal,
                p.margin,
                8,
                56,
                (v) => '${v.round()}',
                (x) => p.margin = x,
              ),
            ],
          ),
        );
      },
    ),
  );
}
