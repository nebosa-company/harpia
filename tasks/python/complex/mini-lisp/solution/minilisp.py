"""A small Lisp interpreter."""


class LispError(Exception):
    pass


# ---------------------------------------------------------------- parsing

def _tokenize(src):
    tokens = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c == ";":
            while i < n and src[i] != "\n":
                i += 1
        elif c in "()":
            tokens.append(c)
            i += 1
        elif c.isspace():
            i += 1
        else:
            j = i
            while j < n and not src[j].isspace() and src[j] not in "();":
                j += 1
            tokens.append(src[i:j])
            i = j
    return tokens


def _atom(token):
    if token == "#t":
        return True
    if token == "#f":
        return False
    try:
        return int(token)
    except ValueError:
        pass
    try:
        return float(token)
    except ValueError:
        pass
    return token  # symbol, as str


def _parse_all(src):
    tokens = _tokenize(src)
    pos = 0

    def read():
        nonlocal pos
        if pos >= len(tokens):
            raise LispError("unexpected end of input")
        tok = tokens[pos]
        pos += 1
        if tok == "(":
            items = []
            while True:
                if pos >= len(tokens):
                    raise LispError("missing closing parenthesis")
                if tokens[pos] == ")":
                    pos += 1
                    return items
                items.append(read())
        if tok == ")":
            raise LispError("unexpected closing parenthesis")
        return _atom(tok)

    forms = []
    while pos < len(tokens):
        forms.append(read())
    return forms


# ------------------------------------------------------------ environment

class _Env:
    def __init__(self, parent=None):
        self.vars = {}
        self.parent = parent

    def lookup(self, name):
        env = self
        while env is not None:
            if name in env.vars:
                return env.vars[name]
            env = env.parent
        raise LispError(f"unbound symbol: {name}")

    def define(self, name, value):
        self.vars[name] = value

    def assign(self, name, value):
        env = self
        while env is not None:
            if name in env.vars:
                env.vars[name] = value
                return
            env = env.parent
        raise LispError(f"set! of unbound symbol: {name}")


class _Lambda:
    def __init__(self, params, body, env):
        self.params = params
        self.body = body
        self.env = env

    def __call__(self, *args):
        if len(args) != len(self.params):
            raise LispError(
                f"expected {len(self.params)} arguments, got {len(args)}"
            )
        env = _Env(self.env)
        for name, value in zip(self.params, args):
            env.define(name, value)
        result = None
        for expr in self.body:
            result = _eval(expr, env)
        return result


# ---------------------------------------------------------------- builtins

def _need_numbers(args, op):
    for a in args:
        if isinstance(a, bool) or not isinstance(a, (int, float)):
            raise LispError(f"{op} expects numbers")


def _add(*args):
    if len(args) < 2:
        raise LispError("+ expects at least 2 arguments")
    _need_numbers(args, "+")
    total = args[0]
    for a in args[1:]:
        total = total + a
    return total


def _mul(*args):
    if len(args) < 2:
        raise LispError("* expects at least 2 arguments")
    _need_numbers(args, "*")
    total = args[0]
    for a in args[1:]:
        total = total * a
    return total


def _sub(a, b):
    _need_numbers((a, b), "-")
    return a - b


def _div(a, b):
    _need_numbers((a, b), "/")
    if b == 0:
        raise LispError("division by zero")
    return a / b


def _car(lst):
    if not isinstance(lst, list) or not lst:
        raise LispError("car expects a non-empty list")
    return lst[0]


def _cdr(lst):
    if not isinstance(lst, list) or not lst:
        raise LispError("cdr expects a non-empty list")
    return lst[1:]


def _cons(item, lst):
    if not isinstance(lst, list):
        raise LispError("cons expects a list as its second argument")
    return [item] + lst


def _null(lst):
    return isinstance(lst, list) and not lst


def _length(lst):
    if not isinstance(lst, list):
        raise LispError("length expects a list")
    return len(lst)


def _minmax(fn, name):
    def impl(*args):
        if len(args) < 2:
            raise LispError(f"{name} expects at least 2 arguments")
        _need_numbers(args, name)
        return fn(args)

    return impl


def _global_env():
    env = _Env()
    env.vars.update(
        {
            "+": _add,
            "-": _sub,
            "*": _mul,
            "/": _div,
            "<": lambda a, b: a < b,
            ">": lambda a, b: a > b,
            "<=": lambda a, b: a <= b,
            ">=": lambda a, b: a >= b,
            "=": lambda a, b: a == b,
            "abs": lambda a: abs(a),
            "min": _minmax(min, "min"),
            "max": _minmax(max, "max"),
            "not": lambda a: a is False,
            "equal?": lambda a, b: a == b,
            "list": lambda *items: list(items),
            "cons": _cons,
            "car": _car,
            "cdr": _cdr,
            "null?": _null,
            "length": _length,
        }
    )
    return env


# -------------------------------------------------------------- evaluation

def _quote_datum(datum):
    return datum


def _eval(expr, env):
    if isinstance(expr, str):
        return env.lookup(expr)
    if not isinstance(expr, list):
        return expr  # number or boolean

    if not expr:
        raise LispError("cannot evaluate the empty list")

    head = expr[0]
    if head == "define":
        if len(expr) != 3 or not isinstance(expr[1], str):
            raise LispError("malformed define")
        env.define(expr[1], _eval(expr[2], env))
        return None
    if head == "set!":
        if len(expr) != 3 or not isinstance(expr[1], str):
            raise LispError("malformed set!")
        env.assign(expr[1], _eval(expr[2], env))
        return None
    if head == "if":
        if len(expr) not in (3, 4):
            raise LispError("malformed if")
        cond = _eval(expr[1], env)
        if cond is not False:
            return _eval(expr[2], env)
        if len(expr) == 4:
            return _eval(expr[3], env)
        return None
    if head == "lambda":
        if len(expr) < 3 or not isinstance(expr[1], list):
            raise LispError("malformed lambda")
        params = expr[1]
        if not all(isinstance(p, str) for p in params):
            raise LispError("lambda parameters must be symbols")
        return _Lambda(params, expr[2:], env)
    if head == "let":
        if len(expr) < 3 or not isinstance(expr[1], list):
            raise LispError("malformed let")
        scope = _Env(env)
        for binding in expr[1]:
            if not (
                isinstance(binding, list)
                and len(binding) == 2
                and isinstance(binding[0], str)
            ):
                raise LispError("malformed let binding")
            scope.define(binding[0], _eval(binding[1], env))
        result = None
        for body_expr in expr[2:]:
            result = _eval(body_expr, scope)
        return result
    if head == "begin":
        result = None
        for sub in expr[1:]:
            result = _eval(sub, env)
        return result
    if head == "quote":
        if len(expr) != 2:
            raise LispError("malformed quote")
        return _quote_datum(expr[1])

    fn = _eval(head, env)
    if not callable(fn):
        raise LispError(f"not a function: {fn!r}")
    args = [_eval(arg, env) for arg in expr[1:]]
    try:
        return fn(*args)
    except LispError:
        raise
    except TypeError as e:
        raise LispError(str(e))


def run(src):
    forms = _parse_all(src)
    env = _global_env()
    result = None
    for form in forms:
        result = _eval(form, env)
    return result
