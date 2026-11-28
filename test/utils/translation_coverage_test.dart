import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, String>> loadTranslations() {
  final raw = Map<String, dynamic>.from(
    jsonDecode(File('assets/translation.json').readAsStringSync()),
  );
  final result = <String, Map<String, String>>{};
  for (final entry in raw.entries) {
    result[entry.key] = Map<String, String>.from(entry.value as Map);
  }
  return result;
}

void main() {
  final translations = loadTranslations();

  test('zh_CN and zh_TW cover the exact same set of keys', () {
    final cn = translations['zh_CN']!.keys.toSet();
    final tw = translations['zh_TW']!.keys.toSet();
    expect(
      cn.difference(tw),
      isEmpty,
      reason: 'keys missing from zh_TW: ${cn.difference(tw)}',
    );
    expect(
      tw.difference(cn),
      isEmpty,
      reason: 'keys missing from zh_CN: ${tw.difference(cn)}',
    );
  });

  test('no translation entry is empty', () {
    for (final entry in translations.entries) {
      for (final pair in entry.value.entries) {
        expect(
          pair.value.trim(),
          isNotEmpty,
          reason: '${entry.key}["${pair.key}"] is empty',
        );
      }
    }
  });

  test('UI-refactor user-facing strings are translated', () {
    const keys = [
      'UI font scale',
      'Appearance',
      'Theme',
      'Theme Mode',
      'Theme Color',
      'Display mode of comic tile',
      'Size of comic tile',
      'Display mode of comic list',
      'Cancel',
      'Confirm',
      'Export logs',
      'Error',
      'Super Resolution',
      'How it works',
      'Network Images',
      'Scale Factor',
      'Line Refinement Strength',
      'Edge Refinement Strength',
      'Tuning Tips',
      'No images on this page',
      'Switch to Original',
      'Switch to Super Resolution',
      'Show Super Resolution',
      'Super Resolution in progress',
      'Waiting for Super Resolution to finish',
      'The current upscaling algorithm is Anime4K, tuned for line art, manga and comic edge enhancement. For images that are already blurry or heavily compressed, the improvement is usually limited.',
      'When enabled, the reader upscales pages in the background.',
      'Also upscale when reading online. Images are replaced once processed, which adds latency and memory usage.',
      'Recommended: 1.5 - 2.0. The higher the factor, the sharper the edges, but processing time and memory usage rise noticeably.',
      'Recommended: 0.2 - 0.4. Higher values make black lines sharper; too high may look harsh, cause jaggies, or lose detail.',
      'Recommended: 0.8 - 1.2. Enhances edge transitions; too high may make noise and compression artifacts more obvious.',
      'Start with scale factor 2.0, then fine-tune "Line Refinement Strength" and "Edge Refinement Strength". Anime4K focuses on edge enhancement and cannot turn a low-quality compressed image back into a high-resolution original.',
    ];
    for (final locale in ['zh_CN', 'zh_TW']) {
      final map = translations[locale]!;
      for (final key in keys) {
        expect(map, contains(key), reason: '$locale missing "$key"');
      }
    }
  });
}
