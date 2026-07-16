# dev-dirs -- single authority for dev-tool state under $HOME. Each tool declares
# its DEFAULT leak path and its redirect in ONE place (`tools`), from which the
# session vars (prevention), `stateDirs` (index/backup exclusion), and the
# check-home-pollution reporter (detection) all derive -- so they cannot drift.
# Tools already XDG-clean (ccache, pip, GOCACHE, DENO_DIR) need nothing here.
# pre-commit and huggingface are redirected DELIBERATELY despite being
# XDG-clean: hook repos + language envs and multi-gigabyte model stores are
# expensive tool-state, not disposable cache -- a ~/.cache wipe must not cost
# hook rebuilds or model re-downloads -- so they live under dataHome with the
# other index-excluded stateDirs. cabal is deliberately absent: it is XDG by
# default unless ~/.cabal exists, and setting CABAL_DIR would regress it to one
# legacy dir.
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
let
  cfg = config.myModules.home.dev-dirs;
  inherit (config.xdg)
    dataHome
    cacheHome
    configHome
    stateHome
    ;

  # Redirect target dirs under ~/.local/share (the big, index-worth-excluding
  # ones). Referenced by `tools` below and exported as `stateDirs`.
  dirs = {
    cargo = "${dataHome}/cargo";
    rustup = "${dataHome}/rustup";
    go = "${dataHome}/go";
    bun = "${dataHome}/bun";
    deno = "${dataHome}/deno";
    stack = "${dataHome}/stack";
    dotnet = "${dataHome}/dotnet";
    nuget = "${dataHome}/NuGet";
    gradle = "${dataHome}/gradle";
    platformio = "${dataHome}/platformio";
    android = "${dataHome}/android";
    pre-commit = "${dataHome}/pre-commit";
    huggingface = "${dataHome}/huggingface";
  };

  # SINGLE SOURCE OF TRUTH -- tool -> { leak; vars }:
  #   leak = the ~/-relative path the tool writes by DEFAULT. Its presence means
  #          a redirect was bypassed or a stale pre-redirect leftover remains;
  #          check-home-pollution watches exactly these.
  #   vars = the env var(s) that enact the redirect. Nix-resolved absolute paths,
  #          never "$XDG_*" (hm #6027). Names/defaults verified against each
  #          tool's own upstream docs.
  # Every entry MUST set `leak` -- omit it and `leakPaths` fails to evaluate, so a
  # new tool cannot be redirected without also becoming detectable.
  tools = {
    # -- Language toolchains (home under ~/.local/share) --
    cargo = {
      leak = ".cargo";
      vars.CARGO_HOME = dirs.cargo;
    }; # registry/git/bins; CARGO_TARGET_DIR stays project-local
    rustup = {
      leak = ".rustup";
      vars.RUSTUP_HOME = dirs.rustup;
    }; # pairs with CARGO_HOME (its bin stays on PATH)
    go = {
      leak = "go";
      vars.GOPATH = dirs.go;
    }; # GOMODCACHE follows GOPATH; GOCACHE stays ~/.cache/go-build
    bun = {
      leak = ".bun";
      vars.BUN_INSTALL = dirs.bun;
    }; # cache lives under $BUN_INSTALL/install/cache
    deno = {
      leak = ".deno";
      vars.DENO_INSTALL_ROOT = dirs.deno;
    }; # global `deno install` bins; DENO_DIR cache already XDG
    stack = {
      leak = ".stack";
      vars.STACK_ROOT = dirs.stack;
    }; # Haskell + GHC downloads (large)
    dotnet = {
      leak = ".dotnet";
      vars.DOTNET_CLI_HOME = dirs.dotnet;
    }; # ~/.microsoft (usersecrets) has no var, stays
    nuget = {
      leak = ".nuget";
      vars.NUGET_PACKAGES = "${dirs.nuget}/packages";
    };
    gradle = {
      leak = ".gradle";
      vars.GRADLE_USER_HOME = dirs.gradle;
    }; # caches, wrapper dists, daemon, config
    java = {
      leak = ".java";
      vars._JAVA_OPTIONS = "-Djava.util.prefs.userRoot=${configHome}/java";
    }; # java.util.prefs store; the JVM echoes "Picked up _JAVA_OPTIONS" to stderr by design
    platformio = {
      leak = ".platformio";
      vars.PLATFORMIO_CORE_DIR = dirs.platformio;
    }; # set before first install
    pre-commit = {
      leak = ".cache/pre-commit";
      vars.PRE_COMMIT_HOME = dirs.pre-commit;
    }; # hook repos + language envs: tool-state, not disposable cache (see header)
    huggingface = {
      leak = ".cache/huggingface";
      vars.HF_HOME = dirs.huggingface;
    }; # model store: tool-state, not disposable cache (see header); set FRESH before the first download
    android = {
      leak = ".android"; # current names; ANDROID_SDK_ROOT/_SDK_HOME deprecated. Set FRESH (moving after AVDs exist breaks their ini paths)
      vars = {
        ANDROID_HOME = "${dirs.android}/sdk";
        ANDROID_USER_HOME = dirs.android;
        ANDROID_AVD_HOME = "${dirs.android}/avd";
      };
    };
    npm = {
      leak = ".npm"; # BOTH vars needed: USERCONFIG moves ~/.npmrc, CACHE moves ~/.npm into ~/.cache (already index-excluded)
      vars = {
        NPM_CONFIG_CACHE = "${cacheHome}/npm";
        NPM_CONFIG_USERCONFIG = "${configHome}/npm/npmrc";
      };
    };

    # -- REPL history (~/.local/state) --
    node = {
      leak = ".node_repl_history";
      vars.NODE_REPL_HISTORY = "${stateHome}/node/repl_history";
    }; # "" would disable
    python = {
      leak = ".python_history";
      vars.PYTHON_HISTORY = "${stateHome}/python/history";
    }; # PYTHON_HISTORY: 3.13+ (host is)

    # -- Ad-hoc CLIs reachable via `nix run` (redirect pre-empts first use) --
    docker = {
      leak = ".docker";
      vars.DOCKER_CONFIG = "${configHome}/docker";
    }; # CLI config dir; daemon unaffected
    kube = {
      leak = ".kube";
      vars.KUBECONFIG = "${configHome}/kube/config";
    }; # colon-list; writes land in the first file
    gem = {
      leak = ".gem";
      vars.GEM_SPEC_CACHE = "${cacheHome}/gem/specs";
    }; # cache-only; GEM_HOME NOT set (changes gem resolution)
  };

  sessionVars = lib.foldl' (acc: t: acc // t.vars) { } (lib.attrValues tools);
  leakPaths = lib.map (t: t.leak) (lib.attrValues tools);

  # Detection -- report any managed tool that leaked into $HOME anyway. Watches
  # exactly `leakPaths`, so it can never drift from what we redirect. Self-contained
  # (bash builtins only), read-only, always exits 0 (a reporter, not a gate).
  pollutionCheck = pkgs.writeShellApplication {
    name = "check-home-pollution";
    text = ''
      leaks=(${lib.concatStringsSep " " (map (p: ''"${p}"'') leakPaths)})
      found=0
      for p in "''${leaks[@]}"; do
        if [[ -e "$HOME/$p" ]]; then
          printf 'POLLUTION  ~/%s  -- dev-dirs redirects this; env not honored or stale leftover\n' "$p" >&2
          found=1
        fi
      done
      if [[ "$found" -eq 0 ]]; then
        echo "home clean: no dev-dirs-managed tool is leaking into \$HOME"
      fi
      exit 0
    '';
  };
in
{
  options.myModules.home.dev-dirs = {
    enable = lib.mkEnableOption "redirect dev-tool state out of $HOME into XDG paths";
    stateDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = lib.attrValues dirs;
      description = ''
        Absolute paths of the redirected dev-tool state dirs under
        ~/.local/share. Read-only single source for consumers (e.g. Baloo
        indexing exclusions, backup ignores) so directory locations are never
        re-listed and cannot drift.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (myLib.mkSessionVars sessionVars)
      {
        # On-demand + every-switch leak report (warn-only, never blocks the switch).
        home.packages = [ pollutionCheck ];
        home.activation.checkHomePollution = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${pollutionCheck}/bin/check-home-pollution || true
        '';
      }
    ]
  );
}
