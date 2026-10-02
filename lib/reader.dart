import 'package:flutter/material.dart';

import 'store.dart';

const kThemes = [
  [Color(0xFFFFFFFF), Color(0xFF222222)], // light
  [Color(0xFFF4ECD8), Color(0xFF5B4636)], // sepia
  [Color(0xFF1E1F22), Color(0xFFD6D6D6)], // dark
  [Color(0xFF000000), Color(0xFFB0B0B0)], // black
];
const kFonts = {'Serif': 'serif', 'Sans': 'sans-serif', 'Mono': 'monospace'};
const kAligns = [TextAlign.left, TextAlign.justify, TextAlign.center];

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
  final sc = ScrollController();

  @override
  void initState() {
    super.initState();
    final p = store.progress[widget.book.id];
    i = p?['ch'] ?? 0;
    restore = (p?['f'] ?? 0).toDouble();
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
    sc.jumpTo(0);
    store.saveProgress(widget.book.id, n, 0, ch!.length);
  }

  @override
  void dispose() {
    _save();
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final p = store.prefs, t = kThemes[p.theme];
      final style = TextStyle(
        fontFamily: p.font,
        fontSize: p.size,
        height: p.height,
        color: t[1],
      );
      Widget body;
      if (err != null) {
        body = Center(child: Text(err!, style: style));
      } else if (ch == null) {
        body = Center(child: CircularProgressIndicator(color: t[1]));
      } else {
        body = NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            _save();
            return false;
          },
          child: SingleChildScrollView(
            controller: sc,
            padding: EdgeInsets.symmetric(horizontal: p.margin, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CHAPTER ${i + 1}  /  ${ch!.length}',
                  style: TextStyle(
                    color: t[1].withValues(alpha: .55),
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(ch![i], textAlign: kAligns[p.align], style: style),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: i > 0 ? () => _go(i - 1) : null,
                        child: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: t[1],
                          foregroundColor: t[0],
                        ),
                        onPressed: i < ch!.length - 1 ? () => _go(i + 1) : null,
                        child: const Text('Next'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: t[0],
        appBar: AppBar(
          backgroundColor: t[0],
          foregroundColor: t[1],
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
          actions: [
            if (ch != null)
              IconButton(
                icon: const Icon(Icons.format_list_numbered),
                onPressed: _chapterList,
              ),
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: _settings,
            ),
          ],
        ),
        body: SafeArea(child: body),
      );
    },
  );

  void _chapterList() => showModalBottomSheet(
    context: context,
    builder: (_) => ListView.builder(
      itemCount: ch!.length,
      itemBuilder: (_, n) => ListTile(
        title: Text('Chapter ${n + 1}'),
        selected: n == i,
        onTap: () {
          Navigator.pop(context);
          _go(n);
        },
      ),
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
          double v,
          double min,
          double max,
          void Function(double) f,
        ) => Row(
          children: [
            SizedBox(width: 90, child: Text(l)),
            Expanded(
              child: Slider(
                value: v,
                min: min,
                max: max,
                onChanged: (x) => store.setPrefs(() => f(x)),
              ),
            ),
          ],
        );
        return Padding(
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
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: kThemes[n][1],
                        child: CircleAvatar(
                          radius: p.theme == n ? 17 : 20,
                          backgroundColor: kThemes[n][0],
                          child: Text(
                            'Aa',
                            style: TextStyle(
                              color: kThemes[n][1],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in kFonts.entries)
                    ChoiceChip(
                      label: Text(e.key),
                      selected: p.font == e.value,
                      onSelected: (_) => store.setPrefs(() => p.font = e.value),
                    ),
                ],
              ),
              const SizedBox(height: 8),
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
              slider('Size', p.size, 12, 32, (x) => p.size = x),
              slider('Line height', p.height, 1.2, 2.4, (x) => p.height = x),
              slider('Margin', p.margin, 8, 56, (x) => p.margin = x),
            ],
          ),
        );
      },
    ),
  );
}
