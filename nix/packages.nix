{
  atomi,
  pkgs,
  pkgs-2605,
  pkgs-unstable,
}:
let
  all = rec {
    atomipkgs = (
      with atomi;
      rec {
        dotnetlint = atomi.dotnetlint.override { dotnetPackage = nix-2605.dotnet-sdk_10; };
        dn-inspect = atomi.dn-inspect.overrideAttrs (old: {
          buildCommand = old.buildCommand + ''
            wrapper="$out/bin/dn-inspect"
            ${pkgs.gnused}/bin/sed -i \
              's#[^:"]*dotnet-sdk-wrapped-[^:/"]*/bin#${nix-2605.dotnet-sdk_10}/bin#g' \
              "$wrapper"

            inner="$(${pkgs.gnused}/bin/sed -n 's#^\(/nix/store/.*-dn-inspect\.sh\) "\$@"$#\1#p' "$wrapper")"
            test -n "$inner"
            patched="$out/bin/dn-inspect-inner.sh"
            cp "$inner" "$patched"
            chmod +x "$patched"
            ${pkgs.gnused}/bin/sed -i \
              's#inspectcode_args="$sln_file --format=Sarif --output=$report_file"#inspectcode_args="$sln_file --format=Sarif --output=$report_file --properties:RunAnalyzers=false --verbosity=OFF"#' \
              "$patched"
            ${pkgs.gnused}/bin/sed -i "s#$inner#$patched#g" "$wrapper"
          '';
        });

        inherit
          atomiutils
          infralint
          infrautils
          pls
          sg
          ;
      }
    );

    nix-2605 = (
      with pkgs-2605;
      {
        inherit
          actionlint
          dotnet-sdk_10
          git
          gitlint
          go-task
          infisical
          pre-commit
          shellcheck
          skopeo
          treefmt
          ;
      }
    );

    nix-unstable = (
      with pkgs-unstable;
      {
      }
    );
  };
in
with all;
atomipkgs // nix-2605 // nix-unstable
