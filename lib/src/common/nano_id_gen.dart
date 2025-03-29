import 'dart:math';

const String _hexDigits = '0123456789ABCDEFGHIJKMLN';

/// Generate a random hexadecimal id
/// based in the length passed
String nanoid([int length = 8]) {
  final Random random = Random.secure();
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < length; i++) {
    buffer.write(_hexDigits[random.nextInt(_hexDigits.length)]);
  }

  return buffer.toString();
}
