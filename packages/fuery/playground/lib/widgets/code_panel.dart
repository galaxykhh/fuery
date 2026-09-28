import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Shows the `// #region snippet` regions of a source file bundled as an
/// asset, so the code on screen is the code that runs.
class CodePanel extends StatefulWidget {
  const CodePanel({super.key, required this.source});

  /// The asset path, such as `lib/scenarios/lifecycle.dart`.
  final String source;

  @override
  State<CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<CodePanel> {
  late Future<List<String>> _snippets = _load();

  // Uncached: a file is small, and each panel reads its own copy.
  Future<List<String>> _load() async => extractSnippets(
        await rootBundle.loadString(widget.source, cache: false),
      );

  @override
  void didUpdateWidget(CodePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _snippets = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _snippets,
      builder: (context, snapshot) {
        final snippets = snapshot.data;
        if (snippets == null) {
          return SizedBox(
            height: 48,
            child: snapshot.hasError
                ? Text('Could not load ${widget.source}.')
                : null,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, snippet) in snippets.indexed) ...[
              if (index > 0) const SizedBox(height: 12),
              CodeBlock(snippet),
            ],
            const SizedBox(height: 8),
            Text(
              'From ${widget.source}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }
}

/// The lines between each `// #region snippet` and the `// #endregion` after
/// it, with their common indentation removed.
List<String> extractSnippets(String source) {
  final snippets = <String>[];
  List<String>? lines;
  for (final line in const LineSplitter().convert(source)) {
    switch (line.trim()) {
      case '// #region snippet':
        lines = [];
      case '// #endregion':
        if (lines != null) snippets.add(_dedent(lines));
        lines = null;
      default:
        lines?.add(line);
    }
  }
  return snippets;
}

String _dedent(List<String> lines) {
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  var indent = 1 << 20;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final spaces = line.length - line.trimLeft().length;
    if (spaces < indent) indent = spaces;
  }
  return [
    for (final line in lines) line.trim().isEmpty ? '' : line.substring(indent),
  ].join('\n');
}

/// Dart code in the code font, lightly highlighted, on the ink background.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D0A1E) : Brand.ink,
        borderRadius: BorderRadius.circular(12),
        border: dark ? Border.all(color: const Color(0xFF2E2852)) : null,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: SelectionArea(
          child: Text.rich(highlightDart(code), softWrap: false),
        ),
      ),
    );
  }
}

const _plain = TextStyle(
  fontFamily: monoFamily,
  fontSize: 12.5,
  height: 1.5,
  color: Color(0xFFD9D6EA),
);
const _keyword = TextStyle(color: Brand.lavender);
const _type = TextStyle(color: Colors.white);
const _string = TextStyle(color: Brand.lime);
const _number = TextStyle(color: Brand.lime);
const _comment = TextStyle(color: Color(0xFF8C87AA));

const _keywords = {
  'abstract',
  'as',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'for',
  'get',
  'if',
  'implements',
  'import',
  'in',
  'is',
  'late',
  'mixin',
  'new',
  'null',
  'required',
  'return',
  'set',
  'static',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

final _token = RegExp(
  r'(?<comment>//[^\n]*)'
  r"|(?<string>'(?:[^'\\\n]|\\.)*'|"
  r'"(?:[^"\\\n]|\\.)*")'
  r'|(?<number>\b\d+(?:\.\d+)?\b)'
  r'|(?<word>@?[A-Za-z_$][A-Za-z0-9_$]*)',
);

/// Colors comments, strings, numbers, keywords, and type names.
TextSpan highlightDart(String code) {
  final spans = <TextSpan>[];
  var position = 0;
  for (final match in _token.allMatches(code)) {
    if (match.start > position) {
      spans.add(TextSpan(text: code.substring(position, match.start)));
    }
    final text = match[0]!;
    final TextStyle? style;
    if (match.namedGroup('comment') != null) {
      style = _comment;
    } else if (match.namedGroup('string') != null) {
      style = _string;
    } else if (match.namedGroup('number') != null) {
      style = _number;
    } else if (_keywords.contains(text) || text.startsWith('@')) {
      style = _keyword;
    } else if (text.startsWith(RegExp('[A-Z]'))) {
      style = _type;
    } else {
      style = null;
    }
    spans.add(TextSpan(text: text, style: style));
    position = match.end;
  }
  if (position < code.length) {
    spans.add(TextSpan(text: code.substring(position)));
  }
  return TextSpan(style: _plain, children: spans);
}
