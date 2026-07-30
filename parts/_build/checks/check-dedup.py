#!/usr/bin/env python3
"""check-dedup — near-duplicate (copy-paste) detector for Nix, the backstop to
the structural single-source-of-truth discipline (dendritic ownership + _lib
derivation). It surfaces LOGIC copy-paste that slipped past that discipline so it
can be extracted into a shared helper. Duplication of VALUES — the deliberate,
explicit per-host `enable` manifests — is NOT a defect and is never flagged.

Approach (inspired by dmtrKovalenko/fff: a rare-shingle index + local alignment):

  1. Tokenize each file; drop comments; reduce each string literal to a stable
     CONTENT HASH (identical strings match, different strings do not), keeping
     numbers and structure verbatim. Matching is thus near-verbatim — which is
     what real copy-paste is — so two unrelated `"key" = value` tables that merely
     share a SHAPE (e.g. sysctls vs a hex map) are not false-positived.
  2. Index k-token shingles. A shingle occurring in only 2..MAX_FILES distinct
     files is a copy-paste SEED. Idiomatic boilerplate (`mkOption`, `mkIf`, the
     `mkSimplePackage` manifest) occurs in MANY files, so it never seeds — the
     granular manifest is suppressed BY CONSTRUCTION, with no allowlist.
  3. Anchor on seeds and extend along the alignment diagonal (a copied block is a
     run of consecutive matching shingles), tolerating small edit gaps. This is an
     anchored local alignment — the seed-and-extend realization fff uses, rather
     than a naive O(n*m) Smith-Waterman pass over whole files.
  4. Report blocks whose aligned length >= MIN_TOKENS as `A:lines <-> B:lines`.

A `# dedup-ok` comment anywhere in either block's line span suppresses that block
(escape hatch for a deliberate, reviewed near-duplicate).

CLI:
  (no args)  gate: scan tracked *.nix, exit 1 if any block is found (pre-commit).
  --audit    same scan, verbose, always exit 0 (the one-off audit / tuning).
  FILE...    restrict the scan to these files (manual use / tests).

Tunables (env): DEDUP_K, DEDUP_MAX_FILES, DEDUP_MIN_TOKENS.
"""

import os
import re
import subprocess
import sys
import time
import zlib
from collections import defaultdict

K = int(os.environ.get("DEDUP_K", "14"))         # shingle length; a 14-token verbatim
#                                                  match across files is ~always a copy
MAX_FILES = int(os.environ.get("DEDUP_MAX_FILES", "3"))   # seed only if in 2..3 files
MIN_TOKENS = int(os.environ.get("DEDUP_MIN_TOKENS", "50"))  # egregious-copy threshold
GAP = 3  # consecutive-shingle gap tolerated when extending along a diagonal

# Excluded: generated files, and hosts/** — the dendritic composition root, whose
# per-host repetition (import manifests, explicit enable lists) is DELIBERATE
# granular config, not logic copy-paste. Hosts are exempt from the cross-module
# gates for the same reason; the dedup backstop polices MODULE logic.
EXCLUDE = re.compile(r"(^|/)hardware-configuration\.nix$|(^|/)hosts/|(^|/)_build/tests/")

# --- tokenizer -------------------------------------------------------------
_IND = re.compile(r"''.*?''", re.S)             # indented '' string '' (re.S: . spans newlines)
_DQ = re.compile(r'"(?:\\.|[^"\\])*"', re.S)     # "double" string
_BLOCK_C = re.compile(r"/\*.*?\*/", re.S)        # /* block comment */
_LINE_C = re.compile(r"(?m)(?:(?<=\s)|^)#.*$")    # # line comment
_TOK = re.compile(
    r"[0-9][0-9_.]*"                              # number (kept verbatim)
    r"|[A-Za-z_][A-Za-z0-9_'-]*"                  # identifier / keyword / S<crc> string token
    r"|\.\.\.|\+\+|//|->|==|!=|<=|>=|\|\||&&"
    r"|[{}()\[\];=:,.@?!<>$+*/-]"
)


def _blank_keep_nl(s):
    return "\n" * s.count("\n")


def _str_tok(m):
    """Reduce a string to a stable content-hash token `S<crc>`; preserve newlines
    so reported line numbers stay accurate."""
    crc = zlib.crc32(m.group(0).encode("utf-8", "replace")) & 0xFFFFFF
    return f" S{crc:06x} " + _blank_keep_nl(m.group(0))


def tokenize(text):
    """Return a list of (token, line): comments dropped, each string reduced to a
    content-hash token, numbers and structure kept verbatim."""
    text = _IND.sub(_str_tok, text)
    text = _DQ.sub(_str_tok, text)
    text = _BLOCK_C.sub(lambda m: _blank_keep_nl(m.group(0)), text)
    text = _LINE_C.sub("", text)
    toks, line, pos = [], 1, 0
    for m in _TOK.finditer(text):
        line += text.count("\n", pos, m.start())
        pos = m.start()
        toks.append((m.group(0), line))
    return toks


