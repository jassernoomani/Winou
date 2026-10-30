"""Copies the push notification texts (android/app/src/main/res/values*/strings.xml) into the app's
translations, so the notifications list says exactly what the pushes said, in every language, and
writes lib/push_texts.dart to look them up by key.

    python tool/push_texts.py && flutter gen-l10n
"""
import collections
import json
import re
from pathlib import Path

MOBILE = Path(__file__).parents[1]
RES = MOBILE / 'android/app/src/main/res'
LOCALES = {'en': 'values', 'fr': 'values-fr', 'ar': 'values-ar'}


def strings(folder):
    text = (RES / folder / 'strings.xml').read_text(encoding='utf-8')
    return {m.group(1): m.group(2).replace("\\'", "'")
            for m in re.finditer(r'<string name="(\w+)">(.*?)</string>', text)}


def arb_key(name):
    return 'push' + ''.join(part.capitalize() for part in name.split('_'))


def message(text):
    # Android's %1$s and %2$s become {a} and {b}
    return text.replace('%1$s', '{a}').replace('%2$s', '{b}')


english = strings('values')
for locale, folder in LOCALES.items():
    texts = strings(folder)
    arb = MOBILE / f'lib/l10n/app_{locale}.arb'
    data = json.loads(arb.read_text(encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
    for name in english:
        key = arb_key(name)
        data[key] = message(texts[name])
        if locale == 'en':
            used = [p for p in ('a', 'b') if '{%s}' % p in data[key]]
            if used:
                data['@' + key] = {'placeholders': {p: {'type': 'String'} for p in used}}
            else:
                data.pop('@' + key, None)
    arb.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')

cases = []
for name, text in english.items():
    params = [p for p in ('a', 'b') if '{%s}' % p in message(text)]
    call = 'l10n.%s' % arb_key(name)
    if params:
        call += '(%s)' % ', '.join('arg(%d)' % i for i in range(len(params)))
    cases.append("    '%s' => %s," % (name, call))

(MOBILE / 'lib/push_texts.dart').write_text("""// Written by tool/push_texts.py from the Android push texts: run it again after changing them.
import 'l10n/app_localizations.dart';

/// The text of a push key (as the backend sends it, e.g. "match_title"), filled with [args], in the
/// app's language. null for a key this version of the app doesn't know.
String? pushText(AppLocalizations l10n, String? key, List<String> args) {
  String arg(int i) => i < args.length ? args[i] : '';
  return switch (key) {
%s
    _ => null,
  };
}
""" % '\n'.join(cases), encoding='utf-8', newline='\n')
print(len(english), 'texts')
