import 'package:flutter/material.dart';

/// A named color offered by the Touch color picker.
final class TouchColorSwatch {
  const TouchColorSwatch(this.name, this.hex);

  final String name;
  final String hex;
}

/// A compact palette for appearance edits. Existing custom colors remain visible.
const _palette = <TouchColorSwatch>[
  TouchColorSwatch('White', '#FFFFFF'),
  TouchColorSwatch('Ivory', '#F6F1E8'),
  TouchColorSwatch('Charcoal', '#202735'),
  TouchColorSwatch('Slate', '#475569'),
  TouchColorSwatch('Navy', '#16324F'),
  TouchColorSwatch('Blue', '#2563EB'),
  TouchColorSwatch('Indigo', '#4F46E5'),
  TouchColorSwatch('Purple', '#7C3AED'),
  TouchColorSwatch('Pink', '#DB2777'),
  TouchColorSwatch('Red', '#DC2626'),
  TouchColorSwatch('Orange', '#EA580C'),
  TouchColorSwatch('Amber', '#D97706'),
  TouchColorSwatch('Lime', '#65A30D'),
  TouchColorSwatch('Green', '#15803D'),
  TouchColorSwatch('Teal', '#0F766E'),
  TouchColorSwatch('Cyan', '#0891B2'),
];

Color? _colorOf(String? hex) {
  if (hex == null ||
      !RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
    return null;
  }
  return Color(
    int.parse(
      hex.length == 7 ? 'FF${hex.substring(1)}' : hex.substring(1),
      radix: 16,
    ),
  );
}

class TouchColorField extends StatelessWidget {
  const TouchColorField({
    super.key,
    required this.name,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onReset,
    this.palette,
  });

  final String name;
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onReset;
  final List<TouchColorSwatch>? palette;

  Future<void> _choose(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 336,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a color',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
                children: [
                  for (final entry in palette ?? _palette)
                    _PaletteChoice(
                      name: entry.name,
                      hex: entry.hex,
                      selected: value?.toUpperCase() == entry.hex,
                      onTap: () => Navigator.of(dialogContext).pop(entry.hex),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (onReset != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onReset!();
              },
              child: const Text('Use original'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null && context.mounted) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final current = _colorOf(value);
    final nameOfColor = (palette ?? _palette)
        .where((entry) => entry.hex == value?.toUpperCase())
        .map((entry) => entry.name)
        .firstOrNull;
    return InkWell(
      key: Key('touch-color-field-$name'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _choose(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.palette_outlined),
        ),
        child: Row(
          children: [
            Container(
              key: Key('touch-color-preview-$name'),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: current ?? Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nameOfColor ??
                    (current == null ? 'Choose color' : 'Current color'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.name,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(hex)!;
    return Tooltip(
      message: name,
      child: Semantics(
        label: 'Choose $name',
        button: true,
        selected: selected,
        child: InkWell(
          key: Key('touch-color-choice-${name.toLowerCase()}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.black26),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
