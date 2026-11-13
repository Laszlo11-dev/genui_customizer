import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Presentation-only catalog. Its properties are intentionally literal-friendly
/// so a later Touch integration can expose them without changing the renderer.
const newsGalleryCatalogId =
    'https://example.com/a2ui-tech-reader/gallery.json';

final newsGalleryCatalog = CatalogImplementation(
  id: newsGalleryCatalogId,
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [_page, _section, _story, _grid],
);

final _color = Schema.string();
final _number = CommonSchemasV1.dynamicNumber;
final _string = CommonSchemasV1.dynamicString;
final _boolean = CommonSchemasV1.dynamicBoolean;

/// A2UI root for page-level appearance. The host also reads its resolved
/// backgroundColor to paint the Flutter shell around the news surface.
final _page = ComponentImplementation(
  name: 'NewsPage',
  schema: Schema.object(
    properties: {
      'children': Schema.fromMap({
        r'$ref': r'common_types.json#/$defs/ChildList',
      }),
      'backgroundColor': _color,
    },
    required: ['children'],
  ),
  builder: (context, node, props, buildChild) {
    final children = props.children('children');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children)
          KeyedSubtree(
            key: NodeKey(child.instanceId),
            child: buildChild(child),
          ),
      ],
    );
  },
);

final _section = ComponentImplementation(
  name: 'NewsSection',
  schema: Schema.object(
    properties: {
      'title': _string,
      'eyebrow': _string,
      'backgroundColor': _color,
      'textColor': _color,
      'accentColor': _color,
      'titleSize': _number,
      'padding': _number,
      'cornerRadius': _number,
      'showRule': _boolean,
    },
    required: ['title'],
  ),
  builder: (context, node, props, buildChild) {
    final accent = _readColor(
      props.string('accentColor'),
      Theme.of(context).colorScheme.primary,
    );
    final ink = _readColor(
      props.string('textColor'),
      Theme.of(context).colorScheme.onSurface,
    );
    final radius = _measure(props, 'cornerRadius', 0, 0, 40);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_measure(props, 'padding', 0, 0, 48)),
      decoration: BoxDecoration(
        color: _optionalColor(props.string('backgroundColor')),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (props.string('eyebrow') case final eyebrow?)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                eyebrow.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          Text(
            props.string('title') ?? '',
            style: TextStyle(
              color: ink,
              fontSize: _measure(props, 'titleSize', 26, 14, 52),
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (props.boolean('showRule') == true)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                height: 3,
                width: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  },
);

final _story = ComponentImplementation(
  name: 'NewsStory',
  schema: Schema.object(
    properties: {
      'title': _string,
      'source': _string,
      'summary': _string,
      'date': _string,
      'imageUrl': _string,
      'openLabel': _string,
      'open': Schema.fromMap({r'$ref': r'common_types.json#/$defs/Action'}),
      'backgroundColor': _color,
      'textColor': _color,
      'mutedColor': _color,
      'accentColor': _color,
      'borderColor': _color,
      'cornerRadius': _number,
      'padding': _number,
      'imageHeight': _number,
      'imagePosition': Schema.string(enumValues: ['top', 'left', 'none']),
      'imageFit': Schema.string(enumValues: ['cover', 'contain']),
      'titleSize': _number,
      'titleWeight': Schema.string(enumValues: ['regular', 'medium', 'bold']),
      'summarySize': _number,
      'showSummary': _boolean,
      'showDate': _boolean,
      'buttonStyle': Schema.string(enumValues: ['outline', 'filled', 'text']),
      'elevation': _number,
    },
    required: ['title', 'source', 'open'],
  ),
  builder: (context, node, props, buildChild) {
    final theme = Theme.of(context);
    final ink = _readColor(
      props.string('textColor'),
      theme.colorScheme.onSurface,
    );
    final muted = _readColor(
      props.string('mutedColor'),
      ink.withValues(alpha: .7),
    );
    final accent = _readColor(
      props.string('accentColor'),
      theme.colorScheme.primary,
    );
    final background = _readColor(
      props.string('backgroundColor'),
      theme.colorScheme.surface,
    );
    final border = _readColor(
      props.string('borderColor'),
      ink.withValues(alpha: .12),
    );
    final radius = _measure(props, 'cornerRadius', 18, 0, 48);
    final padding = _measure(props, 'padding', 15, 0, 48);
    final imageHeight = _measure(props, 'imageHeight', 160, 40, 420);
    final imageUrl = props.string('imageUrl');
    final imagePosition = props.string('imagePosition') ?? 'top';
    final imageFit = props.string('imageFit') == 'contain'
        ? BoxFit.contain
        : BoxFit.cover;
    final hasImage =
        imageUrl != null && imageUrl.isNotEmpty && imagePosition != 'none';
    Widget image() => ClipRRect(
      borderRadius: BorderRadius.circular((radius - 4).clamp(0, 44)),
      child: Image.network(
        imageUrl!,
        height: imageHeight,
        width: imagePosition == 'left' ? imageHeight * 1.15 : double.infinity,
        fit: imageFit,
        errorBuilder: (_, _, _) => Container(
          height: imageHeight,
          color: accent.withValues(alpha: .08),
          alignment: Alignment.center,
          child: Icon(Icons.image_not_supported_outlined, color: muted),
        ),
      ),
    );
    final titleWeight = switch (props.string('titleWeight')) {
      'regular' => FontWeight.w400,
      'medium' => FontWeight.w500,
      _ => FontWeight.w700,
    };
    final action = props.action('open');
    final buttonLabel = props.string('openLabel') ?? 'Read original ↗';
    final onPressed = action == null ? null : () => unawaited(action.call());
    final button = switch (props.string('buttonStyle')) {
      'filled' => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
        ),
        child: Text(buttonLabel),
      ),
      'text' => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: accent),
        child: Text(buttonLabel),
      ),
      _ => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: .5)),
        ),
        child: Text(buttonLabel),
      ),
    };
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (props.string('source') ?? '').toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: .8,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          props.string('title') ?? '',
          style: TextStyle(
            fontSize: _measure(props, 'titleSize', 23, 14, 42),
            fontWeight: titleWeight,
            color: ink,
            height: 1.2,
          ),
        ),
        if (props.boolean('showSummary') != false &&
            (props.string('summary')?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 9),
          Text(
            props.string('summary')!,
            style: TextStyle(
              color: muted,
              fontSize: _measure(props, 'summarySize', 14, 10, 24),
              height: 1.45,
            ),
          ),
        ],
        if (props.boolean('showDate') != false &&
            (props.string('date')?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 10),
          Text(
            props.string('date')!,
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: button),
      ],
    );
    return Material(
      color: background,
      elevation: _measure(props, 'elevation', 0, 0, 12),
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: hasImage
            ? LayoutBuilder(
                builder: (context, constraints) {
                  if (imagePosition == 'left' && constraints.maxWidth >= 420) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        image(),
                        const SizedBox(width: 18),
                        Expanded(child: content),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [image(), const SizedBox(height: 14), content],
                  );
                },
              )
            : content,
      ),
    );
  },
);

