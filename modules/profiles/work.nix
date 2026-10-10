# Work-only tools and AWS settings, kept out of `code` so home machines
# don't carry them.
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
