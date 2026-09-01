import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'line_icon.dart';

/// White (or cream) surface with the design's soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.color = AppColors.card,
    this.border,
    this.shadow = true,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final BoxBorder? border;
  final bool shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x0F362B2C),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Filled clay CTA — the app's primary action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 60,
    this.radius = 20,
    this.icon,
    this.color = AppColors.clay,
    this.textStyle,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final LineIconData? icon;
  final Color color;
  final TextStyle? textStyle;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? AppText.button;
    final button = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          foregroundColor: AppColors.card,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Color(0x1A362B2C)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              LineIcon(icon!, color: AppColors.card, size: 22),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// White fill, 2px tan border — the quieter half of a button pair.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 52,
    this.radius = 16,
    this.textStyle,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final TextStyle? textStyle;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(AppColors.surface),
        ),
        child: Text(
          label,
          style: textStyle ?? AppText.buttonMedium.copyWith(color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Borderless text action, e.g. "تراجع" on a resolved visit row.
class TextActionButton extends StatelessWidget {
  const TextActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppColors.clayDark,
    this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: (style ?? AppText.textButton).copyWith(color: color)),
    );
  }
}

/// Fully-rounded status badge, coloured per state.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.padding = _defaultPadding,
    this.textStyle,
    this.leading,
  });

  static const _defaultPadding = EdgeInsets.symmetric(horizontal: 13, vertical: 7);

  /// Success — attended, paid, on track.
  const StatusPill.success(
    String label, {
    Key? key,
    EdgeInsetsGeometry padding = _defaultPadding,
    TextStyle? textStyle,
    Widget? leading,
  }) : this(
          key: key,
          label: label,
          background: AppColors.sageBg,
          foreground: AppColors.sageText,
          padding: padding,
          textStyle: textStyle,
          leading: leading,
        );

  /// Balance due / urgent.
  const StatusPill.due(
    String label, {
    Key? key,
    EdgeInsetsGeometry padding = _defaultPadding,
    TextStyle? textStyle,
  }) : this(
          key: key,
          label: label,
          background: AppColors.dueBg,
          foreground: AppColors.clayDark,
          padding: padding,
          textStyle: textStyle,
        );

  /// No data — "٠ متبقية", expired.
  const StatusPill.neutral(
    String label, {
    Key? key,
    EdgeInsetsGeometry padding = _defaultPadding,
    TextStyle? textStyle,
  }) : this(
          key: key,
          label: label,
          background: AppColors.neutralChipBg,
          foreground: AppColors.neutralChipText,
          padding: padding,
          textStyle: textStyle,
        );

  final String label;
  final Color background;
  final Color foreground;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: (textStyle ?? AppText.pill).copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Rounded-square avatar showing the client's first letter, tinted from a
/// rotating family so the same client keeps the same colour.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 48,
    this.radius = 16,
    this.textStyle,
    this.muted = false,
  });

  final String name;

  /// Anything stable per client — the id works well.
  final String seed;
  final double size;
  final double radius;
  final TextStyle? textStyle;

  /// Uses the neutral tan tint, for clients with no running package.
  final bool muted;

  /// A stable index from the seed. `String.hashCode` is not guaranteed to
  /// be the same between runs, and an avatar that changes colour every
  /// launch would be worse than no rotation at all.
  static int _tintIndex(String seed) {
    var sum = 0;
    for (final unit in seed.codeUnits) {
      sum = (sum + unit) % 100003;
    }
    return sum % AppColors.avatarTints.length;
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = muted
        ? (AppColors.canvas, AppColors.textMuted)
        : AppColors.avatarTints[_tintIndex(seed)];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        name.characters.first,
        style: (textStyle ??
                TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                ))
            .copyWith(color: foreground),
      ),
    );
  }
}

/// The green/grey dot row showing how far into a package a client is.
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.total,
    required this.done,
    this.size = 9,
    this.gap = 5,
  });

  final int total;
  final int done;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            margin: EdgeInsetsDirectional.only(start: i == 0 ? 0 : gap),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: i < done ? AppColors.sage : AppColors.sageDot,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// A hairline divider between list rows inside a card.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key, this.margin = const EdgeInsets.symmetric(vertical: 12)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        height: 1,
        color: AppColors.divider,
      );
}

/// Small square icon tile used on the stat cards and the balance card.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 44,
    this.radius = 14,
    this.iconSize = 22,
  });

  final LineIconData icon;
  final Color color;
  final Color background;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: LineIcon(icon, color: color, size: iconSize),
      );
}

/// A tappable icon sized for the top bar.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.color = AppColors.textPrimary,
    this.size = 26,
    this.tooltip,
  });

  final LineIconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: LineIcon(icon, color: color, size: size),
    );
  }
}

/// Bordered input matching the cream form fields in the design.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.suffix,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.borderSoft, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: textAlign,
              autofocus: autofocus,
              onChanged: onChanged,
              style: AppText.rowTitleSmall.copyWith(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.placeholder.copyWith(fontSize: 16),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (suffix != null) ...[const SizedBox(width: 8), suffix!],
        ],
      ),
    );
  }
}

/// The small grey label that sits above a field or section.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.padding = const EdgeInsets.only(bottom: 10)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: Text(text, style: AppText.fieldLabel));
}

/// Segmented control on a tan track, as used for the payment status and
/// the payment method rows.
class SegmentedRow<T> extends StatelessWidget {
  const SegmentedRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                  decoration: value == selected
                      ? BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14362B2C),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    labelOf(value),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: value == selected ? AppText.chip : AppText.chipIdle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Row of bordered option boxes — the نقداً / بِت / تحويل selector.
class OptionTabs<T> extends StatelessWidget {
  const OptionTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final value in values) ...[
          if (value != values.first) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(value),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: value == selected ? AppColors.sage : AppColors.borderSoft,
                    width: 2,
                  ),
                ),
                child: Text(
                  labelOf(value),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: value == selected ? AppText.chip : AppText.chipIdle,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
