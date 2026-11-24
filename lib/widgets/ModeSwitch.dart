import 'package:material_ui/material_ui.dart';

/// A two-state mode switch whose thumb carries the mode's icon: a microphone
/// for speech-to-signs and a raised-index hand for signs-to-speech.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      toggled: value,
      label: value ? 'Speech to Signs' : 'Signs to Speech',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 78,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value
                ? colors.primary.withValues(alpha: 0.18)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? colors.primary : colors.outlineVariant,
              width: 1.2,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                value ? Icons.mic : Icons.touch_app,
                size: 20,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
