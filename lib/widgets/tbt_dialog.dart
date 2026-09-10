import 'package:flutter/material.dart';

const tbtDialogBackground = Color(0xFF0D1B30);
const tbtDialogAccent = Color(0xFF8ACDFF);

ThemeData tbtDialogTheme(ThemeData base) => base.copyWith(
  colorScheme: base.colorScheme.copyWith(
    primary: tbtDialogAccent,
    secondary: tbtDialogAccent,
    primaryContainer: const Color(0xFF203C62),
    onPrimaryContainer: Colors.white,
    onSurface: const Color(0xFFF0F5FF),
    onPrimary: const Color(0xFF071322),
    surface: tbtDialogBackground,
    surfaceContainerHigh: tbtDialogBackground,
    surfaceContainerHighest: const Color(0xFF162A43),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: tbtDialogAccent,
    selectionColor: Color(0x448ACDFF),
    selectionHandleColor: tbtDialogAccent,
  ),
  inputDecorationTheme: base.inputDecorationTheme.copyWith(
    fillColor: const Color(0xFF081426),
    floatingLabelStyle: const TextStyle(color: tbtDialogAccent),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: tbtDialogAccent),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFFB5C9DF)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF285F8C),
      foregroundColor: Colors.white,
      minimumSize: const Size(90, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);

Future<T?> showTbtDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: barrierDismissible,
  enableDrag: barrierDismissible,
  backgroundColor: Colors.transparent,
  builder: (context) => Theme(
    data: tbtDialogTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom -
                        MediaQuery.paddingOf(context).top -
                        36)
                    .clamp(100, 760)
                    .toDouble(),
          ),
          child: builder(context),
        ),
      ),
    ),
  ),
);

/// Compact, scrollable surfaces shared by editing, confirmation and info flows.
class TbtDialog extends StatelessWidget {
  const TbtDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.backgroundColor,
  });
  final Widget? title, content, icon;
  final List<Widget>? actions;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => Material(
    color: tbtDialogBackground,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF3B526E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IconTheme(
                data: const IconThemeData(color: tbtDialogAccent, size: 28),
                child: icon!,
              ),
            ),
          if (title != null)
            DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              child: title!,
            ),
          if (content != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Color(0xFFD7E3EF),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    child: content!,
                  ),
                ),
              ),
            ),
          if (actions?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: actions!,
              ),
            ),
        ],
      ),
    ),
  );
}
