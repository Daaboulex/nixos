# docs — build mdBook documentation site with auto-generated option reference.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      docsSrc = ../../docs;
    in
    {
      packages.docs = pkgs.stdenvNoCC.mkDerivation {
        name = "nixos-flake-docs";
        src = docsSrc;
        nativeBuildInputs = [ pkgs.mdbook ];
        buildPhase = ''
          cp -r $src/* .
          chmod -R u+w .

          # Resolve symlinks in src/ to actual content
          for link in src/*.md; do
            if [ -L "$link" ]; then
              target=$(readlink "$link")
              rm "$link"
              cp "$src/$target" "$link" 2>/dev/null || echo "# Page not found" > "$link"
            fi
          done

          mdbook build
        '';
        installPhase = ''
          cp -r book $out
        '';
      };
    };
}
