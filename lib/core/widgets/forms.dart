import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/utils/formatters.dart';

/// Form kit. Every control here is the same Executive Slate material the
/// dashboards use: level 2 fill, 1px structural border, 8px radius, a label in
/// `label-sm`, and an accent border instead of a glow when focused. No new
/// visual language is introduced for editing.

class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MyOSSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: MyOSText.labelSm),
          const SizedBox(height: MyOSSpace.sm),
          Container(
            padding: const EdgeInsets.all(MyOSSpace.md),
            decoration: BoxDecoration(
              color: MyOSColors.surface,
              borderRadius: BorderRadius.circular(MyOSRadius.lg),
              border: Border.all(color: MyOSColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: MyOSSpace.md),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.error,
    this.required = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? error;
  final bool required;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: widget.label, required: widget.required),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          focusNode: _node,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          style: widget.maxLines > 1
              ? MyOSText.bodyMd
              : MyOSText.labelLg.copyWith(fontSize: 15),
          cursorColor: MyOSColors.accent,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: MyOSText.bodyMd.copyWith(color: MyOSColors.textMuted),
            counterStyle: MyOSText.dataSm,
            filled: true,
            fillColor: MyOSColors.surfaceHigh,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MyOSSpace.md,
              vertical: MyOSSpace.md,
            ),
            border: _border(MyOSColors.border),
            enabledBorder: _border(MyOSColors.border),
            focusedBorder: _border(MyOSColors.accent),
            errorBorder: _border(MyOSColors.negative),
            focusedErrorBorder: _border(MyOSColors.negative),
            errorText: widget.error,
            errorStyle: MyOSText.dataSm.copyWith(color: MyOSColors.negative),
          ),
        ),
        if (widget.error == null && widget.helper != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helper!,
            style: MyOSText.dataSm.copyWith(fontSize: 10),
          ),
        ],
      ],
    );
  }

  static OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(MyOSRadius.md),
      borderSide: BorderSide(color: color),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: MyOSText.labelSm),
        if (required) ...[
          const SizedBox(width: 4),
          Text(
            'wajib',
            style: MyOSText.dataSm.copyWith(
              fontSize: 9,
              color: MyOSColors.textDisabled,
            ),
          ),
        ],
      ],
    );
  }
}

/// Money input. Numeric keyboard on Android, digits regrouped as they are typed
/// so the field always reads like a ledger amount. The parsed integer is
/// handed to the caller; the text is never trusted as a number.
class AppAmountField extends StatefulWidget {
  const AppAmountField({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.helper,
    this.required = false,
    this.prefix = 'Rp',
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? error;
  final String? helper;
  final bool required;
  final String prefix;
  final ValueChanged<String>? onChanged;

  @override
  State<AppAmountField> createState() => _AppAmountFieldState();
}

class _AppAmountFieldState extends State<AppAmountField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_reformat);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_reformat);
    super.dispose();
  }

  void _reformat() {
    final text = widget.controller.text;
    final formatted = Fmt.formatAmountInput(text);
    if (formatted != text) {
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: widget.label, required: widget.required),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: MyOSText.dataLg.copyWith(fontSize: 18),
          cursorColor: MyOSColors.accent,
          decoration: InputDecoration(
            prefixText: '${widget.prefix} ',
            prefixStyle: MyOSText.dataSm.copyWith(
              color: MyOSColors.textMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: MyOSColors.surfaceHigh,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MyOSSpace.md,
              vertical: MyOSSpace.md,
            ),
            border: _AppTextFieldState._border(MyOSColors.border),
            enabledBorder: _AppTextFieldState._border(MyOSColors.border),
            focusedBorder: _AppTextFieldState._border(MyOSColors.accent),
            errorBorder: _AppTextFieldState._border(MyOSColors.negative),
            focusedErrorBorder: _AppTextFieldState._border(MyOSColors.negative),
            errorText: widget.error,
            errorStyle: MyOSText.dataSm.copyWith(color: MyOSColors.negative),
          ),
        ),
        if (widget.error == null && widget.helper != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helper!,
            style: MyOSText.dataSm.copyWith(fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// Tappable field that opens the platform date picker. Read only, because a
/// hand typed date is never a good idea on a phone.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.helper,
    this.allowClear = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? error;
  final String? helper;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        Material(
          color: MyOSColors.surfaceHigh,
          borderRadius: BorderRadius.circular(MyOSRadius.md),
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) onChanged(picked);
            },
            borderRadius: BorderRadius.circular(MyOSRadius.md),
            splashColor: MyOSColors.surfaceHighest,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MyOSRadius.md),
                border: Border.all(
                  color: error == null ? MyOSColors.border : MyOSColors.negative,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value == null ? 'Belum ditentukan' : Fmt.shortDate(value!),
                      style: value == null
                          ? MyOSText.bodyMd.copyWith(
                              color: MyOSColors.textMuted,
                            )
                          : MyOSText.labelLg.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (value != null && allowClear)
                    InkResponse(
                      onTap: () => onChanged(null),
                      radius: 18,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: MyOSColors.textMuted,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: MyOSColors.textMuted,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (error == null && helper != null) ...[
          const SizedBox(height: 4),
          Text(helper!, style: MyOSText.dataSm.copyWith(fontSize: 10)),
        ],
      ],
    );
  }
}

