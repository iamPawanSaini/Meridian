"""One-off, word-neutral reflow of prose lines over 100 characters (T04a finding 5).

Tables, headings, fenced code and lines MD013 would not flag are untouched. Inline code spans
with spaces are kept whole. Usage: python3 docs/tests/T04a/reflow_md.py FILE...
"""
import re
import sys

TOK = re.compile(r"(?:`[^`]*`|\S)+")
LIMIT = 100


def flagged(s: str) -> bool:
    return len(s) > LIMIT and re.match(r"^.{100}.*\s", s) is not None


def reflow(line: str) -> list[str]:
    m = re.match(r"^(\s*)([-*+] |\d+[.)] )?", line)
    assert m is not None
    ind, mark = m.group(1), m.group(2) or ""
    cont = " " * (len(ind) + len(mark))
    words = TOK.findall(line[len(m.group(0)):])
    out: list[str] = []
    cur = ind + mark
    empty = True
    for w in words:
        cand = cur + w if empty else cur + " " + w
        if len(cand) > LIMIT and not empty:
            out.append(cur)
            cur, empty = cont + w, False
        else:
            cur, empty = cand, False
    out.append(cur)
    return out


def main(paths: list[str]) -> int:
    risk = 0
    for p in paths:
        text = open(p, encoding="utf-8").read()
        res: list[str] = []
        fence = False
        n = 0
        for line in text.split("\n"):
            if re.match(r"\s*(```|~~~)", line):
                fence = not fence
                res.append(line)
                continue
            if fence or line.lstrip().startswith("|") or line.startswith("#") or not flagged(line):
                res.append(line)
                continue
            new = reflow(line)
            for extra in new[1:]:
                if re.match(r"\s*([-*+>]|\d+[.)]|#|\|)(\s|$)", extra):
                    print("RISK block marker at line start:", p, extra[:60])
                    risk += 1
            res.extend(new)
            n += 1
        open(p, "w", encoding="utf-8").write("\n".join(res))
        print(f"{p}: {n} lines reflowed")
    return 1 if risk else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
