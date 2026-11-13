import os
import re
import sys

path = sys.argv[1]
keys = ['ANDROID_INTERSTITIAL', 'ANDROID_BANNER', 'ANDROID_REWARDED', 'ANDROID_APP_OPEN', 'IOS_INTERSTITIAL', 'IOS_BANNER', 'IOS_REWARDED', 'IOS_APP_OPEN']
pattern = re.compile(r'^ca-app-pub-\d+/\d+$')

with open(path, encoding='utf-8') as handle:
    source = handle.read()

applied = []
for key in keys:
    value = os.environ.get('ADMOB_' + key, '').strip()
    if not value:
        continue
    if not pattern.match(value):
        print(f'::warning::ADMOB_{key} is not a valid ad unit id, using the test id')
        continue
    source = re.sub(rf"(public static final {key}:String = )'[^']*';", rf"\1'{value}';", source)
    applied.append(key)

with open(path, 'w', encoding='utf-8') as handle:
    handle.write(source)

print('Real ad units: ' + (', '.join(applied) if applied else 'none, using test ads'))
