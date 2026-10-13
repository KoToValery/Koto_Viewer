import 'dart:math' as math;
import 'dart:ui';
import '../geometry/bim_grid_axis.dart';

/// Drafting identifiers (numbers/letters); these are model names, not UI words.
class BimAxisNaming {
  static String getSuggestedAxisName(
    Offset start,
    Offset end,
    List<BimGridAxis> existingAxes,
    bool isBulgarian,
  ) {
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final isVertical = (math.cos(angle).abs() <= math.sin(angle).abs());

    final sameDirAxes = existingAxes
        .where((a) => a.isVertical == isVertical)
        .toList();

    const cyrillic = [
      'А',
      'Б',
      'В',
      'Г',
      'Д',
      'Е',
      'Ж',
      'З',
      'И',
      'К',
      'Л',
      'М',
      'Н',
      'О',
      'П',
      'Р',
      'С',
      'Т',
      'У',
      'Ф',
      'Х',
      'Ц',
      'Ч',
      'Ш',
      'Щ',
    ];
    const latin = [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'J',
      'K',
      'L',
      'M',
      'N',
      'P',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ];
    final letters = isBulgarian ? cyrillic : latin;

    if (sameDirAxes.isNotEmpty) {
      final hasNumbers = sameDirAxes.any((a) => int.tryParse(a.name) != null);
      if (hasNumbers) {
        int maxNum = 0;
        for (final a in sameDirAxes) {
          final val = int.tryParse(a.name);
          if (val != null && val > maxNum) maxNum = val;
        }
        return (maxNum + 1).toString();
      } else {
        int maxIdx = -1;
        for (final a in sameDirAxes) {
          final idx = letters.indexOf(a.name.toUpperCase());
          if (idx > maxIdx) maxIdx = idx;
        }
        if (maxIdx != -1 && maxIdx + 1 < letters.length) {
          return letters[maxIdx + 1];
        }
        return getNextAxisName(sameDirAxes.last.name, isBulgarian);
      }
    }

    final otherDirAxes = existingAxes
        .where((a) => a.isVertical != isVertical)
        .toList();
    if (otherDirAxes.isNotEmpty) {
      final otherHasNumbers = otherDirAxes.any(
        (a) => int.tryParse(a.name) != null,
      );
      if (otherHasNumbers) {
        return letters.first;
      } else {
        return '1';
      }
    }

    return isVertical ? '1' : letters.first;
  }

  static String getNextAxisName(String current, bool isBulgarian) {
    final num = int.tryParse(current);
    if (num != null) {
      return (num + 1).toString();
    }
    const cyrillic = [
      'А',
      'Б',
      'В',
      'Г',
      'Д',
      'Е',
      'Ж',
      'З',
      'И',
      'К',
      'Л',
      'М',
      'Н',
      'О',
      'П',
      'Р',
      'С',
      'Т',
      'У',
      'Ф',
      'Х',
      'Ц',
      'Ч',
      'Ш',
      'Щ',
    ];
    const latin = [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'J',
      'K',
      'L',
      'M',
      'N',
      'P',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ];
    final letters = isBulgarian ? cyrillic : latin;
    final idx = letters.indexOf(current.toUpperCase());
    if (idx != -1 && idx + 1 < letters.length) {
      return letters[idx + 1];
    }
    return '${current}_1';
  }
}
