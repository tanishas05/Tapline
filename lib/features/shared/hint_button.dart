// Shared hint control for all three gameplay HUDs. Previously the
// hint action was a bare lightbulb IconButton with the cost only in
// its tooltip — invisible on a touch device, since tooltips need a
// long-press. This surfaces that same info (free hints left, or the
// coin cost once they're used up) as a small always-visible badge on
// the icon itself, and reuses [CoinIcon] so a paid hint reads as
// "costs a coin" at a glance, not just a bare number.

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import 'coin_badge.dart';

class HintButton extends StatelessWidget {
  const HintButton({
    super.key,
    required this.freeHintsRemaining,
    required this.hintCoinCost,
    required this.enabled,
    required this.onPressed,
  });

  final int freeHintsRemaining;
  final int hintCoinCost;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isFree = freeHintsRemaining > 0;

    return Semantics(
      button: true,
      label: isFree
          ? 'Hint, $freeHintsRemaining free left'
          : 'Hint, costs $hintCoinCost coins',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 34,
                color: enabled
                    ? ConvoyColors.amber
                    : ConvoyColors.amber.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 3),
              // The visible cost readout the old tooltip-only version
              // was missing: "N FREE" while the free allotment lasts,
              // then a coin icon + price the moment it runs out — so
              // the player always knows what tapping this costs
              // before they tap it, not after.
              if (isFree)
                Text(
                  '$freeHintsRemaining FREE',
                  style: ConvoyTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ConvoyColors.textSecondary,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 16),
                    const SizedBox(width: 3),
                    Text(
                      '$hintCoinCost',
                      style: ConvoyTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ConvoyColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
