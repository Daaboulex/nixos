# nixpkgs' bun ships upstream's prebuilt bun-linux-x64, which requires AVX2;
# the macbook's i5-3210M (Ivy Bridge: AVX, no AVX2) SIGILLs on it, and
# llm-agents' pi embeds that runtime via `bun build --compile` (no --target
# = the running bun), so the locally built pi dies with it. nixpkgs closed
# baseline packaging as not-planned (#298612); upstream publishes an official
# -baseline artifact per release (SHASUMS256.txt-verified hash below). Open
# upstream caveat: bun #30613 reports baseline >=1.3.9 crashing on CPUs with
# no AVX at all — this CPU has AVX1, outside that class; verified by running
# pi on the box after the swap.
{
  # bun moved past the version observed broken — re-verify baseline is still
  # needed on the i5-3210M (and refresh the hash), or delete.
  dropWhen = pkgs: pkgs.bun.version != "1.3.13";
  overlay = _final: prev: {
    bun = prev.bun.overrideAttrs (old: {
      src = prev.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${old.version}/bun-linux-x64-baseline.zip";
        hash = "sha256-nYokKSpwaAkCBdqsCloiP19pc29Sh+N7+I07QDHtx1A=";
      };
    });
  };
}
