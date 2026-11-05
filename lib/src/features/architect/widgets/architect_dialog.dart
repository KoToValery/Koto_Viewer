import 'package:flutter/material.dart';

/// Consistent readable forms, including narrow phones and the on-screen keyboard.
/// Keeps a real AlertDialog in the tree for focus, semantics and route behavior.
Widget architectAlertDialog({
  Key? key,
  Widget? title,
  Widget? content,
  List<Widget>? actions,
  Color? backgroundColor,
  BoxConstraints? constraints,
  EdgeInsetsGeometry? contentPadding,
  EdgeInsetsGeometry? titlePadding,
  ShapeBorder? shape,
  bool scrollable = true,
}) => Builder(
  builder: (context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
      child: AlertDialog(
        key: key,
        title: title,
        content: content,
        actions: actions,
        backgroundColor: backgroundColor,
        constraints: constraints,
        shape: shape,
        scrollable: scrollable,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        titlePadding: titlePadding ?? const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding:
            contentPadding ?? const EdgeInsets.fromLTRB(20, 8, 20, 16),
      ),
    );
  },
);
