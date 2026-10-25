import 'package:flutter/material.dart';

class BimNumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final String keyPrefix;
  final int decimals;
  const BimNumericKeypad({
    super.key,
    required this.onKey,
    this.keyPrefix = 'wall-key',
    this.decimals = 2,
  });

  static String edit(String? input, String key, {int decimals = 2}) {
    var value = input ?? '';
    if (key == '±') {
      return value.startsWith('-') ? value.substring(1) : '-$value';
    }
    if (key == '⌫') {
      return value.isEmpty ? '' : value.substring(0, value.length - 1);
    }
    if (key == '.') {
      if (decimals == 0) return value;
      return value.contains('.') ? value : '${value.isEmpty ? '0' : value}.';
    }
    if (value.length >= 10 ||
        (value.contains('.') && value.split('.').last.length >= decimals)) {
      return value;
    }
    return value + key;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['.', '0', '⌫'],
      ])
        Row(
          children: [
            for (final key in row)
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextButton(
                    key: ValueKey('$keyPrefix-$key'),
                    onPressed: key == '.' && decimals == 0
                        ? null
                        : () => onKey(key),
                    child: key == '⌫'
                        ? Icon(
                            Icons.backspace_outlined,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 20,
                          )
                        : Text(
                            key,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}
