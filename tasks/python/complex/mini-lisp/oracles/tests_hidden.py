from minilisp import LispError, run

# atoms and arithmetic
assert run("42") == 42
assert run("-7") == -7
assert run("3.5") == 3.5
assert run("#t") is True
assert run("#f") is False
assert run("(+ 1 2)") == 3
assert run("(+ 1 2 3 4)") == 10
assert run("(- 10 4)") == 6
assert run("(* 2 3 4)") == 24
assert run("(/ 7 2)") == 3.5
assert run("(+ (* 2 3) (- 10 4))") == 12

# comparisons
assert run("(< 1 2)") is True
assert run("(> 1 2)") is False
assert run("(<= 2 2)") is True
assert run("(>= 1 2)") is False
assert run("(= 3 3)") is True
assert run("(= 3 4)") is False

# define and multiple top-level expressions
assert run("(define x 10) (define y 4) (- x y)") == 6

# if: only #f is false, only the taken branch evaluates
assert run("(if #t 1 2)") == 1
assert run("(if #f 1 2)") == 2
assert run("(if 0 1 2)") == 1
assert run("(if (quote ()) 1 2)") == 1
assert run("(define trap (lambda () (car (list)))) (if #t 5 (trap))") == 5

# lambda, application, closures
assert run("((lambda (x) (* x x)) 9)") == 81
assert run("(define sq (lambda (n) (* n n))) (sq 12)") == 144
assert run(
    "(define make-adder (lambda (n) (lambda (x) (+ x n))))"
    "(define add5 (make-adder 5))"
    "(add5 37)"
) == 42

# recursion
assert run(
    "(define fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))"
    "(fact 10)"
) == 3628800
assert run(
    "(define fib (lambda (n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2))))))"
    "(fib 15)"
) == 610

# let and begin
assert run("(let ((a 2) (b 3)) (+ a b))") == 5
assert run("(begin 1 2 3)") == 3
assert run("(define r (let ((x 2)) (begin (define y 3) (* x y)))) r") == 6

# set! and stateful closures
assert run(
    "(define make-counter (lambda ()"
    "  (let ((n 0)) (lambda () (begin (set! n (+ n 1)) n)))))"
    "(define c (make-counter))"
    "(c) (c) (c)"
) == 3

print("ok")
