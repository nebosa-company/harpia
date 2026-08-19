from minilisp import LispError, run

# quote
assert run("(quote abc)") == "abc"
assert run("(quote 5)") == 5
assert run("(quote (1 2 3))") == [1, 2, 3]
assert run("(quote (a (b c)))") == ["a", ["b", "c"]]
assert run("(quote ())") == []

# lists
assert run("(list 1 2 3)") == [1, 2, 3]
assert run("(list)") == []
assert run("(car (list 1 2 3))") == 1
assert run("(cdr (list 1 2 3))") == [2, 3]
assert run("(cons 0 (list 1 2))") == [0, 1, 2]
assert run("(cons 1 (list))") == [1]
assert run("(null? (list))") is True
assert run("(null? (list 1))") is False
assert run("(length (list 1 2 3 4))") == 4
assert run("(length (list))") == 0

# equal? / not / abs / min / max
assert run("(equal? (list 1 2) (list 1 2))") is True
assert run("(equal? (list 1 2) (list 2 1))") is False
assert run("(equal? 3 3)") is True
assert run("(not #f)") is True
assert run("(not 0)") is False
assert run("(abs -4)") == 4
assert run("(min 3 1 2)") == 1
assert run("(max 3 1 2)") == 3

# floats and mixed arithmetic
assert run("(+ 0.5 0.25)") == 0.75
assert run("(* 2 1.5)") == 3.0

# comments and whitespace
assert run("; a comment\n(+ 1 ; midline\n 2)") == 3
assert run("\n\n  (+ 1\t2)\n") == 3

# empty program
assert run("") is None

# if without else
assert run("(if #f 1)") is None
assert run("(if #t 1)") == 1

# shadowing in let does not leak
assert run("(define x 1) (let ((x 99)) x)") == 99
assert run("(define x 1) (let ((x 99)) x) x") == 1

# errors
for bad in [
    "(undefined-symbol)",
    "nope",
    "(car (list))",
    "(cdr (list))",
    "(car 5)",
    "((lambda (x) x) 1 2)",
    "((lambda (x y) x) 1)",
    "(1 2 3)",
    "(+ 1",
    ")",
    "(set! ghost 1)",
]:
    try:
        run(bad)
    except LispError:
        pass
    else:
        raise AssertionError(f"run({bad!r}) should raise LispError")

# set! reaches the nearest enclosing scope only
assert run(
    "(define n 5)"
    "(define bump (lambda () (set! n (+ n 1))))"
    "(bump) (bump) n"
) == 7

print("ok")
