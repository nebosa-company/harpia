from pivot import pivot

sales = "\n".join(
    [
        "region,quarter,amount",
        "east,Q1,100",
        "east,Q2,150",
        "west,Q1,200",
        "east,Q1,50",
        "west,Q2,25.5",
    ]
) + "\n"

out = pivot(sales, "region", "quarter", "amount")
assert out == "region,Q1,Q2\neast,150,150\nwest,200,25.5\n", repr(out)

out = pivot(sales, "region", "quarter", "amount", aggregate="count")
assert out == "region,Q1,Q2\neast,2,1\nwest,1,1\n", repr(out)

# missing combinations are empty cells
gaps = "\n".join(
    [
        "person,day,hours",
        "ann,mon,8",
        "bob,tue,6",
        "ann,tue,7",
    ]
) + "\n"
out = pivot(gaps, "person", "day", "hours")
assert out == "person,mon,tue\nann,8,7\nbob,,6\n", repr(out)

# rows and columns sorted ascending as strings
scramble = "\n".join(
    [
        "k,c,v",
        "zeta,b2,1",
        "alpha,a1,2",
        "mid,c3,3",
        "alpha,b2,4",
    ]
) + "\n"
out = pivot(scramble, "k", "c", "v")
assert out == "k,a1,b2,c3\nalpha,2,4,\nmid,,,3\nzeta,,1,\n", repr(out)

# sum keeps float behavior but formats via :g
floats = "id,g,x\na,p,0.5\na,p,0.25\nb,p,2\n"
out = pivot(floats, "id", "g", "x")
assert out == "id,p\na,0.75\nb,2\n", repr(out)

print("ok")
