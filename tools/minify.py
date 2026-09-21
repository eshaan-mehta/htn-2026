#!/usr/bin/env python3
"""Line-preserving Lua minifier for badge apps.

Keeps the 8-line badge-app header verbatim, then strips comments and all
optional whitespace. Every newline is kept, so line numbers are unchanged and
badge error lines map straight back to the readable source. Strings may span
lines with the \\z continuation escape. Long strings/comments ([[ ]]) are not
supported outside the header.

Note: the badge compiles the source in RAM, and stripped bytecode (luac -s) is
what its memory limit tracks, so minifying never changes whether an app fits.
It only makes the file smaller to paste and share.

usage: python3 tools/minify.py hlf_test.lua > hlf_test.min.lua
"""
import re
import sys

TOKEN = re.compile(r'''
    (?P<ws>\s+)
  | (?P<comment>--[^\n]*)
  | (?P<str>"(?:\\.|\\\n|[^"\\])*"|'(?:\\.|\\\n|[^'\\])*')
  | (?P<num>0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+)
  | (?P<name>[A-Za-z_]\w*)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|//|::|<<|>>|.)
''', re.VERBOSE | re.DOTALL)

WORD = re.compile(r'\w')


def needs_space(prev, nxt):
    if WORD.match(prev[-1]) and WORD.match(nxt[0]):
        return True
    if prev.endswith('.') and (nxt[0].isdigit() or nxt[0] == '.'):
        return True
    if prev[-1].isdigit() and nxt[0] == '.':
        return True
    if prev.endswith('-') and nxt.startswith('-'):
        return True
    if prev.endswith('[') and nxt.startswith('['):
        return True
    return False


def minify(body):
    out = []
    pos = 0
    while pos < len(body):
        m = TOKEN.match(body, pos)
        if not m:
            raise SystemExit(f'cannot tokenize: {body[pos:pos + 20]!r}')
        pos = m.end()
        kind = m.lastgroup
        tok = m.group()
        if kind == 'comment':
            continue
        if kind == 'ws':
            nl = tok.count('\n')
            if nl:
                out.append('\n' * nl)
            continue
        if kind == 'str':
            # after a \z continuation Lua skips all whitespace: keep only the newlines (for line numbers)
            tok = re.sub(r'(\\z)[ \t]*((?:\n[ \t]*)+)', lambda g: g.group(1) + '\n' * g.group(2).count('\n'), tok)
        if out and not out[-1].endswith('\n') and needs_space(out[-1], tok):
            out.append(' ')
        out.append(tok)
    return ''.join(out)


def main():
    src = open(sys.argv[1]).read()
    lines = src.split('\n')
    assert lines[0].startswith('--[==[') and lines[7].strip() == ']==]', 'unexpected header'
    head = '\n'.join(lines[:8]) + '\n'
    body = '\n'.join(lines[8:])
    if '--[[' in body or '--[=' in body or '[[' in body:
        raise SystemExit('long strings/comments unsupported outside the header')
    sys.stdout.write(head + minify(body))


if __name__ == '__main__':
    main()
