import 'package:flutter/material.dart';

class BimNumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final String keyPrefix;
  const BimNumericKeypad({
    super.key,
    required this.onKey,
    this.keyPrefix = 'wall-key',
  });

  static String edit(String? input, String key) {
    var value = input ?? '';
    if (key == '±') {
      return value.startsWith('-') ? value.substring(1) : '-$value';
    }
    if (key == '⌫') {
      return value.isEmpty ? '' : value.substring(0, value.length - 1);
    }
    if (key == '.') {
      return value.contains('.') ? value : '${value.isEmpty ? '0' : value}.';
    }
    if (value.length >= 10 ||
        (value.contains('.') && value.split('.').last.length >= 2)) {
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
                    onPressed: () => onKey(key),
                    child: key == '⌫'
                        ? const Icon(
                            Icons.backspace_outlined,
                            color: Colors.white,
                            size: 20,
                          )
                        : Text(
                            key,
                            style: const TextStyle(
                              color: Colors.white,
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
