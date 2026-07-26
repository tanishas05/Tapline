import 'package:flutter/material.dart';

import '../../data/level_loader.dart';
import '../../data/level_schema.dart';
import '../../design_system/design_system.dart';
import '../../engine/engine.dart';
import '../../generation/generation.dart';
import '../capacity/capacity_node_gauge.dart';

/// Dev-only screen that renders every design system component
/// together, so styling can be checked in isolation before any
/// gameplay exists. Not part of normal navigation flow — reached via
/// the palette icon in the hub screen's app bar.
class StyleGuideScreen extends StatefulWidget {
  const StyleGuideScreen({super.key});

  static const routeName = '/style-guide';

  @override
  State<StyleGuideScreen> createState() => _StyleGuideScreenState();
}

/// One shared toggle drives both the Pipe and Node demos below, so
/// their state colors can be compared side by side.
enum _DemoState { inactive, active, decaying }

class _StyleGuideScreenState extends State<StyleGuideScreen> {
  _DemoState _demo = _DemoState.active;

  PipeState get _pipeState => switch (_demo) {
        _DemoState.inactive => PipeState.inactive,
        _DemoState.active => PipeState.active,
        _DemoState.decaying => PipeState.decaying,
      };

  NodeVisualState get _nodeState => switch (_demo) {
        _DemoState.inactive => NodeVisualState.inactive,
        _DemoState.active => NodeVisualState.supplied,
        _DemoState.decaying => NodeVisualState.decaying,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STYLE GUIDE')),
      body: Stack(
        children: [
          const BlueprintGrid(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(ConvoySpacing.lg),
              children: [
                _Section(
                  title: 'COLORS',
                  child: Wrap(
                    spacing: ConvoySpacing.sm,
                    runSpacing: ConvoySpacing.sm,
                    children: [
                      _ColorChip(name: 'background', color: ConvoyColors.background),
                      _ColorChip(name: 'surface', color: ConvoyColors.surface),
                      _ColorChip(name: 'surfaceElevated', color: ConvoyColors.surfaceElevated),
                      _ColorChip(name: 'outline', color: ConvoyColors.outline),
                      _ColorChip(name: 'textPrimary', color: ConvoyColors.textPrimary),
                      _ColorChip(name: 'textSecondary', color: ConvoyColors.textSecondary),
                      _ColorChip(name: 'amber', color: ConvoyColors.amber),
                      _ColorChip(name: 'cyan', color: ConvoyColors.cyan),
                      _ColorChip(name: 'redDecay', color: ConvoyColors.redDecay),
                    ],
                  ),
                ),
                _Section(
                  title: 'TYPOGRAPHY',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TypeSample(
                        'wordmark · Baloo 2 ExtraBold',
                        ConvoyTypography.wordmark,
                        'TapLine',
                      ),
                      _TypeSample(
                        'panelTitle · Overpass Bold',
                        ConvoyTypography.panelTitle,
                        'CLASSIC',
                      ),
                      _TypeSample(
                        'panelSubtitle · Overpass Regular',
                        ConvoyTypography.panelSubtitle,
                        'Tap the fewest nodes to supply the network.',
                      ),
                      _TypeSample(
                        'sectionLabel · Overpass SemiBold',
                        ConvoyTypography.sectionLabel,
                        'MODE SELECT',
                      ),
                      _TypeSample(
                        'body · Overpass Regular',
                        ConvoyTypography.body,
                        'Every screen shares one schematic world.',
                      ),
                      _TypeSample(
                        'hudLarge · JetBrains Mono SemiBold',
                        ConvoyTypography.hudLarge,
                        '★ 128',
                      ),
                      _TypeSample(
                        'monoLabel · JetBrains Mono Medium',
                        ConvoyTypography.monoLabel,
                        'NODE_07 · CAP 12',
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'STATE',
                  child: _StateToggle(
                    value: _demo,
                    onChanged: (value) => setState(() => _demo = value),
                  ),
                ),
                _Section(
                  title: 'PIPE',
                  child: SizedBox(
                    height: 100,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return ConvoyPipe(
                                start: const Offset(10, 20),
                                end: Offset(constraints.maxWidth - 10, 80),
                                state: _pipeState,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _Section(
                  title: 'NODE',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ConvoyNode(
                        icon: Icons.storage,
                        label: 'CLASSIC',
                        state: _nodeState,
                      ),
                      ConvoyNode(
                        icon: Icons.speed,
                        label: 'CAPACITY',
                        state: _nodeState,
                      ),
                      ConvoyNode(
                        icon: Icons.settings_input_antenna,
                        label: 'SIGNAL',
                        state: _nodeState,
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'NODE: TAPPED (Phase 3)',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Not on the shared toggle above: "tapped" is a '
                          'player-action state, not a supply state, and '
                          'only applies to nodes. Filled solid so it reads '
                          'as "active source" against the outline-only '
                          'ring a merely-supplied node gets.',
                          style: ConvoyTypography.caption,
                        ),
                      ),
                      const SizedBox(width: ConvoySpacing.md),
                      const ConvoyNode(
                        icon: Icons.storage,
                        label: 'TAPPED',
                        state: NodeVisualState.tapped,
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'MODE PANEL',
                  child: ModePanel(
                    title: 'CLASSIC',
                    description:
                        'Tap the fewest tanks needed to keep every node supplied.',
                    icon: Icons.storage,
                    accentColor: ConvoyColors.amber,
                    onTap: () {},
                  ),
                ),
                _Section(
                  title: 'CAPACITY GAUGE (Phase 4)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The ring is the "read from across the room" '
                        'signal: how full, what color. The number '
                        'underneath is the "read up close" signal, the '
                        'exact supply/demand. A node past ~115% gets an '
                        'extra glow so "just barely satisfied" and '
                        '"comfortably supplied" don\'t look identical.',
                        style: ConvoyTypography.caption,
                      ),
                      const SizedBox(height: ConvoySpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          CapacityNodeGauge(
                            supply: 2,
                            demand: 10,
                            state: NodeVisualState.decaying,
                          ),
                          CapacityNodeGauge(
                            supply: 6,
                            demand: 10,
                            state: NodeVisualState.decaying,
                          ),
                          CapacityNodeGauge(
                            supply: 10,
                            demand: 10,
                            state: NodeVisualState.tapped,
                          ),
                          CapacityNodeGauge(
                            supply: 15,
                            demand: 10,
                            state: NodeVisualState.supplied,
                          ),
                        ],
                      ),
                      const SizedBox(height: ConvoySpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text('20%', style: ConvoyTypography.caption),
                          Text('60%', style: ConvoyTypography.caption),
                          Text('100%', style: ConvoyTypography.caption),
                          Text('150%', style: ConvoyTypography.caption),
                        ],
                      ),
                      const SizedBox(height: ConvoySpacing.md),
                      Text(
                        'Spillover pipes (dimmer, thinner than full '
                        'flow, since every cross-node contribution in '
                        'Capacity is the 0.5x mechanic, so pipes never '
                        'use the full-intensity "active" state Classic '
                        'does):',
                        style: ConvoyTypography.caption,
                      ),
                      const SizedBox(height: ConvoySpacing.sm),
                      SizedBox(
                        height: 32,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ConvoyPipe(
                              start: const Offset(0, 14),
                              end: Offset(constraints.maxWidth, 18),
                              state: PipeState.spillover,
                              curvature: 0.12,
                              baseStrokeWidth: 3,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'SIGNAL DIRECTED PIPE (Phase 5)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Arrowheads sit on the curve's own tangent at "
                        'the endpoint, pulled back so the node glyph '
                        "painted on top doesn't bury them; direction "
                        'is the one thing that has to read at a glance '
                        'to tell Signal apart from Classic/Capacity.',
                        style: ConvoyTypography.caption,
                      ),
                      const SizedBox(height: ConvoySpacing.sm),
                      SizedBox(
                        height: 40,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ConvoyPipe(
                              start: const Offset(0, 30),
                              end: Offset(constraints.maxWidth, 10),
                              state: PipeState.active,
                              directed: true,
                              curvature: 0.22,
                              baseStrokeWidth: 4,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: 'LEVEL GENERATION (DEV)',
                  child: const _LevelGenerationDemo(),
                ),
                const SizedBox(height: ConvoySpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ConvoySpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ConvoyTypography.sectionLabel),
          const SizedBox(height: ConvoySpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.name, required this.color});

  final String name;
  final Color color;

  String get _hex {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ConvoyColors.outline),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: ConvoyTypography.caption),
          Text(_hex, style: ConvoyTypography.monoLabel),
        ],
      ),
    );
  }
}

class _TypeSample extends StatelessWidget {
  const _TypeSample(this.label, this.style, this.sample);

  final String label;
  final TextStyle style;
  final String sample;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ConvoySpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ConvoyTypography.caption),
          const SizedBox(height: 2),
          Text(sample, style: style),
        ],
      ),
    );
  }
}