# --- corpus ----------------------------------------------------------------
def list_files(args):
    files = [a for a in args if not a.startswith("-")]
    if files:
        return [f for f in files if f.endswith(".nix") and not EXCLUDE.search(f)]
    out = subprocess.run(
        ["git", "ls-files", "*.nix"], capture_output=True, text=True
    ).stdout.split()
    return [f for f in out if not EXCLUDE.search(f)]


def main():
    audit = "--audit" in sys.argv
    files = list_files(sys.argv[1:])
    file_toks = {}
    occ = defaultdict(list)          # shingle -> [(file, start_idx)]
    shingle_files = defaultdict(set)  # shingle -> {file}
    _t0 = time.perf_counter()
    for f in files:
        try:
            text = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        toks = tokenize(text)
        file_toks[f] = toks
        seq = [t for t, _ in toks]
        for i in range(len(seq) - K + 1):
            sh = tuple(seq[i : i + K])
            shingle_files[sh].add(f)
            occ[sh].append((f, i))

    if os.environ.get("DEDUP_TIME"):
        sys.stderr.write(f"[t] index {len(shingle_files)}sh {time.perf_counter()-_t0:.1f}s\n"); sys.stderr.flush(); _t0 = time.perf_counter()

    # candidate file-pairs and their anchor positions, from rare seeds only
    pair_anchors = defaultdict(list)  # (fa,fb) sorted -> [(ia, ib)]
    for sh, fs in shingle_files.items():
        if not (2 <= len(fs) <= MAX_FILES):
            continue
        occs = occ[sh]
        if len(occs) > 40:  # pathological repetition: skip (not a clone signal)
            continue
        for x in range(len(occs)):
            fa, ia = occs[x]
            for y in range(x + 1, len(occs)):
                fb, ib = occs[y]
                if fa == fb:
                    continue
                if fa < fb:
                    pair_anchors[(fa, fb)].append((ia, ib))
                else:
                    pair_anchors[(fb, fa)].append((ib, ia))

    if os.environ.get("DEDUP_TIME"):
        sys.stderr.write(f"[t] pairs {len(pair_anchors)} {time.perf_counter()-_t0:.1f}s\n"); sys.stderr.flush(); _t0 = time.perf_counter()

    blocks = []  # (matched, fa, la0, la1, fb, lb0, lb1)
    for (fa, fb), anchors in pair_anchors.items():
        by_diag = defaultdict(list)
        for ia, ib in anchors:
            by_diag[ia - ib].append(ia)
        for d, ias in by_diag.items():
            ias = sorted(set(ias))
            start = prev = ias[0]
            for x in list(ias[1:]) + [None]:
                if x is not None and x - prev <= GAP:
                    prev = x
                    continue
                a0, a1 = start, prev + K           # token span in A
                b0, b1 = start - d, prev + K - d   # token span in B
                matched = a1 - a0                  # aligned block length (tokens)
                if matched >= MIN_TOKENS:
                    la0 = file_toks[fa][a0][1]
                    la1 = file_toks[fa][min(a1, len(file_toks[fa])) - 1][1]
                    lb0 = file_toks[fb][b0][1]
                    lb1 = file_toks[fb][min(b1, len(file_toks[fb])) - 1][1]
                    blocks.append((matched, fa, la0, la1, fb, lb0, lb1))
                if x is not None:
                    start = prev = x

    if os.environ.get("DEDUP_TIME"):
        sys.stderr.write(f"[t] blocks {len(blocks)} {time.perf_counter()-_t0:.1f}s\n"); sys.stderr.flush(); _t0 = time.perf_counter()

    # dedup overlapping reports per file-pair; apply `# dedup-ok` suppression
    def suppressed(f, l0, l1):
        lines = open(f, encoding="utf-8", errors="replace").read().splitlines()
        return any("# dedup-ok" in ln for ln in lines[max(0, l0 - 1) : l1])

    seen = set()
    final = []
    for matched, fa, la0, la1, fb, lb0, lb1 in sorted(blocks, reverse=True):
        key = (fa, fb, la0 // 4, lb0 // 4)
        if key in seen:
            continue
        seen.add(key)
        if suppressed(fa, la0, la1) or suppressed(fb, lb0, lb1):
            continue
        final.append((matched, fa, la0, la1, fb, lb0, lb1))

    if not final:
        if audit:
            print(f"check-dedup: scanned {len(files)} files — no near-duplicate blocks "
                  f"(K={K}, MIN_TOKENS={MIN_TOKENS}, MAX_FILES={MAX_FILES}).")
        return 0

    print("check-dedup: near-duplicate logic blocks (extract into a shared "
          "helper, or add `# dedup-ok` if a deliberate near-duplicate):")
    for matched, fa, la0, la1, fb, lb0, lb1 in final:
        print(f"  ~{matched} tok  {fa}:{la0}-{la1}  <->  {fb}:{lb0}-{lb1}")
    return 0 if audit else 1


if __name__ == "__main__":
    sys.exit(main())
