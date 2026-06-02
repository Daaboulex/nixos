# NixOS Config Audit — 2026-05-29

> **Scratch deliverable, untracked.** Lives at repo root by intent (not `docs/`, not the deleted
> `.ai-context/`). Zero edits were made to the tree to produce this. Delete it once executed.
>
> **Method.** Deterministic `rg` sweeps (coupling edges, comment density, option ownership,
> band-aid markers) + 17 read-only analysis agents over the three 1000+-line files, every custom
> component, the comment hotspots, and a security/standards pass. Every finding scored through one
> lens: _does this reduce friction and compound, or add policing?_
>
> **Scope.** 296 `.nix` files, ~27k lines. `repos/` (your ~25 personal `*-nix` flakes) excluded.

## Verdict legend

`remove` · `relocate` · `replace` (swap for upstream/declarative) · `refactor` · `simplify` ·
`enforce` (turn a comment/manual step into a build-time check) · `keep` (validated, no action).
Friction: `↓` reduces · `=` neutral · `⊟` removes-policing · `↑` currently _adds_ friction (fix it).

---

## §0 — Executive summary

**The bones are excellent. The debt is localized, not pervasive.** Standards conformance is, in the
agents' words, "among the cleanest assessed against its own rules": nixfmt/RFC-166 clean across all
388 files, no `with lib;`, disciplined `mkIf`/`mkDefault`/`mkForce`, namespace 100% self-consistent
(0 path↔name mismatches, 0 legacy exports), and **option `description` coverage is ~100% (422
`mkOption`, 0 missing)** — so "descriptions-as-docs" is already real and drift-free.

The four problem dimensions:

| Dim                           | Headline                                                                                                                                                                                       | Severity                         |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| **A — Docs/comments**         | Docs pipeline is **broken & orphaned** (`nix build .#docs` never runs the generator; nrb calls a deleted script). Comment pollution is real but **localized to the two host files**.           | High value, low risk to fix      |
| **B — Dendritic coupling**    | Invariant is **almost perfectly held**. Exactly **one true violation** (`_kernelPostPatch` phantom-field read). Rest are accepted bridges + a handful of host→module _relocate_ opportunities. | Low — your design works          |
| **C — NIH / machinery**       | The test harness is **orphaned** (CI never runs `nix flake check`). `modules-hierarchy.nix` is **now upstream**. `home/lib` is **mislocated**. nrb is a 1309-line zsh heredoc.                 | Medium                           |
| **D — Band-aid → root-cause** | The **mDNS/`.local` fleet-resolution** decay (5 stacked workarounds across 5 files) + the nrb **kernel-safe-update** runtime bisection. Both want one declarative source of truth.             | Medium — your instinct was right |

Security is strong (key-only PQ-hybrid SSH, sound agenix model, lanzaboote, the `nrb-activate` sudo
wrapper is a textbook mitigation). Gaps are baseline-coverage, plus one **false assurance** (the
hardening header advertises AppArmor that is never configured).

---

## §1 — Dimension A · Documentation & comments

### A.1 Remove the docs pipeline (it is already dead code)

- [ ] **`scripts/generate-all-docs.nix` (553L)** — `nix build .#docs` _never invokes it_; orphaned. `remove` ↓
- [ ] **`parts/_build/docs.nix`** + its import at `parts/flake-module.nix:40` — mdBook ships placeholder "Reference" pages that tell you to run the command that produced them. `remove` ↓
- [ ] **`docs/book.toml` + `docs/src/`** (symlinks, `SUMMARY.md`, `reference/`) + stale `docs/src/result` symlink. `remove` ↓
- [ ] **`nrb-functions.nix:1127-1136`** — post-switch regen calls **nonexistent** `scripts/generate-docs.nix` behind `2>/dev/null`; silent no-op every rebuild. `remove` ↓ _(also Dim D)_
- [ ] **`git rm --cached docs/OPTIONS.md.tmp`** — stray 0-byte file accidentally tracked. `remove` ↓
- [ ] **`treefmt.nix:11-14, 48-53`** + **`.gitignore:79-84`** — dead excludes for generated artifacts that don't exist. `remove` ↓
- [ ] **`README.md:45` / `CONTRIBUTING.md:45`** — drop the `nix build .#docs` advertisement. `remove` ↓
- ✅ **Replacement validated:** 527 in-code `description` strings (high quality) + `nix flake show`. If a rendered page is ever wanted, a ~10-line `pkgs.nixosOptionsDoc` derivation — not the 553-line bespoke generator.

### A.2 Collapse prose docs → ONE lean README

- [ ] **Delete** `docs/{ARCHITECTURE,DEVELOPMENT,INSTALLATION,NETWORKING,SECRETS,SECURE-BOOT,USAGE}.md`, `docs/archive/`, `home/modules/{neovim,yazi}/README.md`, `scripts/README.md` (lists **7 nonexistent scripts**), `CONTRIBUTING.md`. `remove` ↓
- [ ] **Write the new `README.md`** (9 sections, ~70-90 lines, table-driven): ① title + the two timeless intro sentences (`README:5`,`:7`) kept verbatim · ② Hosts (hostname/CPU/arch/tier/role — **drop the kernel column**, the `xanmod` row is already stale) · ③ Build & deploy (nrb command table + `nrb --help` canonical — current README omits `--deploy/--boot/--list/--update-no-kernel`) · ④ Layout map · ⑤ Adding a module · ⑥ Adding a host · ⑦ Secrets (agenix pointer) · ⑧ `nix flake show` · ⑨ License. `replace` ↓
- [ ] **Replace all hardcoded counts** ("74 NixOS / 152 HM / 6 lib"; USAGE says "76+") with `nix flake show`. `replace` ↓

### A.3 ⚠ STYLE.md is load-bearing — do not delete naively

**6 enforcement hooks emit errors citing "STYLE §x.x"** (`git-hooks.nix`). Deleting `docs/STYLE.md`
orphans those references and breaks the error messages' usefulness.

- [ ] **Decision required (see questions below):** keep `STYLE.md` as the _one_ permitted non-README doc the hooks point to, **or** inline the cited rules into the hook error messages themselves and delete it. Either way its substance must survive somewhere the messages still resolve.

### A.4 Comment standard — apply the 3-tier policy (delete narration · keep timeless landmines · enforce where cheap)

Pollution is **concentrated in the two host files** (388 + 352 comment lines). Classification already done:

- [ ] **DELETE (AI session-narration):** the `scx` ~34-line "observation protocol/revert runbook" (`macbook:434-468`); "WiFi-break recovery (2026-04-16)" blocks (`macbook:192-201`, `ryzen:158-166`); "leftover from a pre-latency-tuning phase / Do not re-add" (`macbook:660-672`); "10:05 and 10:19 today" journald block (`macbook:954-960`); `ryzen:418-419, 776-783`. `remove` ↓
- [ ] **KEEP, rewritten timeless (genuine hardware landmines):** libata "both flags in ONE param" (`macbook:635-643`, highest-value), cpufreq_schedutil stub (`687-693`), mq-deadline↔noncq (`833-841`); ryzen `loglevel`/Plymouth (`72`), ath12k `cma=64M` (`87`), `KWIN_DRM_DEVICES` `:` parser (`626-628`), ACS group-22 security trade-off (`608-628`). `keep`
- [ ] **ENFORCE (comment → check):** win11 NVMe↔cryptroot BDF-swap "RE-VERIFY by hand" warning → static assertion (runtime `protectedDiskGuard` already exists; `ryzen:735-748`); vms.nix empirical `sleep 8` → bounded-poll-then-abort (the file already does this for hugepages; `vms.nix:371-373`). `enforce` ↓
- [ ] **Module-file banners:** `vms.nix:96-98,167-169` Phase-1/2 box banners violate STYLE §4.3 (banners are host-file-only) → plain one-liners. `simplify` =
- [ ] **Drift-prone counts/dates in module docstrings:** "Thirty+ callsites" (`mkSettingsOption:12`, actual 29), "Twenty-three" (`mergeSettings:14`, actual 27), "import-tree was rejected (2026-04-15)" (`home-modules.nix:6`), "Extracted for testability" (`nrb-functions:1-2`), `ADV-001/002` tracker IDs, "Added 2026-04-21" (`tests.nix:227`). `simplify` ↓
- ✅ **Host `# ===` banners + `# (default)` markers in `parts/hosts/*/default.nix` are STYLE-mandated — keep.**

### A.5 Two comments are outright WRONG (correctness bugs, not style)

- [ ] **`git-hooks.nix:394-401`** — the `check-behind-remote` rationale is physically attached above `check-secrets-leak`, cut off mid-sentence ("once per"). Relocate to its real hook (`:436`); give secrets-leak its own header. `relocate` ↓
- [ ] **`git-hooks.nix:335-339`** — `check-module-docstring` header says "ADVISORY (exit 0)" but the code **blocks with exit 1**. Delete the stale paragraph. `simplify` ↓
- [ ] **`tests.nix:304-316`** — orphaned mesa-git "Assertion strategy" essay sitting above the pipewire test. `relocate` ↓

