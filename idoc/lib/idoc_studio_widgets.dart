part of 'idoc_studio_app.dart';

class QuestionTarget {
  const QuestionTarget({required this.id, required this.label});

  final String id;
  final String label;
}

class BlockWidthOption {
  const BlockWidthOption(this.factor, this.label);

  final double factor;
  final String label;
}

class _IdocTextEditor extends StatefulWidget {
  const _IdocTextEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.style,
    this.minLines = 1,
    this.maxLines = 1,
    this.decoration = const InputDecoration(),
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final TextStyle? style;
  final int minLines;
  final int maxLines;
  final InputDecoration decoration;

  @override
  State<_IdocTextEditor> createState() => _IdocTextEditorState();
}

class _IdocTextEditorState extends State<_IdocTextEditor> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  bool get _isMultiline => widget.minLines > 1 || widget.maxLines > 1;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _IdocTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _controller.text != widget.initialValue) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isMultiline || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    const tabInsertion = '    ';
    final selection = _controller.selection;
    final rawStart = selection.isValid
        ? selection.start
        : _controller.text.length;
    final rawEnd = selection.isValid ? selection.end : _controller.text.length;
    final start = rawStart < rawEnd ? rawStart : rawEnd;
    final end = rawStart < rawEnd ? rawEnd : rawStart;
    final nextText = _controller.text.replaceRange(start, end, tabInsertion);
    final caretOffset = start + tabInsertion.length;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caretOffset),
      composing: TextRange.empty,
    );
    widget.onChanged(nextText);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedStyle = widget.style ?? DefaultTextStyle.of(context).style;
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: EditableText(
        controller: _controller,
        focusNode: _focusNode,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        keyboardType: _isMultiline
            ? TextInputType.multiline
            : TextInputType.text,
        textInputAction: _isMultiline
            ? TextInputAction.newline
            : TextInputAction.done,
        style: resolvedStyle,
        cursorColor: theme.colorScheme.primary,
        backgroundCursorColor: theme.colorScheme.onSurface,
        selectionColor:
            theme.textSelectionTheme.selectionColor ??
            theme.colorScheme.primary.withValues(alpha: 0.22),
        selectionControls: materialTextSelectionControls,
        strutStyle: StrutStyle.fromTextStyle(resolvedStyle),
        onChanged: widget.onChanged,
      ),
    );
  }
}
