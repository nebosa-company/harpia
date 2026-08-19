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
  check('empty', normalizeUsPhone(''), null);
  check('double plus', normalizeUsPhone('++12125550187'), null);
  check('plus late', normalizeUsPhone('212+5550187'), null);
  check('plus without one', normalizeUsPhone('+2125550187'), null);
  check('plus then short', normalizeUsPhone('+1212555018'), null);
  check('eleven no one', normalizeUsPhone('22125550187'), null);
  check('twelve digits', normalizeUsPhone('112125550187'), null);
  check('strange grouping', normalizeUsPhone('2 125 550 187'), '+12125550187');
  check('separators anywhere', normalizeUsPhone('2(1)2-555.01 87'),
      '+12125550187');
  check('area one', normalizeUsPhone('1234567890'), null);
  check('exchange zero', normalizeUsPhone('212-055-0187'), null);
  check('trailing junk', normalizeUsPhone('2125550187x'), null);
  check('only separators', normalizeUsPhone('()-. '), null);
  if (failures > 0) exit(1);
  print('edge ok');
}
