import 'dart:io';

import '../lib/phone_normalizer.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

void main() {
  check('parens dash', normalizeUsPhone('(212) 555-0187'), '+12125550187');
  check('dots', normalizeUsPhone('212.555.0187'), '+12125550187');
  check('leading one', normalizeUsPhone('1 212 555 0187'), '+12125550187');
  check('plus one', normalizeUsPhone('+1 (212) 555-0187'), '+12125550187');
  check('bare digits', normalizeUsPhone('2125550187'), '+12125550187');
  check('eleven digits', normalizeUsPhone('12125550187'), '+12125550187');
  check('too short', normalizeUsPhone('555-0187'), null);
  check('area zero', normalizeUsPhone('(023) 555-0187'), null);
  check('exchange one', normalizeUsPhone('212-155-0187'), null);
  check('letter', normalizeUsPhone('212555O187'), null);
  check('uk number', normalizeUsPhone('+44 20 7946 0958'), null);
  if (failures > 0) exit(1);
  print('core ok');
}
