/// Strict RFC-4180-style CSV parsing and encoding.

/// Parses CSV text into records of fields.
List<List<String>> parseCsv(String input) {
  if (input.isEmpty) return [];
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var pending = false; // a field is in progress (even if empty)
  var i = 0;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRecord() {
    endField();
    rows.add(row);
    row = <String>[];
    pending = false;
  }

  while (i < input.length) {
    final ch = input[i];
    if (ch == '"') {
      if (field.isNotEmpty) {
        throw FormatException('quote inside unquoted field at offset $i');
      }
      i++;
      var closed = false;
      while (i < input.length) {
        final c = input[i];
        if (c == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i += 2;
          } else {
            closed = true;
            i++;
            break;
          }
        } else {
          field.write(c);
          i++;
        }
      }
      if (!closed) throw FormatException('unterminated quoted field');
      pending = true;
      if (i < input.length) {
        final next = input[i];
        final crlf = next == '\r' &&
            i + 1 < input.length &&
            input[i + 1] == '\n';
        if (next != ',' && next != '\n' && !crlf) {
          throw FormatException(
              'unexpected character after closing quote at offset $i');
        }
      }
    } else if (ch == ',') {
      endField();
      pending = true; // the next field exists even if empty
      i++;
    } else if (ch == '\n') {
      endRecord();
      i++;
    } else if (ch == '\r') {
      if (i + 1 < input.length && input[i + 1] == '\n') {
        endRecord();
        i += 2;
      } else {
        throw FormatException('bare carriage return at offset $i');
      }
    } else {
      field.write(ch);
      pending = true;
      i++;
    }
  }
  if (pending || field.isNotEmpty || row.isNotEmpty) endRecord();
  return rows;
}

/// Encodes records as CSV text.
String encodeCsv(List<List<String>> rows) =>
    rows.map((row) => row.map(_encodeField).join(',')).join('\r\n');

String _encodeField(String field) {
  final needsQuotes = field.contains(',') ||
      field.contains('"') ||
      field.contains('\r') ||
      field.contains('\n');
  if (!needsQuotes) return field;
  return '"${field.replaceAll('"', '""')}"';
}
