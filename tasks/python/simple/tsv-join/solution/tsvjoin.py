"""TSV inner join."""


def _parse(doc):
    lines = doc.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if not lines:
        raise ValueError("empty document")
    header = lines[0].split("\t")
    rows = []
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) != len(header):
            raise ValueError(f"row has {len(fields)} fields, header has {len(header)}")
        rows.append(fields)
    return header, rows


def inner_join(left, right, key):
    lheader, lrows = _parse(left)
    rheader, rrows = _parse(right)
    if key not in lheader or key not in rheader:
        raise ValueError(f"key column {key!r} missing")
    lk = lheader.index(key)
    rk = rheader.index(key)

    out_header = [key]
    out_header += [c for i, c in enumerate(lheader) if i != lk]
    out_header += [c for i, c in enumerate(rheader) if i != rk]

    lines = ["\t".join(out_header)]
    for lrow in lrows:
        for rrow in rrows:
            if lrow[lk] == rrow[rk]:
                row = [lrow[lk]]
                row += [v for i, v in enumerate(lrow) if i != lk]
                row += [v for i, v in enumerate(rrow) if i != rk]
                lines.append("\t".join(row))
    return "\n".join(lines) + "\n"
