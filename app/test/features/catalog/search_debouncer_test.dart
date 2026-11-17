import 'package:el3yada/features/catalog/application/search_debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A.6: search about 150 ms after the last keystroke; older answers dropped.
void main() {
  test('only the last of quick keystrokes searches; the others answer null', () async {
    final debouncer = SearchDebouncer(delay: const Duration(milliseconds: 30));
    addTearDown(debouncer.dispose);
    final searched = <String>[];
    Future<String> search(String text) async {
      searched.add(text);
      return text;
    }

    final a = debouncer.run(() => search('a'));
    final at = debouncer.run(() => search('at'));
    final ator = debouncer.run(() => search('ator'));
    expect(await a, isNull);
    expect(await at, isNull);
    expect(await ator, 'ator');
    expect(searched, ['ator']);
  });

  test('a slow search replaced while running is dropped', () async {
    final debouncer = SearchDebouncer(delay: const Duration(milliseconds: 5));
    addTearDown(debouncer.dispose);
    final slow = debouncer.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      return 'slow';
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final fast = debouncer.run(() async => 'fast');
    expect(await fast, 'fast');
    expect(await slow, isNull);
  });

  test('the default wait is about 150 ms', () {
    expect(SearchDebouncer().delay, const Duration(milliseconds: 150));
  });
}
