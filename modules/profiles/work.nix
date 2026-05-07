# Work-machine extras: a thin layer of AWS configs and work-only tools.
# Distinct from `code` so home machines don't carry work tooling.
_: {
  flake.modules.homeManager.profile-work =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        awscli2
        ssm-session-manager-plugin
        terraform
        vault
        kubectl
        k9s
        kubernetes-helm
      ];

      home.sessionVariables = {
        AWS_PAGER = "";
        AWS_SDK_LOAD_CONFIG = "1";
      };
    };
}