class _StateToggle extends StatelessWidget {
  const _StateToggle({required this.value, required this.onChanged});

  final _DemoState value;
  final ValueChanged<_DemoState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ConvoySpacing.sm,
      children: _DemoState.values.map((state) {
        final selected = state == value;
        return ChoiceChip(
          label: Text(state.name.toUpperCase()),
          selected: selected,
          onSelected: (_) => onChanged(state),
          labelStyle: ConvoyTypography.buttonLabel.copyWith(
            fontSize: 12,
            color:
                selected ? ConvoyColors.background : ConvoyColors.textPrimary,
          ),
          backgroundColor: ConvoyColors.surface,
          selectedColor: ConvoyColors.amber,
          side: BorderSide(color: ConvoyColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }
}

/// Phase 2's verification checklist calls for exactly this: "Calling
/// the SAME generation module directly, on-device (e.g. from a
/// temporary debug button), produces a valid, freshly-verified layout
/// at a given difficultyTier without going through the offline
/// script." Picks mode + tier, calls the real
/// [LevelLoader.generateNewLevelSameDifficulty] — the identical method
/// the Master Context's retry rule will call from real gameplay in
/// Phase 3+ — and shows what came back. Temporary: this whole section
/// is expected to be deleted once Phase 3 has a real place to
/// exercise generation (an actual retry, rather than a button on a
/// design-system reference screen).
class _LevelGenerationDemo extends StatefulWidget {
  const _LevelGenerationDemo();

  @override
  State<_LevelGenerationDemo> createState() => _LevelGenerationDemoState();
}

class _LevelGenerationDemoState extends State<_LevelGenerationDemo> {
  final _levelLoader = LevelLoader();

  GameMode _mode = GameMode.classic;
  DifficultyTier _tier = DifficultyTier.small;
  Level? _result;
  String? _error;
  bool _generating = false;

  void _generate() {
    setState(() {
      _generating = true;
      _result = null;
      _error = null;
    });
    try {
      final level = _levelLoader.generateNewLevelSameDifficulty(
        mode: _mode,
        tier: _tier,
      );
      setState(() => _result = level);
    } on LevelGenerationException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calls the on-device generator directly, the same call the '
          'retry flow uses, not the offline CLI script.',
          style: ConvoyTypography.caption,
        ),
        const SizedBox(height: ConvoySpacing.md),
        Wrap(
          spacing: ConvoySpacing.sm,
          children: GameMode.values.map((mode) {
            final selected = mode == _mode;
            return ChoiceChip(
              label: Text(mode.name.toUpperCase()),
              selected: selected,
              onSelected: (_) => setState(() => _mode = mode),
              labelStyle: ConvoyTypography.buttonLabel.copyWith(
                fontSize: 12,
                color: selected
                    ? ConvoyColors.background
                    : ConvoyColors.textPrimary,
              ),
              backgroundColor: ConvoyColors.surface,
              selectedColor: ConvoyColors.cyan,
              side: BorderSide(color: ConvoyColors.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ConvoySpacing.sm),
        Wrap(
          spacing: ConvoySpacing.sm,
          children: DifficultyTier.values.map((tier) {
            final selected = tier == _tier;
            return ChoiceChip(
              label: Text(tier.name.toUpperCase()),
              selected: selected,
              onSelected: (_) => setState(() => _tier = tier),
              labelStyle: ConvoyTypography.buttonLabel.copyWith(
                fontSize: 12,
                color: selected
                    ? ConvoyColors.background
                    : ConvoyColors.textPrimary,
              ),
              backgroundColor: ConvoyColors.surface,
              selectedColor: ConvoyColors.amber,
              side: BorderSide(color: ConvoyColors.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ConvoySpacing.md),
        ElevatedButton(
          onPressed: _generating ? null : _generate,
          child: Text(_generating ? 'GENERATING…' : 'GENERATE ON-DEVICE'),
        ),
        const SizedBox(height: ConvoySpacing.md),
        if (_error != null)
          Text(
            _error!,
            style: ConvoyTypography.caption.copyWith(
              color: ConvoyColors.redDecay,
            ),
          ),
        if (_result != null) _GeneratedLevelSummary(level: _result!),
      ],
    );
  }
}

class _GeneratedLevelSummary extends StatelessWidget {
  const _GeneratedLevelSummary({required this.level});

  final Level level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ConvoySpacing.md),
      decoration: BoxDecoration(
        color: ConvoyColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ConvoyColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: ConvoyColors.cyan,
                size: 16,
              ),
              const SizedBox(width: ConvoySpacing.xs),
              Text(
                'VERIFIED: construct-then-verify passed',
                style: ConvoyTypography.monoLabel.copyWith(
                  color: ConvoyColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: ConvoySpacing.sm),
          Text('id: ${level.id}', style: ConvoyTypography.monoLabel),
          Text(
            'nodes: ${level.nodes.length}   edges: ${level.edges.length}',
            style: ConvoyTypography.monoLabel,
          ),
          Text(
            'optimum: ${level.optimum}   maxTaps: ${level.optimum + 1}',
            style: ConvoyTypography.monoLabel,
          ),
          Text(
            'timeLimitSeconds: ${level.timeLimitSeconds}',
            style: ConvoyTypography.monoLabel,
          ),
        ],
      ),
    );
  }
}
