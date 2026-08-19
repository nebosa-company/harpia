"""CSV pivot reports."""

import csv
import io


def pivot(csv_text, index, columns, values, aggregate="sum"):
    if aggregate not in ("sum", "mean", "count"):
        raise ValueError(f"unknown aggregate {aggregate!r}")
    reader = csv.reader(io.StringIO(csv_text))
    try:
        header = next(reader)
    except StopIteration:
        raise ValueError("empty document")
    for name in (index, columns, values):
        if name not in header:
            raise ValueError(f"no column named {name!r}")
    ix, cx, vx = header.index(index), header.index(columns), header.index(values)

    groups = {}
    for row in reader:
        if not row:
            continue
        key = (row[ix], row[cx])
        groups.setdefault(key, []).append(row[vx])

    row_keys = sorted({k[0] for k in groups})
    col_keys = sorted({k[1] for k in groups})

    def cell(rk, ck):
        got = groups.get((rk, ck))
        if got is None:
            return ""
        if aggregate == "count":
            return str(len(got))
        try:
            nums = [float(v) for v in got]
        except ValueError:
            raise ValueError(f"non-numeric value in column {values!r}")
        total = sum(nums)
        if aggregate == "mean":
            total = total / len(nums)
        return f"{total:g}"

    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerow([index] + col_keys)
    for rk in row_keys:
        writer.writerow([rk] + [cell(rk, ck) for ck in col_keys])
    return buf.getvalue()
