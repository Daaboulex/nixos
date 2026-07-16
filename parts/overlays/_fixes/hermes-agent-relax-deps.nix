# hermes-agent upstream pins rich/pillow with == which our channel outruns
# (only numtide's own frozen nixpkgs satisfied them exactly); upstream
# already relaxes 13 other pins the same way.
{
  # Upstream's own relax list now covers rich and pillow — delete this fix.
  dropWhen =
    pkgs:
    let
      relaxed = pkgs.llm-agents.hermes-agent.pythonRelaxDeps or [ ];
    in
    builtins.elem "rich" relaxed && builtins.elem "pillow" relaxed;
  overlay = _final: prev: {
    llm-agents = prev.llm-agents // {
      hermes-agent = prev.llm-agents.hermes-agent.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [
          "rich"
          "pillow"
        ];
      });
    };
  };
}