final _grid = ComponentImplementation(
  name: 'NewsGrid',
  schema: Schema.object(
    properties: {
      'children': Schema.fromMap({
        r'$ref': r'common_types.json#/$defs/ChildList',
      }),
      'columns': _number,
      'gap': _number,
    },
    required: ['children'],
  ),
  builder: (context, node, props, buildChild) {
    final children = props.children('children');
    final columns = _measure(props, 'columns', 3, 1, 4).round();
    final gap = _measure(props, 'gap', 16, 0, 40);
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 650 ? 1 : columns;
        return Column(
          children: [
            for (var start = 0; start < children.length; start += count) ...[
              if (start > 0) SizedBox(height: gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = start; i < start + count; i++) ...[
                    if (i > start) SizedBox(width: gap),
                    Expanded(
                      child: i < children.length
                          ? KeyedSubtree(
                              key: NodeKey(children[i].instanceId),
                              child: buildChild(children[i]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  },
);

double _measure(
  ComponentProps props,
  String name,
  double fallback,
  double min,
  double max,
) => (props.number(name) ?? fallback).clamp(min, max).toDouble();

Color? _optionalColor(String? value) {
  if (value == null) return null;
  final hex = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) return null;
  return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
}

Color _readColor(String? value, Color fallback) =>
    _optionalColor(value) ?? fallback;
