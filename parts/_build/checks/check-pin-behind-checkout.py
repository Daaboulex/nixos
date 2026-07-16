"""check-pin-behind-checkout -- flake.lock pins vs local repos/ workbenches.

The gap this closes: a fix is committed and pushed in repos/<x>, but
`nix flake update <x>` is forgotten, so the flake keeps deploying the stale
pin while the workbench looks done.

Scope: DIRECT flake inputs (root.inputs) pinned to github:Daaboulex/*, plus
git+file inputs whose URL points under repos/ (site). Transitive pins are
each fleet repo's own CI concern. A machine without repos/ (CI) or without
a given checkout has no workbench to drift from and is skipped.

Verdicts per input:
  pin == HEAD               OK
  pin ancestor of HEAD      FAIL   (pin behind committed local work)
  HEAD ancestor of pin      notice (workbench behind: pull)
  pin not in local history  notice (workbench stale: pull)
  otherwise                 FAIL   (histories diverged: reconcile)

Exit: 0 clean or notices only, 1 on any FAIL.
Usage: check-pin-behind-checkout [root]  (root defaults to cwd)
"""

import json
import os
import subprocess
import sys


def git(repo_dir, *args):
    return subprocess.run(
        ["git", "-C", repo_dir, *args], capture_output=True, text=True, check=False
    )


def workbench_dir(repos_dir, locked):
    if locked.get("type") == "github" and locked.get("owner") == "Daaboulex":
        return os.path.join(repos_dir, locked["repo"])
    if locked.get("type") == "git" and "/repos/" in locked.get("url", ""):
        rel = locked["url"].rstrip("/").rsplit("/repos/", 1)[1]
        return os.path.join(repos_dir, rel)
    return None


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    lock_path = os.path.join(root, "flake.lock")
    repos_dir = os.path.join(root, "repos")
    if not os.path.isfile(lock_path):
        print("check-pin-behind-checkout: no flake.lock -- nothing to check")
        return 0
    if not os.path.isdir(repos_dir):
        print("check-pin-behind-checkout: no repos/ workbenches here -- skipped")
        return 0

    with open(lock_path) as f:
        nodes = json.load(f)["nodes"]

    failed = []
    for name, key in sorted(nodes["root"]["inputs"].items()):
        if not isinstance(key, str):
            continue
        locked = nodes.get(key, {}).get("locked", {})
        pin = locked.get("rev")
        if not pin:
            continue
        wb = workbench_dir(repos_dir, locked)
        if wb is None or not os.path.isdir(os.path.join(wb, ".git")):
            continue
        head = git(wb, "rev-parse", "HEAD").stdout.strip()
        if not head or head == pin:
            continue
        if git(wb, "cat-file", "-e", pin + "^{commit}").returncode != 0:
            print(
                f"  notice: {name}: pin {pin[:7]} not in {wb} history"
                f" -- workbench stale: git -C {wb} pull --ff-only"
            )
            continue
        if git(wb, "merge-base", "--is-ancestor", pin, head).returncode == 0:
            print(f"ERROR: {name}: pin {pin[:7]} is BEHIND workbench HEAD {head[:7]} ({wb})")
            print(f"       committed local work is not deployed. Fix: nix flake update {name}")
            failed.append(name)
        elif git(wb, "merge-base", "--is-ancestor", head, pin).returncode == 0:
            print(
                f"  notice: {name}: workbench {head[:7]} behind pin {pin[:7]}"
                f" -- git -C {wb} pull --ff-only"
            )
        else:
            print(f"ERROR: {name}: pin {pin[:7]} and workbench HEAD {head[:7]} DIVERGED ({wb})")
            print(f"       reconcile the workbench, then: nix flake update {name}")
            failed.append(name)

    if failed:
        print()
        print(f"{len(failed)} input pin(s) out of sync with their workbench.")
        print("To bypass for this commit: SKIP=check-pin-behind-checkout git commit ...")
        return 1
    print("check-pin-behind-checkout: all input pins in sync with their workbenches")
    return 0


if __name__ == "__main__":
    sys.exit(main())
