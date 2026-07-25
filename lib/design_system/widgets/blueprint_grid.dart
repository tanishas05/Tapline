import 'package:flutter/material.dart';

import '../convoy_colors.dart';

/// The backdrop behind Convoy's chrome screens: a soft directional
/// gradient wash. Kept the class name and [Positioned.fill]-in-a-
/// [Stack] usage unchanged across every visual revision so every
/// existing call site (hub, level select, achievements, settings,
/// style guide, coming-soon, and now the three gameplay screens too)
/// automatically picks up whatever this paints, with no other edits
/// needed.
///
/// A faint low-opacity version of [PipeMazeArt] was tried here as a
/// background texture but reverted — at the opacity needed to stay
/// out of the way of foreground content, straight pipe segments just
/// read as vague translucent rectangles rather than a recognizable
/// maze, so it looked like a rendering glitch rather than a design
/// choice. [PipeMazeArt] stays reserved for its rich, full-color use
/// on the hub banner, where it actually reads as intended.
///
/// Reads brightness straight from [Theme.of(context)] rather than
/// [ConvoyColors]'s shared mutable `brightness` field (which most
/// other widgets in this codebase use). That field is only guaranteed
/// correct once MaterialApp's own `builder` has run for the frame —
/// fine for a widget where a stale frame would be invisible, but this
/// one is a fully opaque full-screen wash, so any desync instead
/// showed up as the AppBar (theme-driven) and this background
/// (field-driven) rendering two different brightnesses at once.
/// Reading `Theme.of(context)` directly removes that race entirely —
/// it's always exactly what this widget's position in the tree
/// resolves to, no shared state involved.
///
/// Must be used as a direct child of a [Stack]; it positions itself
/// with [Positioned.fill].
class BlueprintGrid extends StatelessWidget {
  const BlueprintGrid({super.key, this.spacing = 28});

  /// Kept for API compatibility with existing call sites
  /// (`BlueprintGrid(spacing: ...)`); unused now that this paints a
  /// gradient rather than a grid.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = ConvoyColors.backgroundFor(brightness);
    final surface = ConvoyColors.surfaceFor(brightness);
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                background,
                Color.lerp(background, surface, 0.6)!,
                background,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}