/// Single choice as a row of selectable chips. Same material as the filter
/// rail, so a form control and a filter are visually one system.
class AppChoiceField<T> extends StatelessWidget {
  const AppChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.hintOf,
    this.error,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T option) labelOf;
  final String? Function(T option)? hintOf;
  final ValueChanged<T> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        Wrap(
          spacing: MyOSSpace.sm,
          runSpacing: MyOSSpace.sm,
          children: [
            for (final option in options)
              _SelectChip(
                label: labelOf(option),
                hint: hintOf?.call(option),
                selected: option == value,
                onTap: () => onChanged(option),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: MyOSText.dataSm.copyWith(color: MyOSColors.negative),
          ),
        ],
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MyOSColors.surfaceHigh : MyOSColors.surface,
      borderRadius: BorderRadius.circular(MyOSRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MyOSRadius.sm),
        splashColor: MyOSColors.surfaceHighest,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MyOSSpace.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyOSRadius.sm),
            border: Border.all(
              color: selected ? MyOSColors.accent : MyOSColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: MyOSText.labelSm.copyWith(
                  color: selected
                      ? MyOSColors.textPrimary
                      : MyOSColors.textMuted,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 6),
                Text(
                  hint!,
                  style: MyOSText.dataSm.copyWith(
                    fontSize: 10,
                    color: MyOSColors.textDisabled,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Binary selector, the same 16x16 cell the focus list uses.
class AppSwitchField extends StatelessWidget {
  const AppSwitchField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              AppCheckboxLike(checked: value, onChanged: onChanged),
              const SizedBox(width: MyOSSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: MyOSText.bodyMd),
                    if (helper != null)
                      Text(
                        helper!,
                        style: MyOSText.dataSm.copyWith(fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox shape reused by the focus list, exposed here so forms do not
/// import a ledger widget.
class AppCheckboxLike extends StatelessWidget {
  const AppCheckboxLike({
    super.key,
    required this.checked,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      label: semanticLabel,
      child: InkResponse(
        onTap: () => onChanged(!checked),
        radius: 22,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: checked ? MyOSColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: checked ? MyOSColors.accent : MyOSColors.textMuted,
              width: 1.5,
            ),
          ),
          child: checked
              ? const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: MyOSColors.canvas,
                )
              : null,
        ),
      ),
    );
  }
}

/// Primary action. Accent fill, canvas text, 40px standard and 32px dense,
/// exactly as DESIGN.md specifies.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Material(
      color: enabled ? MyOSColors.accent : MyOSColors.surfaceHighest,
      borderRadius: BorderRadius.circular(MyOSRadius.md),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        child: Container(
          height: dense ? 32 : 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.lg),
          child: Text(
            busy ? 'Menyimpan' : label,
            style: MyOSText.labelMd.copyWith(
              color: enabled ? MyOSColors.canvas : MyOSColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Destructive action: transparent fill, negative text, 20% border. Never the
/// default button in a row, always the last one.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(MyOSRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyOSRadius.md),
            border: Border.all(
              color: MyOSColors.negative.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: MyOSText.labelMd.copyWith(color: MyOSColors.negative),
          ),
        ),
      ),
    );
  }
}

/// Secondary action with an icon, for the action bar on a detail screen where
/// the destructive action sits next to it.
class SecondaryAction extends StatelessWidget {
  const SecondaryAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MyOSColors.surfaceHigh,
      borderRadius: BorderRadius.circular(MyOSRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyOSRadius.md),
            border: Border.all(color: MyOSColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: onPressed == null
                    ? MyOSColors.textDisabled
                    : MyOSColors.accentDim,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: MyOSText.labelMd.copyWith(
                  color: onPressed == null
                      ? MyOSColors.textDisabled
                      : MyOSColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
