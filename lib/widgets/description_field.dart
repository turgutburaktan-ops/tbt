import 'package:flutter/material.dart';

/// Explicit dismissal is needed for touch taps outside a field on iOS.
class DescriptionField extends StatelessWidget {
  const DescriptionField({super.key, required this.controller,
    this.minLines = 3, this.maxLines = 5, this.maxLength = 500,
    this.style, this.decoration = const InputDecoration(labelText: 'Açıklama')});

  final TextEditingController controller;
  final int minLines, maxLines, maxLength;
  final TextStyle? style;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    void dismiss() => FocusManager.instance.primaryFocus?.unfocus();
    return TextField(
      controller: controller, minLines: minLines, maxLines: maxLines,
      maxLength: maxLength, style: style,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => dismiss(),
      onTapOutside: (_) => dismiss(),
      decoration: decoration.copyWith(suffixIcon: TextButton(
        onPressed: dismiss, child: const Text('Bitti'),
      )),
    );
  }
}
