{
  formatter,
  packages,
  pre-commit-lib,
}:
let
  # One dotnet-format-style lint hook per project. Per-project `files` scoping keeps incremental
  # runs fast and pins a failure to a single project; defining the shared command and boilerplate
  # here means an SDK bump or flag change is a one-line edit instead of four near-identical blocks.
  dotnetLintHook =
    { project, files }:
    {
      enable = true;
      description = "Lint the ${project} project with dotnet format style";
      entry = "${packages.dotnet-sdk_10}/bin/dotnet format style --no-restore --severity info --verify-no-changes -v d ./${project}/${project}.csproj";
      inherit files;
      name = "Dotnet Lint (${project})";
      pass_filenames = false;
      language = "system";
    };
in
pre-commit-lib.run {
  src = ./.;

  hooks = {
    a-dotnet-lint-app = dotnetLintHook {
      project = "App";
      files = "^App/.*\\.cs$";
    };

    a-dotnet-lint-int-test = dotnetLintHook {
      project = "IntTest";
      files = "^IntTest/.*\\.cs$";
    };

    a-dotnet-lint-lib = dotnetLintHook {
      project = "Lib";
      files = "^Lib/.*\\.cs$";
    };

    a-dotnet-lint-unit-test = dotnetLintHook {
      project = "UnitTest";
      files = "^UnitTest/.*\\.cs$";
    };

    a-enforce-exec = {
      enable = true;
      entry = "${packages.atomiutils}/bin/chmod +x";
      files = ".*sh$";
      name = "Enforce Shell Script executable";
      pass_filenames = true;
      language = "system";
    };

    a-enforce-gitlint = {
      enable = true;
      description = "Enforce atomi_releaser conforms to gitlint";
      entry = "${packages.sg}/bin/sg gitlint -c atomi_release.yaml";
      files = "(atomi_release\\.yaml|\\.gitlint)";
      name = "Enforce gitlint";
      pass_filenames = false;
      language = "system";
    };

    a-gitlint = {
      enable = true;
      description = "Lints git commit message";
      entry = "${packages.gitlint}/bin/gitlint --staged --msg-filename";
      name = "Gitlint";
      pass_filenames = true;
      stages = [
        "commit-msg"
      ];
      language = "system";
    };

    a-infisical = {
      enable = true;
      description = "Scan for possible secrets";
      entry = "${packages.infisical}/bin/infisical scan . -v";
      name = "Secrets Scanning";
      pass_filenames = false;
      language = "system";
    };

    a-infisical-staged = {
      enable = true;
      description = "Scan for possible secrets in staged files";
      entry = "${packages.infisical}/bin/infisical scan git-changes --staged -v";
      name = "Secrets Scanning (Staged files)";
      pass_filenames = false;
      language = "system";
    };

    a-shellcheck = {
      enable = true;
      entry = "${packages.shellcheck}/bin/shellcheck";
      files = ".*sh$";
      name = "Shell Check";
      pass_filenames = true;
      language = "system";
    };

    treefmt = {
      enable = true;
      excludes = [
        ".*(Changelog|README|CommitConventions).+(MD|md)"
        ".*infra/root_chart.*"
        ".*node_modules.*"
      ];
      package = formatter;
    };
  };
}