---

## §2 — Dimension B · Dendritic coupling

**Your invariant ("a module owns its whole domain; no other modifies it") is almost perfectly held.**
The deterministic map found 117 modules each reading only their own `cfg`; cross-boundary reads classify as:

### B.1 The one true violation

- [ ] **`parts/boot/kernel.nix:284`** reads `config.myModules.vfio.stealth._kernelPostPatch or ""` — an `_`-private field **declared nowhere in the tree**, owned by the external `vfio-stealth` flake (your own repo), imported only on ryzen. The `or ""` silently no-ops a kernel security patch on hosts without it. **Promote to a public `myModules.vfio.stealth.kernelPostPatch` option (default `""`) in vfio-stealth, consume without `or ""`** so a missing patch fails at eval. `replace` · risk med ↓ _(also Dim D)_

### B.2 Accepted — validated, no action (the bridges work)

- ✅ HM→system `osConfig` reads (btop/displays/neovim/plasma/yeetmouse) are clean, guarded, read-only public-option bridges. _(The brief's "neovim reads theme module" is intra-HM via `themeCtx` — a non-issue.)_
- ✅ Host→module preset reads (`syncthing.defaultIgnorePatterns`, `goxlr.eq.presets`) = composition root using a public contract.
- ✅ `users.users.*.extraGroups` additive writes from 10 files = idiomatic NixOS merge (invariant binds _option_ ownership, not additive config).
- ✅ Umbrella `default.nix` importing own sub-files; `_vms-lib.nix`; `drivers/*` callPackage; `myLib` via specialArgs — all sanctioned.

### B.3 Host → module _relocate_ opportunities (logic that drifted into hosts)

- [ ] **`ryzen:863`** inline NVMe `services.udev.extraRules` (rq_affinity/nr_requests) → typed `myModules.storage.nvmeTuning.*`. `relocate` ↓
- [ ] **`home/hosts/ryzen:519-543`** 20-line ADB-ProxyCommand `writeShellScript` inline in SSH config → HM module driven by `site.hosts.pixel-9-pro.adb`. `relocate` ↓
- [ ] **Mullvad settings block (~55L) duplicated verbatim** `macbook:205-260` vs `ryzen:170-225` with a "keep identical" comment → shared `myModules.services.mullvad.fleetPolicy` preset. `refactor` ↓
- [ ] **Portmaster `forceSettings`** duplicated (`macbook:337-346` vs `ryzen:326-365`, rationale only on ryzen) → hoist shared keys into `portmasterMullvadCompat`. `refactor` ↓
- [ ] **`ryzen:110` Looking-Glass split-brain:** HM installs the client but system `kvmfr.enable=false` → client can never attach. Drive HM off `osConfig…kvmfr.enable`. `simplify` ↓
- ✅ The big VFIO/VM blocks correctly source identity from the `site` registry — the band-aid-free model to extend everywhere.

---

## §3 — Dimension C · NIH & custom machinery

### C.1 Clean upstream/structural wins

- [ ] **`parts/_build/modules-hierarchy.nix` (56L) is NOW UPSTREAM** — flake-parts ships `inputs.flake-parts.flakeModules.modules` (same shape). Its own header says "delete when upstream adopts" — it has. Replace with `imports = [ inputs.flake-parts.flakeModules.modules ]`; 75 call-sites stay byte-identical. `replace` · ⊟
- [ ] **Relocate `home/lib/` → top-level `lib/`** — the 6 helpers are imported cross-tree by `parts/_build/lib.nix:19-26` to populate flake-wide `flake.lib`; the `home/` location lies about ownership and forces placement-hook exemptions (`check-placement.nix:49`, `git-hooks.nix:364`). Move all 6 together, delete exemptions. `relocate` ↓
- ✅ **All 6 lib helpers validated as justified dedup** (mergeSettings named-args prevents silent arg-order clobber; mkSettingsOption 31×; mkSimplePackage 86×; cap/themeCtx/withStdenvCC) — keep. Trim `themeCtx.when` (only 5/32 users, aliases `lib.optionalAttrs hasTheme`). `simplify`

### C.2 The test harness is ORPHANED (biggest C finding)

- [ ] **CI never runs `nix flake check`** (`.github/workflows/check.yml` runs only host-eval + `nix build .#docs`). ~40 checks/VM tests protect _nothing automatically_ and silently rot. **Add a `flake-check` CI job.** `refactor` · risk low ↓ _(Dim D: tests that don't run are a fragile mechanism masking failure)_
- [ ] **Drop tautological eval-canaries** (`eval-nix-flakes`, `eval-hardware-networking`, `eval-users-zsh` restate typed defaults); **keep value-pinning ones** (`eval-portmaster-dns-interception`, `eval-mullvad-lockdown`, `eval-scx-scheduler`, `eval-boot-lanzaboote`). `simplify`/`keep`
- [ ] **Collapse redundant VM tests** — most `nixosTest`s boot QEMU just to confirm a unit reaches `active` (host eval + `mkIf` nearly proves this). Keep only runtime-behavior tests (impermanence bind-mount, pipewire socket) and the **gold `nrb` VM tests** (`tests/nrb.nix:158-240` — guard a real hang fix). `simplify`/`keep`
- [ ] **`nrb-activate-regex-test` tests a _copy_ of the regex** (`nrb.nix:135`) not `hardening.nix:46` — extract one shared constant or delete. `refactor` ↓
- [ ] **Extract one `assertEq` helper** to kill 789L of repeated FAIL-echo boilerplate. **Do NOT adopt namaka/nixt** (more machinery than it removes). `simplify` ↓

### C.3 Pre-commit friction (the things actually fighting you)

- [ ] **`nix-eval-check` runs 4 nix evals on nearly every commit** (`git-hooks.nix:58-107`) — dominant commit latency, pushes toward `--no-verify`. Move to pre-push, or scope to the changed host only. `simplify` · ↑→↓
- [ ] **`check-behind-remote` does a network `git fetch` at commit time** (`:436`) — belongs at pre-push. `relocate` · ↑→↓
- [ ] **`check-no-roadmap-in-docs`** guards a filename that has never existed → dead policing. `remove` · ⊟
- ✅ **`auto-format` hook** (fixes treefmt's "formatted-but-not-restaged" gap), **`check-secrets-leak`**, and the 4 custom checks (`check-placement`, `check-scrub-tokens`, `mkExhaustivenessCheck`) are **justified** — cheap, text-only, encode rules no upstream linter knows. Keep. _(Minor: `check-scrub-tokens` silently no-ops without `~/.ai-context/scrub-config.json` — emit a one-line "scrub disabled" notice.)_

### C.4 nrb & diagnostics → package properly

- [ ] **Package nrb/nrb-check/nrb-info as `writeShellApplication`** (shellcheck + `runtimeInputs`) instead of a 1309-line zsh heredoc — the repo already proves the pattern with `nrb-activate`. Collapse the 3× duplicated `/home/user` flake/site bootstrap. `refactor` · effort large ↓
- [ ] **`sysdiag-script.nix` (616L) → `writeShellApplication`** (currently `writeShellScriptBin`, no shellcheck, hybrid PATH). `refactor` ↓
- [ ] **`scripts/audit-probes.sh`** — re-implements `check-placement` via grep, A2 is a `return 0` no-op, frozen to a dead spec → dead policing. `remove` · ⊟
- [ ] **`scripts/test-shell-functions.sh`** — broken `grep -q | head` assertions, `local` at script scope, half is doc-string linting. `simplify` ↓
- ✅ `iodiag`, `b43-resume-verify`, `vfio-phase1-probe`, `warm-macbook-cache` — keep (well-scoped, host-pinned). `install-btrfs.sh` (521L) — acceptable bootstrap exception; long-term → disko.
- [ ] **`home/modules/default.nix`** may be **dead scaffolding** (no importer found) duplicating `home-modules.nix` discovery — verify, then remove. `remove` · risk med

### C.5 Importers

- [ ] **De-dup the two readDir importers** (`home-modules.nix:20-26` + `home/modules/default.nix:16-24` hand-roll identical discovery) into one shared helper. `simplify` ↓
- [ ] **Correct the import-tree comment** — it's _filterable_ (`.match`/`.filter`), not incompatible; the blanket "rejected" overstates it. (Adoption optional; the `/_` convention already matches import-tree's default, so a future migration is a drop-in.) `refactor` =

---

## §4 — Dimension D · Band-aid → root-cause

The pattern you named: a fragile **runtime** mechanism + a **fallback that masks failure**, instead of
declarative ground truth. Fix = one declarative source of truth.

### D.1 ★ The fleet-resolution decay (flagship — fix once, delete everywhere)

mDNS `.local` broke under the Mullvad tunnel (nss-mdns multicast follows the default route → escapes
the tunnel → rename loop `host→host-21`). **5 stacked workarounds** resulted:

| Site                                                   | Band-aid                                       |
| ------------------------------------------------------ | ---------------------------------------------- |
| `avahi.nix:54`                                         | `denyInterfaces = ["wg0-mullvad"]`             |
| `networking.nix:70-88`                                 | a whole `multicastDns` `no/resolve/yes` option |
| `macbook:168`                                          | `avahi.enable = false` (gave up)               |
| `remote-builder.nix:131-200`                           | `staticIp` → `/etc/hosts` fallback             |
| `nrb:190`, `deploy.sh:153`, `home/hosts/ryzen:505,511` | dead `.local` SSH fallbacks                    |

- [ ] **Root-cause fix:** make `site` + `secrets/host-identifiers.nix` the **single fleet registry** → feed `networking.hosts` + `programs.ssh.knownHosts` on every host. Resolution becomes build-time, deterministic, VPN-independent. Then **delete** every `.local` path above and retire avahi/the `multicastDns` option. `replace` · effort medium · risk med ↓⊟

### D.2 nrb kernel-safe-update is a runtime bisection over a declarable fact

- [ ] **`nrb-functions.nix:476-772` (~250L)** speculatively updates the lock, re-evals the kernel drvPath map, bisects per-input, and even **HTTP-HEADs substituters** (`_kern_is_cached`) to _discover at runtime_ which input moved the kernel — making `--update-no-kernel` **nondeterministic** (same bump is "safe" or not by cache warmth). The kernel is **one pinned input** (`nix-cachyos-kernel`). Replace with a static split: `nix flake update <all-except-kernel-set>`. `replace` · effort large ↓
- [ ] Drop the substituter cache-probe entirely (`:572-616`). `remove` ↓

### D.3 Smaller band-aids

- [ ] **`withStdenvCC.nix`** masks an upstream packaging defect (cachyos turbostat ships empty `nativeBuildInputs` under `strictDeps`) at the consumer (`turbostat.nix:28`). Keep the 1-user helper but **file the upstream fix** so it can be deleted. `keep`/track
- [ ] **`deploy.sh:153-193`** mDNS-resolve + manual-IP-prompt fallback → collapse to SSH-alias once D.1 lands. `replace` · ⊟
- [ ] **VM hook `_vfio_resolve_host_driver`** 4-tier runtime discovery (`vms.nix:174-207`, **duplicated** at `:442-475`) over a host-static fact → make `gpu.hostDriver` required, collapse tiers, de-dup into one `let`. `simplify` ↓
- [ ] **`vms.nix` 47× `2>/dev/null`** on sysfs/systemctl mutate paths mask partial-state failures → keep swallowing only on best-effort cleanup-trap paths; log+exit on load-bearing writes. `simplify` ↓

---

## §5 — Security & safety

✅ **Strong baseline:** key-only PQ-hybrid SSH (`ssh.nix` at/above CIS), sound agenix model (only
`secrets.nix` tracked, `.age` never committed, encrypted to host keys), lanzaboote Secure Boot on
ryzen with sbctl PKI persisted 0700, sandboxed Nix, and the `nrb-activate` sudo wrapper (validates
closure integrity — textbook mitigation, not a vuln).

- [ ] **★ `hardening.nix:1` advertises "AppArmor" — none is configured.** False assurance in a security module. Either implement `security.apparmor` or drop the claim. _(Note: Portmaster is a network filter, not syscall/FS confinement — "app isolation" is also overstated.)_ `simplify` · ↓
- [ ] **Add missing KSPP/CIS sysctls** as `mkDefault` in `hardening.nix`: `dmesg_restrict=1` (currently only set under corecycler), `kptr_restrict=2`, `perf_event_paranoid=2`, `kexec_load_disabled=1`, `unprivileged_userfaultfd=0`, `protected_{hardlinks,symlinks,fifos,regular}`, `suid_dumpable=0`, `default.rp_filter=1`. `enforce` =
- [ ] **systemd per-service confinement** for the 3 custom root units (`fwmark-preserve`, `mdns-no-wg0-mullvad`, github-token) — `NoNewPrivileges`, `ProtectSystem=strict`, scoped `CapabilityBoundingSet`. Validate with `systemd-analyze security`. `enforce` =
- [ ] **`nix.nix:84-90` github-token** written then chmod'd (brief world-readable window) → `(umask 077; …)` / `install -m600`; prefer a fine-grained PAT. `refactor` =
- [ ] **Reconcile `rp_filter` sysctl (=1) vs `firewall.checkReversePath`** — both control the same kernel behavior; pin `checkReversePath` explicitly (likely `loose` for Mullvad policy routing). `enforce` · risk med
- [ ] **`impermanence.nix:68` rollback** parses `btrfs subvolume list | cut -f9` — brittle, runs as root in initrd against `/`. Harden parsing + assert `@root-blank` exists before enabling. `refactor` · risk med (currently inert)
- [ ] **`wifi.age`** encrypted to one host, consumed by none → wire it or delete the unused blob + recipient. `simplify`
- ⓘ **Document, don't change:** Nix `trusted-users` includes primaryUser (= root-equivalent — the standard single-admin tradeoff); `split_lock_detect=off`/`nmi_watchdog=0` are deliberate gaming choices. State the trade-offs in comments given the "safety" framing.

---

## §6 — Standards conformance (validated — the good news)

✅ nixfmt/RFC-166 clean (0 diffs, 388 files) · ✅ no `with lib;`, no `mdDoc`, no unguarded config ·
✅ `mkIf`/`mkDefault`/`mkForce` discipline (every non-host `mkForce` has a `# Why:`) · ✅ namespace
100% self-consistent · ✅ option `description` coverage ~100% · ✅ 80 docstring-less home modules are
all `mkSimplePackage` wrappers (STYLE-exempt — do **not** backfill). Only note: `statix check` shows
53 "repeated keys" warnings on the _intentional_ dotted-path-per-line style — do **not** add a
`statix check` gate (would police an intentional style); one doc line at most.

---

## §7 — Proposed execution plan

Each phase gated by **`nix flake check` + `nrb --check` (all hosts) + `nrb --dry` per host**. Nothing
executes without your sign-off per item.

- **Phase 0 — Dead code & correctness (trivial, do first).** A.1 nrb regen block + `OPTIONS.md.tmp`; A.5 three comment bugs; C.3 `check-no-roadmap`; C.4 `audit-probes.sh`; §5 AppArmor claim; strip dead `.ai-context`/docs `.gitignore`+treefmt rules. _Pure deletions + comment fixes; near-zero risk._
- **Phase 1 — Docs consolidation (A).** Resolve A.3 (STYLE), remove pipeline (A.1), remove prose docs (A.2), write the lean README. _One reviewable diff._
- **Phase 2 — Comment standard (A.4).** Mechanical per-file pass using the block-level classification above; the 2 `enforce` items become assertions.
- **Phase 3 — Clean NIH wins (C).** `modules-hierarchy`→upstream; relocate `lib/`; hook friction → pre-push; **add `nix flake check` to CI**; trim test harness; de-dup importers; verify/remove `home/modules/default.nix`.
- **Phase 4 — Band-aid root-cause (D).** ★ Fleet registry → `networking.hosts`+`knownHosts`, then delete all mDNS/`.local`; nrb kernel-safe-update → static split; promote `_kernelPostPatch` (coordinate with your vfio-stealth repo); package nrb. _Largest, highest-payoff._
- **Phase 5 — Security hardening (§5).** KSPP sysctls; systemd confinement; github-token umask; rp_filter reconcile; impermanence rollback hardening (before any impermanence enable).

**Dependencies:** Phase 4's `.local` deletions depend on the fleet registry landing first. Phase 2's
comment work is independent. Phase 1's STYLE decision (A.3) blocks deleting `STYLE.md`.

---

## §8 — Open decisions for you

1. **STYLE.md (A.3):** keep it as the one permitted non-README doc the hooks cite, or inline rules into hook messages and delete it?
2. **nrb packaging (C.4):** large refactor — do it as part of Phase 4, or defer (it works today)?
3. **Phase order:** start at Phase 0 next session, or reorder?

---

---

# ADVERSARIAL REVIEW (2026-05-29, second pass)

> 18 agents: coverage sweep of everything the first audit never read + refutation of its claims
> (with `nix eval`/`nixfmt`/`statix` actually run) + best-of-breed technology scouting. This pass
> **corrects the audit above** — where §9 conflicts with §1–§8, §9 wins.

## §9 — Corrections to the original audit (claims it got WRONG)

- [ ] **C.4/C.5 WRONG — `home/modules/default.nix` is LIVE, not dead.** Imported by `home/home.nix:28` (`./modules`); it's the internal HM aggregator that feeds discovered modules into each user's eval. It is **not** redundant with `parts/_build/home-modules.nix` (that declares the `flake.modules.homeManager` _output_ — different consumer). **Delete nothing.** Only the _discovery predicate_ is duplicated verbatim → extract one helper, call from both.
- [ ] **B.1 WRONG — NOT "exactly one" dendritic violation; there are ≥4 cross-module writes:** (1) `kernel.nix:284`→`vfio._kernelPostPatch` (audited); (2) **`cpu-intel.nix:88` governor vs `tuning/performance.nix:79` governor** — both own CPU-freq policy; `cpuIntel.governor` is permanently inert (perf's `mkDefault` wins) → delete the cpu-intel governor option; (3) **`macbook/workspaces.nix:37`** writes `kwinrc."Windows".RollOverDesktops` into the group `plasma/kwin.nix` owns; (4) **`delta/default.nix:45`** writes `programs.git.settings.{merge,diff}` into git's namespace (`diff` set by both). Plus a gray intra-plasma `breezerc."Common"` double-writer (`plasma/default.nix:211` + `appearance.nix:73`). _(rusticlDrivers aggregation IS by-design — confirmed not a violation.)_
- [ ] **C.1 WRONG — `modules-hierarchy.nix` is NOT a byte-identical drop-in for `flake-parts.flakeModules.modules`** (proven by `nix eval` of both `apply`s). 4 divergences: upstream sets `_class="homeManager"` (local sets none), richer `_file` provenance, open `lazyAttrsOf` (supports `generic`/`darwin`) vs local closed submodule. **Revised rec:** the 144 `inputs.self.modules.nixos.*` consumers _do_ work unchanged, so — **keep local, fix the 2 cheap divergences now** (add `_class="homeManager"`, adopt upstream `_file` format); full upstream swap only when a `darwin`/`generic` host is actually planned.
- [ ] **Lib "keep all 6" → keep 4, drop 2:** `cap` → **replace with `lib.strings.toSentenceCase`** (exists in 2026 nixpkgs, identical on all 8 lowercase callsites) and delete; `themeCtx.when` → **replace with `lib.optionalAttrs hasTheme`** (verbatim alias, 11 sites) and delete the sub-helper. Keep `mergeSettings`, `mkSimplePackage`, `mkSettingsOption`, `themeCtx`-gatherer (all earn their keep). `withStdenvCC` = 1 real user — keep on documentation grounds, inline if no 2nd materializes.
- [ ] **D.1 fleet-registry — the fix is more nuanced AND carries a regression risk:** `site` is **already a real typed inventory** (`repos/site/network.nix` + `hosts/*.nix`, live via `specialArgs.site`), not a 445-byte stub — the 445 bytes is just the index. `secrets/host-identifiers.nix` = **dead governance** (never existed; `site` serves the role) → strip from `.gitignore`. BUT: `site.network.hosts.{ryzen,fcse01}.ip` exist yet are **dead (zero consumers)**, macbook/pixel have **no IP**, and there are **no general SSH host keys** (only builder pubkeys) → the `knownHosts` arm needs a new `hostPublicKey` field per host. ⚠ **Critical:** `macbook:127-131` set `staticIp=null` _deliberately_ because a pinned IP went stale when ryzen's DHCP lease drifted, breaking ssh+builds — so **D.1's `networking.hosts` from registry IPs REGRESSES a known-fixed bug unless paired with DHCP reservations at the router.** The live precedent to generalize is `site.network.builders.aux` → both `nix.buildMachines` _and_ `programs.ssh.knownHosts` (`macbook:842-873`).
- [ ] **Count/scope corrections:** 296 tracked `.nix` (not 388); 421 `mkOption` + 167 `mkEnableOption`, 0 missing description (not "422"); **82** `mkSimplePackage` wrappers (not 80/86); the 115-line opt-out list is on **pixel** specifically (ryzen 11, macbook 47); the remote-builder is **NOT** replaceable by a cache (a cache serves built paths, can't build a miss).
- [ ] **Docs pipeline — CONFIRMED + WORSE:** `nix build .#docs` never invokes the generator (confirmed); the Options/Module reference pages are **fictional placeholders** that cite a generator never run; `nixosOptionsDoc` appears nowhere; `treefmt` excludes generated files that don't exist. Stronger case for §A.1 removal.
- ✅ **Verified-true claims (ran the tools):** `nixfmt --check` 0 diffs; `statix check` exactly 53 `repeated_keys` (style, not bugs); description coverage 0 missing; CI never runs `nix flake check`. **Tooling note:** `nixfmt`/`treefmt`/`statix`/`deadnix` aren't on PATH and **no `deadnix` runs anywhere** — dead args (below) go uncaught.

## §10 — Coverage findings (the broken twigs the audit never read)

**RISK (robustness / data / determinism) — triage first:**

- [ ] **★ `cryptswap` defined THREE contradictory ways on macbook** — `hibernate.nix:71-87` initrd-unlocks LUKS `cryptswap` + `swapDevices`, `kingston.nix:37-49` _also_ unlocks the **same UUID** via crypttab + adds a **second** `swapDevices` entry, `disko.nix:149` sets `resumeDevice=false`. Result: **won't deterministically hibernate or activate swap.** Pick one owner. `RISK·high`
- [ ] **★ 2nd dangling script: `scripts/repurpose-kingston.sh`** — cited at `macbook:88,155` + `scripts/README.md:19` as the swap/btrbk provisioner; **doesn't exist.** The mbp `btrbk.enable=false "until script runs"` can never flip. `GAP·med`
- [ ] **★ `fcse01` is a registered fleet host with NO in-tree config** — referenced via `site.hosts.fcse01` (syncthing/builder) but no `parts/hosts/fcse01/`, never eval'd. For "many hosts in-tree," it's half-wired — bring in-tree or document as external peer. `GAP·med`
- [ ] **Impermanence is dead weight** — `enable=false` on every host, yet imported + 30-line persist list + a hand-rolled, **never-booted** initrd `btrfs` rollback (parser `cut -d' ' -f9` is fragile; `@root-blank` snapshot **nothing creates declaratively**). Either commit (disko `postCreateHook` creates `@root-blank`) or remove the import until a host needs it. `RISK·high`
- [ ] **disko layout duplicated vs `hardware-configuration.nix` and ALREADY divergent** — both declare the 8-subvol btrfs tree; `@tmp`→`/var/tmp` (disko) vs `/tmp` (hw-config) on mbp; `@persist` missing from hw-config. → adopt `disko.nixosModules.disko` as the single fs source. `RISK·high` _(see §11 install/boot)_
- [ ] **avahi vs networking: two unsynchronized mDNS-leak solutions, no assertion** — the "disable avahi if `multicastDns≠no`" invariant is enforced only by hand. Add `assertion = !(avahi.enable && multicastDns != "no")`. `RISK·high`
- [ ] **`nixos-avf` tracks `trunk` (moving branch)** (`flake.nix:230`) — pixel's entire hardware layer rolls forward silently on every update. Pin a tag or vendor-review bumps. `RISK·med`
- [ ] `bluetooth.nix:55` depends on a `bluetooth` group only `users.nix` creates → move `users.groups.bluetooth={}` into the module. `sunshine.nix:112` `virtual_sink` mkMerge key-collision footgun. `goxlr`/`streamcontroller` `lib.optionalAttrs (options?…)` silent-no-op when the upstream HM module isn't loaded → assert instead. `pipewire.nix:72` `LD_PRELOAD` pinned to PipeWire 1.6.3 but nixpkgs ships 1.6.5 (re-verify/remove). `goxlr.nix:45` `replaceDependencies` rebuilds the world (scope via `ALSA_CONFIG_UCM2`). `rocksmith` overrides `steam.package` (fragile; invert to contribution). `corecycler` needs `ryzen-smu` side-effects with no assertion. `zsh` `gc`/`lc`/`devshells` are multi-phase sudo scripts smuggled as `shellAliases`; `makeZshenvMutable` is an unconditional Claude-Code/bwrap band-aid; flake path hardcoded despite `cfg.flakeDir`.

**GAP / CORRECTION (cleanup, low risk):**

- [ ] `cpu-amd.nix:1` header lie ("performance governor" — sets none); `core.nix:30` false k10temp comment; firmware enabled in 4 places (3 redundant); `filesystems.nix` `enableAll` is a dead OR-gate (6 options → 1 bool); `syncthing.nix:13` `primaryUser or "user"` dead fallback; `theme` 4 dead `-rgb` keys; `hibernate` assertion is a no-op; `loader.timeout` couples to `refind.timeout` unconditionally; `gamemode` 10 options/1 consumer; `steam` `or false` double-guard; `geoclue` `enableWifi` hardcoded (MLS dead since 2024); `earlyoom` notifications ungated; 80-line commented-out goxlr `lighting` block; dead binary asset `streamcontroller/assets/1854458-620033676.jpg`; pixel x86 TCG binfmt near-useless.
- [ ] **`kernelUsesLLVM` block triplicated verbatim** across `sensors/drivers/{it87,ryzen-smu,zenpower}.nix:14-29` → one `mkKernelModule` helper. `TECH·high`
- [ ] **Unused `inputs`/`pkgs` args in ~18 modules** (only `yeetmouse`/`streamcontroller` use `inputs`) → `_:`; **add `deadnix` to the flake check** so this is caught structurally, not by review.
- [ ] `kate` hardcodes 6 LSP servers duplicating `neovim/lsp.nix` (no gating) → shared `langServers` set. `displays` declares HM-only fields in the NixOS schema (hidden contract). `durdraw` `rgbTo256` hides real color-science behind a "simple" facade. `primaryUser` re-hardcoded as literals fleet-wide (pixel `/home/droid`, ryzen `/home/user`) → derive from `config.myModules.primaryUser`.
- [ ] **3 hand-rolled `home.packages=[pkg]` that should be `mkSimplePackage`** (`iotop`, `sysstat`, `eden`) — makes the wrapper/config partition exact. **4 hardware passthroughs** (`acpid`/`upower`/`coolercontrol`/`usbmuxd`) are 1-line `enable→service.enable` — fold into one `hardware/services.nix` attrset _if_ the exhaustiveness hook isn't the justification.

## §11 — Best-of-breed technology roadmap (what to adopt, scored vs your philosophy)

> Lens applied to each: minimize-abstraction · maintainable/compounding · many-hosts · safety/robustness ·
> willing to take hard debt for real improvement. "Defer/reject" items state the trigger condition.

- [ ] **★ Roles/profiles — the highest-payoff structural change.** Your per-tool _module_ pattern is fine (mainstream dendritic — `Bad3r/nixos` lands on the identical design). The **over-abstraction is the exhaustiveness hook + the 82 pure wrappers + 26 thin passthroughs**, which scale **O(hosts×modules)** — they compound _against_ you as hosts grow. Replace with: opt-in **role profiles** (`roles/{workstation,gaming,headless}.nix` that flip bundles on) + per-host short divergence; delete the exhaustiveness hook and the `enable=false` enumeration. Module defaults stay `false`; the "on" polarity lives in roles (a global default-on flip would be a _worse_ explosion). Phased: ① delete hook → one baseline profile; ② fold 82 wrappers into package-set profiles (delete `mkSimplePackage` + 82 dirs); ③ fold 26 thin passthroughs. Target ~226 modules → ~40 + ~6 profiles; host files 180–548 lines → ~50. **This is the "hard debt that improves everything."** `effort·large · payoff·high`
- [ ] **Deploy: `deploy-rs`** — replaces the 230-line `nrb --deploy` (the most fragile artifact) with a declarative node set that consumes `nixosConfigurations` directly **and adds magic-rollback** (auto-revert on failed activation — a real safety win the script lacks). _Not_ colmena (parallel eval path, no payoff at 3–6 hosts), _not_ vanilla `--target-host` (nixos-rebuild-ng regressed cross-arch in 25.11). `effort·medium · payoff·high`
- [ ] **CI + cache: `garnix` now.** One move fixes all three CI gaps: runs the orphaned `nix flake check`, evals the ryzen _toplevel_ through IFD (no public-cache problem), and gives a private binary cache the fleet substitutes from — ~10 lines, replaces the `check.yml` eval kludge. Self-hosted **buildbot-nix + harmonia on ryzen** later if the trust boundary bites (harmonia, **not** the stalled attic; **not** hydra). The one real decision: garnix stores build outputs of your 21 private forks on their infra — acceptable for a single owner, or go self-hosted. `effort·small→large · payoff·high`
- [ ] **Install/boot: finish the disko migration.** disko is half-adopted (layout files exist but aren't the live `fileSystems`). Import `disko.nixosModules.disko`, strip `fileSystems`/`luks` from `hardware-configuration.nix`, delete the 521-line `install-btrfs.sh` (use `disko-install`/`nixos-anywhere`), and create `@root-blank` via `postCreateHook` so impermanence is safe to enable. Add **`srvos.nixosModules.common`** (hardened SSH/nix/sysctl defaults — replaces ad-hoc hardening). **Keep NixVirt** (microvm.nix can't do GPU VFIO). `effort·medium · payoff·high`
- [ ] **Secrets/identity: KEEP agenix + formalize `site`.** agenix is right at N=1 secret; sops-nix/clan would _add_ abstraction for a problem you don't have (reject; triggers documented). Make `site` the canonical typed inventory (it already is), **derive agenix recipients from `site`** (one root for host keys), add `agenix-rekey` only past ~5–10 secrets. ⚠ `site` is an absolute `git+file:///home/user/...` path in `flake.nix` — a per-host coupling that fights many-hosts; relativize/override + preflight-assert. `effort·small · payoff·high`
- [ ] **Testing: wire `nix flake check` to CI (via garnix)** — the 34-check harness runs on zero events. Migrate the ~12 pure-lib `eval-mylib-*` `runCommand`s to **`nix-unit`** (sub-second, no VM); keep `testers.nixosTest` for VM checks. `effort·small · payoff·med`
- [ ] **Forks: already mostly solved — don't add nvfetcher.** `repos/nix-packaging-standard/` already does daily upstream-detection + drift-check across the forks. Real surface ≈ **10–12**, not 21 (`ripgrep-nix`/`durdraw-nix` are deliberate exemplars/upstreamable). Triage: **upstream the 2–3 vanilla packages to nixpkgs**; keep patched/git/unfree as forks. Add a consuming-side `flake check` that _builds_ each fork's package from the locked rev so breakage is caught at the monorepo, not at `nrb` time. `effort·medium · payoff·med`

## §12 — Revised execution plan (supersedes §7)

- **Phase 0 — Safety + dead-code (urgent/trivial).** ★ Resolve the macbook `cryptswap` triple-definition (data/hibernate risk); the `repurpose-kingston.sh` + `generate-docs.nix` dead refs; the AppArmor false claim; the avahi/mDNS assertion; comment bugs; strip dead `.ai-context`/`host-identifiers.nix`/docs gitignore+treefmt rules; add `deadnix` to the check. Decide fcse01 (in-tree or documented-external).
- **Phase 1 — Docs (A).** As §7, with the §9 STYLE decision.
- **Phase 2 — Comments (A.4).** As §7, plus the §10 header lies (cpu-amd, core.nix k10temp).
- **Phase 3 — Cheap correctness wins.** The ≥4 dendritic-write fixes (§9); drop `cap`/`themeCtx.when`; fix the 2 `modules-hierarchy` divergences; the §10 GAP/CORRECTION cleanup; the `mkKernelModule` helper; unused-arg sweep.
- **Phase 4 — CI/cache (garnix) + finish disko + deploy-rs.** The best-of-breed adoptions; each gated by the now-real `nix flake check`.
- **Phase 5 — ★ Roles/profiles refactor (the big one).** Phased per §11; the structural change that makes every future host cheap.
- **Phase 6 — Band-aid root-causes (D) + security (§5).** Fleet registry **with DHCP reservations** (else it regresses the IP-drift bug); kernel-safe-update; `_kernelPostPatch`→public; KSPP sysctls; systemd confinement; impermanence rollback hardening (before enabling).

## §13 — Revised open decisions

1. **Roles refactor (§11/Phase 5):** commit to the role/profile migration (deletes the exhaustiveness hook + ~180 wrapper/toggle lines, the biggest compounding win) — or keep per-tool toggles?
2. **CI trust boundary:** garnix (fast, ~10 lines, but your 21 private forks' build outputs live on their infra) vs self-hosted buildbot-nix+harmonia on ryzen (sovereign, large)?
3. **disko go/no-go:** finish the migration (single fs source, delete 521-line script) now, accepting the host-config refactor — or defer?
4. **fcse01:** bring in-tree as a real host, or document as externally-managed?

---

---

# CONVERGENCE PASS (2026-05-29, third pass)

> Audited `repos/site` (newly in scope), re-verified pass-2's own claims (with `nix eval`), final
> whole-tree band-aid sweep, `flake.lock` health, and a deep Portmaster/Mullvad investigation.
> **Signature of convergence:** mostly CONFIRM + two CORRECTIONS to pass-2 + a small low-severity tail.

## §14 — Convergence: corrections, new findings, definitive band-aid list

**Corrections to pass-2 (the adversarial pass over-counted):**

- [ ] **`cryptswap` is a real bug but a DOUBLE, not a triple** — `nix eval` proof: initrd unlock (`hibernate.nix:71`) **and** crypttab unlock of the same UUID (`kingston.nix:38`) are both live → two `swapDevices` entries on one backing store → second `swapon` hits "Device or resource busy". `disko.nix:149 resumeDevice=false` is **inert** (disko module imported for CLI only, not applied to runtime). Still **macbook-only, silent runtime failure, high-payoff fix.** Pick one unlock owner. `RISK·high`
- [ ] **Dendritic violations: real count is 2, not "≥4".** **REFUTED:** `kernel→vfio._kernelPostPatch` is a _read_ of a `readOnly/internal` exported API where the kernel module (owner of `boot.kernelPackages`) does the write — the dendritic-_correct_ inverted dependency (promoting it to a non-`_` public option is cleanliness, not a bug-fix); `macbook/workspaces→kwin` is an additive merge of _different_ keys (standard HM behavior). **CONFIRMED real:** `delta/default.nix:45`→`programs.git.settings` (genuine cross-module write); `cpu-intel.nix:88` vs `performance.nix:79` both write `powerManagement.cpuFreqGovernor` (split ownership; cpu-intel's `mkOptionDefault` is inert — harmless today, footgun). `effort·low`
- ✅ **Re-confirmed (held up under re-verification):** docs pipeline orphaned + Options page fictional; `home/modules/default.nix` LIVE + non-redundant; `modules-hierarchy.nix` not an upstream drop-in; `site` real; `host-identifiers.nix` never existed; D.1 IP-pinning regression real.

**`repos/site` audit (newly in scope):**

- ✅ **Leak risk LOW — no secrets in the registry.** Every `ssh-ed25519` is a _public_ key; the private builder key lives at `/root/.ssh/remotebuild`, never in `site`. `repos/site` has no git remote and is gitignored. Syncthing IDs / SMBIOS serials / MACs / IPs = topology, fine in plaintext.
- [ ] **Dead registry fields:** `network.{gateway,dns,domain}` and every `network.hosts.<h>.ip` have **zero consumers** (only `subnet` + `builders.aux` are live); `hardware.goxlrSerial`, `fcse01.macAddress` unconsumed. Wire or prune. `GAP·med`
- [ ] **Fleet-`knownHosts` needs a field that doesn't exist:** there are _no per-host SSH host keys_ (only builder pubkeys). Add `hosts.<h>.ssh.hostPublicKey` per host; derive **both** `knownHosts` _and_ agenix recipients from it (one identity root). `NEW·high`
- [ ] **Relativize the input:** `site` now lives under the tree (`repos/site`) but is referenced as absolute `git+file:///home/user/...`. Since it's `flake=false`, switch to `path:./repos/site` — drops the `/home/user` hardcode and most of the `--override-input` dance in `nrb`/CI. `small·high`
- [ ] **CI-stub drift:** `ci/site-stub` is shallower than real `site` (missing `vfio.smbios/edid/acpiOem`); because those are gated inside specialisations, `nix flake check` may not force them → a typo in a real-only field path passes CI. Make the stub a schema-complete mirror. `RISK·med`

**New findings (pass-3, lower severity):**

- [ ] `flake.lock`: **impermanence is the only input NOT following root nixpkgs** → pulls a **second, 4-month-divergent nixpkgs closure** evaluated on every host. Add `impermanence.inputs.nixpkgs.follows = "nixpkgs"`. `RISK·high · effort·trivial`
- [ ] `flake.lock`: **two moving refs** — `nixos-avf ref=trunk` (a `nixos-26.05` tag now exists; 4mo stale) and `nix-flatpak ref=latest` (auto-advancing branch) → pin both to tags so `nix flake update` produces reviewable diffs, not silent jumps. `RISK·med`. Stale long-tail: `tidalcycles` (19mo), `agenix` drags a `nix-darwin@master` + HM node (dead weight on x86_64-linux). _(Correctly pinned: `nix-cachyos-kernel`/`lmstudio` own-nixpkgs — do not "fix".)_
- [ ] **NEW band-aid: `displays/default.nix:206-219`** runs an activation-time `sed` on `kwinrc` every HM switch to undo a plasma-manager Tiling-escaping bug + GC `phantomUuids` — runtime text-surgery on generated config. Upstream-fix or model monitors by stable UUID. `RISK·med`
- [ ] `plasma/input.nix` is the **only** plasma submodule with **no `enable` gate** (writes unconditionally when imported) + unused `pkgs`. `hibernate.nix` emits a **duplicate `resume=`** (both `resumeDevice` and explicit `kernelParams`). `disko` swap has **no `label`** but kingston registers by-label. macbook `efiInstallAsRemovable` set **twice** (module option + raw). `lsp.nix` dotnet doc says "roslyn-ls" but ships **OmniSharp**. `eza` declares unused `pkgs`. All `effort·trivial`.

**Definitive band-aid inventory (loop-until-dry — this is the complete list):**

1. ★ macbook `cryptswap` double-unlock (§14) · 2. ★ Portmaster/Mullvad fwmark 1s-poll watcher (§15) · 3. `displays` kwinrc `sed`-surgery (NEW) · 4. `optionalAttrs (options.programs ? x)` silent-no-op (goxlr/coolercontrol/streamcontroller) · 5. docs pipeline (orphaned generator + fictional page + `|| echo "Page not found"` swallow) · 6. mDNS/`.local` fleet resolution (D.1) · 7. nrb `kernel-safe-update` runtime bisection · 8. dead script refs (`repurpose-kingston.sh`, `generate-docs.nix`) · 9. `deploy.sh` Portmaster stop/start (same fwmark root cause) · 10. impermanence untested initrd shell + missing `@root-blank` · 11. cpu-intel/performance governor split-ownership · 12. `_kernelPostPatch` pseudo-private channel (borderline).
   - ✅ **Confirmed NOT band-aids** (legitimate): the ~30 `2>/dev/null || true` + `sleep N` in `vms.nix`/`install-btrfs.sh` (genuine async PCI-rebind/hardware sequencing); `withStdenvCC` (documented, tested); nrb spinner/adb device-wait sleeps; `syncthing primaryUser or "user"` (cosmetic).

## §15 — Mullvad + Portmaster: can the band-aid go away? (deep, sourced)

**Short answer: no _upstream/config_ fix exists in 2026 — but yes, the fragile part can become robust & declarative, and there's a long-shot true-elimination path worth a 5-minute test.**

- **No shim-free upstream path today (CONFIRMED, sourced).** Portmaster's PR #1993 / v2.0.25 "respect original packet marks" is **connmark-gated** (RETURNs only for its own AcceptAlways=1710 / AcceptFinal=1709), so a _fresh_ Mullvad packet still gets its `0x6d6f6c65` ("mole") mark zeroed by `CONNMARK --restore-mark` before any AcceptAlways exists — Safing states it's "only a compatibility improvement for **pure WireGuard**," not Mullvad. Maintainer on **issue #2097**: the real cause is Mullvad=nftables vs Portmaster=iptables hook priority — "on our roadmap, not straightforward." There is **no Portmaster interface/mark/process exclusion** setting (searched source). The old official workaround was "use OpenVPN" — **Mullvad removed OpenVPN 2026-01-15.** So a local compat layer is genuinely required.
- **Kernel-WG is NOT a reliable escape (lean: won't help).** The rigorous mechanism analysis: Mullvad's daemon sets `fwmark=0x6d6f6c65` for **every** backend (kernel `wgctrl`, `wireguard-go`, the new `gotatun`); the encapsulated UDP is locally generated and transits `mangle OUTPUT` regardless of transport. A second agent speculates kernel-WG _might_ route differently per-packet — so it's a **cheap live test** (force kmod, check whether `CONNMARK --restore-mark` still sees the encapsulated packets) but **don't count on it**.
- **The DNS side (`forceSettings dnsQueryInterception=false`) is a SEPARATE, correct, declarative mitigation — keep verbatim.** It breaks Portmaster's resolver hijack of Mullvad's pre-tunnel `api.mullvad.net` bootstrap; it matches official guidance and is _the model_ the fwmark fix should imitate (declarative, in-tree, no poller). Not part of the fragile shim.
- [ ] **★ Recommended end-state — de-band-aid, don't delete.** Keep the RETURN-on-mole-mark _rule_ (it's strictly more correct than upstream), but **replace the 1s-poll systemd watcher with a static `networking.nftables` table**: its own chain at a `mangle` hook priority numerically _ahead_ of Portmaster (~`-160`), RETURNing `fwmark 0x6d6f6c65`. An independent nft table is an object Portmaster (iptables-nft) **cannot flush** → it survives pause/resume _by construction_, with **no poll, no 1s race, and no hardcoded `PORTMASTER-INGEST-OUTPUT` chain-name coupling** (that chain name already changed once upstream — `C170/C171`→`PORTMASTER-INGEST-*` — so the current match is version-fragile). This converts a racy runtime-guessing poller into declarative ground-truth. `effort·medium · payoff·high`
  - **Honest debt:** still a _local workaround for an upstream gap_ — it hardcodes Mullvad's "mole" constant (stable, guarded by the `mark` option) and depends on Portmaster's hook priority; both are version-coupled → add a `tests.nix` assertion / boot check that the `ip rule fwmark 0x6d6f6c65` exists and Portmaster's priority is unchanged. **Verify on the live host** that an independent nft table at higher priority actually precedes Portmaster's restore-mark before committing; fallback is an `nft monitor`/netlink **event-trigger** (re-insert on chain-creation event) — still strictly better than a clock loop.
  - **Track upstream #2097** as the deletion trigger (if Safing moves Mullvad handling to nftables with explicit priority, the table becomes removable).

## §16 — Convergence verdict

**We are converged enough to stop reviewing and start executing.** Three passes: pass-1 found the obvious (and erred), pass-2 swept the leaves (+25 findings, caught pass-1's errors), pass-3 mostly _confirmed_ pass-2, _corrected two over-counts_, and added a short low-severity tail (one trivial-but-high-value: the impermanence second-nixpkgs). The novelty/severity curve is flattening — a pass-4 would surface trivia, and the remaining unknowns are **runtime-only** (things only an actual `nixos-rebuild` + boot would reveal, not static review). **Recommendation: begin Phase 0** (the `cryptswap` data-risk + the trivial-high-value `flake.lock` follows-fix first), and treat further discovery as part of _execution_ (each change gated by the now-real `nix flake check` + a per-host build/boot).

---

---

# §17 — Phase 4/5 DESIGN DRAFTS (read-only design output; apply + runtime-test)

> Produced by a design workflow (no tree edits). These are **reviewed drafts to apply + test**, not
> applied changes. The Portmaster one in particular **needs a live VPN test** — do not trust it blind.

## §17.1 — Portmaster + Mullvad: kill the 1s-poll band-aid (NEEDS RUNTIME TEST)

**Honest verdict: the obvious fix DOES NOT WORK; a non-obvious one PROBABLY does but must be proven live.**

- The current shim (`portmaster-mullvad-compat.nix`) is a root systemd watcher polling every 1 s to insert an `iptables RETURN` _inside_ Portmaster's `PORTMASTER-INGEST-OUTPUT` chain, before its `CONNMARK --restore-mark` zeroes Mullvad's `0x6d6f6c65` ("mole") mark. Fragile: races Portmaster's pause/resume chain churn; hardcodes the chain name.
- **❌ The intuitive replacement (a standalone nft table at priority `mangle - 5` that `accept`s the mole-marked packet "ahead of" Portmaster) WON'T WORK.** `accept` is _non-terminal across base chains at the same hook_ — the packet still traverses Portmaster's `-150` chain afterward and `restore-mark` still zeroes the mark. Running earlier is the wrong half of the timeline. (Also: kernel-WG vs userspace-WG changes nothing — the fwmark is WireGuard protocol-spec behavior in both.)
- **✅ Candidate that should work (v2 — co-opt Portmaster's own mechanism):** seed the _conntrack_ mark with the mole-mark _before_ Portmaster (priority `mangle - 10` = −160), using WireGuard's still-intact `SO_MARK` as the clean discriminator. Then Portmaster's _own_ `CONNMARK --restore-mark` reinstates `0x6d6f6c65` from connmark for free. No poll, no chain-name coupling, survives pause/resume by **table-ownership** (Portmaster can't flush a table it doesn't own).

```nix
# v2 replacement for portmaster-mullvad-compat.nix config block (NEEDS RUNTIME TEST):
networking.nftables.enable = true;            # ⚠ flips firewall to nft backend + blacklists ip_tables
networking.nftables.tables.mullvad-portmaster-repair = {
  family = "inet";
  content = ''
    chain save-mole-connmark {
      type filter hook output priority mangle - 10; policy accept;   # before Portmaster's -150
      # SO_MARK still intact here → write it to connmark; Portmaster's
      # restore-mark then reinstates it on every later packet of the conn.
      meta mark 0x6d6f6c65 ct mark set 0x6d6f6c65
    }
  '';
};
```

- **⚠ The #1 thing to prove live:** Portmaster's `restore-mark` must restore the _full_ mask (not an `--nfmask`/`--ctmask`-restricted subset) or the mole bits won't round-trip. **Runtime checklist:**
  1. `sudo iptables -t mangle -S PORTMASTER-INGEST-OUTPUT` — inspect the exact restore-mark + mask.
  2. `sudo nft list table inet mullvad-portmaster-repair` — chain present at `mangle - 10`; pause Portmaster in UI, re-check (must survive).
  3. `sudo conntrack -L -o extended | grep 'mark=1836018789'` (= 0x6d6f6c65) — WG-relay conns show the seeded mark; empty ⇒ seed not firing.
  4. `mullvad reconnect && sleep 5 && curl -s https://am.i.mullvad.net/connected` — **fresh** connection survives with Portmaster _running_ (the bug's trigger).
  5. Pause→Resume Portmaster, repeat #4 — tunnel recovers with no intervention.
  6. `curl -s https://am.i.mullvad.net/json | grep mullvad_exit_ip` — no clearnet leak.
- **Fallbacks if v2 fails the live test:** (a) keep the poller but make re-insertion **event-driven** (`nft monitor`/netlink on Portmaster chain-creation) instead of 1 Hz; (b) keep the poller as-is. Either way, **add a loud watchdog** — v2 trades the poller's loud name-fragility for _silent_ mask/ordering fragility. Keep `forceSettings.dnsQueryInterception=false` untouched (orthogonal, load-bearing).

## §17.2 — Roles/profiles refactor (Phase 5 — big migration, design ready)

**Key fact that de-risks it:** the `hm-exhaustiveness` hook is **lint-only** — options are auto-imported and default `false`, so _absence already means off_. Deleting the hook changes **nothing functionally**; it only removes the 115-line `enable=false` ballast (pixel) and the "you forgot a module" reminder.

- **Mechanism (recommended Option A):** add `home/roles/*.nix` — plain HM config modules that flip `myModules.home.*.enable = true` for a coherent bundle (polarity lives in roles; module defaults stay `false`). A new exporter `parts/_build/home-roles.nix` (mirrors `home-modules.nix`) registers each as `flake.modules.homeManager.role-<name>`. Hosts import them via `home-manager.sharedModules` (next to the existing `goxlr-hm-nix` etc.) or the host HM file's `imports`.
- **Roles to carve:** `role-cli` (baseline shell + coreutils + editors/git + net), `role-nix-dev`, `role-desktop-plasma`, `role-gaming`, `role-audio-stream`, `role-vfio-desktop`, `role-emu`, `role-hw-diag`, `role-ai-cli`, `role-embedded-dev`.
- **Payoff:** `home/hosts/pixel-9-pro/default.nix` goes from **181 lines → ~20** (`imports = [ role-cli role-nix-dev ]` + a short host-unique tail). O(hosts×modules) → O(hosts×roles).
- **Phased migration (each eval-gated):** **P1** add the `home-roles.nix` exporter + a baseline `role-cli`, delete `hm-exhaustiveness` (lint-only, safe); **P2** carve the remaining roles, convert hosts to `imports = [roles…] + tail`; **P3** optionally fold the ~82 pure `mkSimplePackage` wrappers into role package-sets. **Risk:** `mkDefault` discipline where `programs.X.enable` could be set in both a module and a role — gate each phase behind a host `nix eval`.
- (Full design incl. example role modules + the exporter is in the workflow task output `wlgwjg6q5.output`.)

---

---

# §18 — EXECUTION RECONCILIATION (final state — supersedes earlier roadmap where they conflict)

Records what was actually executed + the decisions overriding earlier recommendations. Where this conflicts with §11/§17, **this section wins.**

## Done + eval-verified (one uncommitted branch)

- **Phase 0** — cryptswap data-risk (hibernate.nix sole owner; kingston drops it); impermanence 2nd-nixpkgs dedup (`follows`); dead-code/comment fixes; `.gitignore` cleanup.
- **Phase 1** — docs pipeline + 8 `docs/*.md` + archive + 2 module READMEs + CONTRIBUTING + scripts/README **deleted**; **STYLE.md eliminated** (rules folded into self-contained hook error messages); lean README.
- **Phase 3** — `cap` → `lib.strings.toSentenceCase`; dead `themeCtx.when` removed; `modules-hierarchy` `_class=homeManager`; `nix-eval-check` + `check-behind-remote` → **pre-push**; **`home/lib` → top-level `lib/`** relocate.
- **Gap fixes** — `check-scrub-tokens` DOC_CONTEXTS; `test-shell-functions` doc-checks removed; `ci/site-stub` schema-complete + **`eval-site-stub-parity`** check (root-cause for stub drift).

## REJECTED — roles/profiles refactor (was §11 "biggest win" + §17.2)

Built out (pixel + 8 role files + mac/ryzen start), then **reverted on user direction**. The explicit per-host enable lists are a deliberate **granular-control + visible-manifest** choice, not ballast; roles trade that away (disable-one ⇒ `mkForce` override) and `role-workstation` was an incoherent 70-module set-bucket. For 4 _diverse_ hosts the role layer doesn't earn its keep. **Adopted instead:** explicit per-host enables minus the _real_ ballast — the `enable = false` lines + the `hm-exhaustiveness` hook (forced exhaustiveness). Result: pixel 181→66, mac 409→370, ryzen 548→542; all behavior-preserving (bool-leaves identical). `hm-exhaustiveness` removed; `nixos-exhaustiveness` kept. **§17.2 is void.** See memory `granular-over-abstraction`.

## PENDING — decision-gated (NOT executed)

- **§17.1 Portmaster→Mullvad v2** (nft connmark-seed) — needs the live VPN runtime checklist; fallback = keep poller. Not applied.
- **mDNS/.local fleet band-aid** (§D) — declarative `site` → `networking.hosts` + knownHosts; ⚠ IP-pinning regresses DHCP drift unless paired with router DHCP reservations — needs your network reality.
- **CI `nix flake check`** — garnix (or self-hosted) decision; GHA can't run the VM tests / ryzen IFD.
- **deploy-rs / disko / srvos** — best-of-breed adoptions, each a go/no-go.
- **`.ai-context` stale governance** — git-hooks block-rule, `check-scrub-tokens` depends on a now-absent `~/.ai-context/scripts/scrub-config.json` (→ effective no-op), treefmt/nrb excludes, + syncthing folder paths in host configs. Per memory `ai-context-deleted` this is stale debris; left in place (defensive + partly your WIP host config) pending your call.

## Gap-check (this pass)

67 files changed (+660 / −5316). Orphan sweep clean (no dangling docs/STYLE/cap/home-lib/roles refs after fixing 2 stale `hm-exhaustiveness` comments). flake.lib = 5, homeManager modules = 152, `role-*` = ∅, pixel + mac toplevels + devShell eval, ryzen HM = 142 enabled.

# DANGLING-REFERENCE AUDIT (2026-06-02, workflow + deterministic verify)

## §19 — Unguarded cross-module ("dangling") references

**Pattern.** A module's config names a _runtime resource_ (binary, `.desktop` id, path) owned by a different, separately enable-gated module, with no guard tying it to that provider. If the provider is disabled the reference dangles → silent runtime breakage (command-not-found / dead launcher). It is an **implicit, unenforced cross-module dependency** = a self-containment break in the _consuming_ module; fails silent, not fast. **Distinct from inert cross-refs:** option-reads return the provider's _default_ (every module's options always exist — files are imported unconditionally), and shared-conduit writes (`programs.plasma|zsh|bash`) are ignored if the conduit is off. Healthy inverse already in-tree = **guarded optional consumption** (`themeCtx` `hasTheme`, `mkIf config.programs.zsh.enable`) — self-heals when the provider is off.

**Method.** Deterministic ref-graph scan (Nix-level + `.desktop`, complete) as ground truth + 10-agent workflow over all 153 modules for binary-in-string refs grep can't see + adversarial verify. ⚠ **Agent self-partitioning (`P % 10 == k`) LEAKED: 17 modules missed (incl. `plasma`, `yazi`), others double-scanned.** Lesson: the orchestrator must compute _explicit disjoint_ assignments; never let agents self-partition. Two agent refutations overridden on deterministic re-check (`zsh→eza@299`, `zellij→nvim`).

**VERIFIED danglings — ✅ REMEDIATED 2026-06-02 (eval-verified bidirectionally, both hosts):**
| # | consumer | → provider | kind | site | trigger |
|---|---|---|---|---|---|
| 1 | neovim | yazi | binary | neovim/default.nix:234 | `<leader>fy` |
| 2 | neovim | lazygit | binary | neovim/default.nix:244 | `<leader>gl` |
| 3 | zsh | bat | binary | zsh/default.nix:204 | `cat` alias |
| 4 | zsh | eza | binary | zsh/default.nix:299 | fzf-tab cd preview |
| 5 | zsh | eza | binary | zsh/default.nix:300 | fzf-tab ls preview |
| 6 | zellij | neovim | binary | zellij/default.nix:30 | `scrollback_editor = "nvim"` |
| 7 | plasma | ghostty | desktop-id | plasma/shortcuts.nix:176 | Ctrl+Alt+T (added 2026-06-02) |
| 8 | plasma | ghostty | desktop-id | plasma/appearance.nix:65 | default terminal (added 2026-06-02) |

- candidate: `yazi → zoxide` (binary/plugin, yazi/default.nix:79) — confirm on remediation.

**Tier 2 — host/flatpak-provided:** plasma/panels.nix:51-53 → librewolf/chromium/betterbird flatpak `.desktop` (depend on host `services.flatpak.packages`).
**Tier 3 — assumed-present KDE (low risk):** plasma/shortcuts.nix → dolphin/krunner/spectacle/plasma-systemmonitor/emojier (KDE ships them).
**Tier 4 — NOT danglings (verified inert / guarded):** all `programs.plasma.*` conduit writes (konsole/kate/okular/macbook); option-reads (defaulted); `zsh→git` in nrb-functions (git ubiquitous, borderline). `delta→git` & `yazi→zsh` = GUARDED (the good pattern).

**Remediation — DONE 2026-06-02 (one convention: guarded optional consumption):**

- #1–6 (binary refs): guarded on `config.myModules.home.<provider>.enable` via `lib.optionalString`/`optionalAttrs` (zsh cat→bat + eza fzf-preview; neovim yazi/lazygit keybinds in the Lua heredoc; zellij scrollback_editor; yazi zoxide `require`). Self-heal — verified present-when-enabled, **absent-when-disabled**.
- #7–8 (plasma↔ghostty): replaced the hardcoded id with `myModules.home.plasma.defaultTerminal` option (`plasma/default.nix`) = `ghostty > konsole > null`, consumed by `appearance.nix` (kdeglobals) + `shortcuts.nix` (Ctrl+Alt+T); dangling now **structurally impossible** (id derived from `.enable`). Fail-fast `assertion` if a plasma host has no terminal. Verified: ghostty when on, **falls back to konsole when ghostty forced off**.
- Tier 2: flatpak panel pins lifted to `plasma.panels.pinnedLaunchers` (safe default), wired per-host on macbook + ryzen.
- Tier 3: KDE-bundled apps documented as assumed-present in `shortcuts.nix`.
- Remaining detector hit `plasma/default.nix:56-57` is a FALSE POSITIVE — the `defaultTerminal` option's own `if ghostty.enable then "…ghostty.desktop"` priority literal is self-guarding by construction. (Informs the closure-integrity check below: a `.desktop` literal inside `if <provider>.enable` must be treated as guarded.)
- TODO: CI closure-integrity check (§ below, layer 3) not yet built.

**Automated catch — 3 layers (build on remediation):**

1. **pre-commit grep-lint** (fast, fuzzy tripwire) — scan modules for binary/`.desktop` refs to other modules lacking a guard; needs a provider→binary index + conduit allowlist (`plasma`/`zsh`/`bash`) + _exact_ `.desktop` segment match (substring `git`⊂`gitlab` was a real detector false-positive).
2. **CI Nix `assertion`s** for declared deps → `nix flake check`/build fails fast when a referenced provider is disabled.
3. **CI closure-integrity** (robust, exact, zero-FP): realize each host HM profile, assert every referenced `.desktop`/binary exists in the closure (else allowlist as system/flatpak). **Notify = CI red** (fleet GHA) + local pre-commit block.

## §20 — Coverage extended to ALL nix config + automated gates SHIPPED (2026-06-02)

**parts/ audit (the other half of "all our nix configuration") — CLEAN, and not by luck.** parts modules pin `${pkgs.X}` (self-contained, no PATH dependency on another module) and express hard cross-module deps as `assertions` (`assertion = config.myModules.<other>.enable; message = "requires …"` — rocksmith→pipewire, portmaster→mullvad). The runtime-resource "dangling" model genuinely does not apply to parts (no app-binary/`.desktop` refs) — forcing it there would be placebo. The cross-module READS that exist are host-identity (`primaryUser`, `host.tier`) and assertions — all legitimate.

**The real cross-cutting standard for both layers = the dendritic invariant**: a module must not WRITE config into another module's `myModules.*` namespace (reads are inert/fine; shared-conduit writes `programs.plasma|zsh|bash` are governed separately). Found + fixed one live violation: `home/modules/macbook/dock.nix` wrote `myModules.home.plasma.panels.showPager` — deleted (the macbook **host** already sets it at line 196; zero behaviour change, dendritic-clean).

**Two gates SHIPPED** (pre-commit hook + `nix flake check`/CI, each with a non-vacuous fixture test that proves catch + pass; `# dangling-ok:` / `# foreign-ok:` escape hatches):

- **`check-dangling-refs`** — unguarded cross-module runtime-resource refs (binary/`.desktop`) in `home/modules`. Caught 2 real ones the LLM audit missed (`kate→nil`, `vscode→nil`), now guarded.
- **`check-no-foreign-config`** — dendritic-invariant: no foreign `myModules.*` writes, across `home/modules` **and** `parts`. Caught + fixed `macbook/dock.nix`.
  Files: `parts/_build/checks/check-{dangling-refs,no-foreign-config}.{py,nix}`, fixtures in `parts/_build/tests/fixtures/`, wired in `git-hooks.nix` + `tests.nix` (flake checks `check-dangling-refs[-test]`, `check-no-foreign-config[-test]`).
