{ pkgs, packages }:
with packages;
{
  dev = [
    git
    infisical
    pls
    skopeo
  ];

  lint = [
    actionlint
    dotnetlint
    gitlint
    go-task
    infralint
    pre-commit
    sg
    shellcheck
    treefmt
  ];

  main = [
    dotnet-sdk_10
  ];

  releaser = [
    sg
  ];

  system = [
    atomiutils
    infrautils
  ];
}
