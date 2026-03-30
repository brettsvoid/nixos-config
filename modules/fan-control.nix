# MSI fan control via isw (ice-sealed wyvern)
# Reads/writes EC registers to set fan curves for MSI laptops.
# Profile 17E2EMS1 covers GE75 Raider 8SF (MS-17E2).
{ config, lib, pkgs, ... }:

let
  isw = pkgs.stdenv.mkDerivation {
    pname = "isw";
    version = "unstable-2020-02-26";

    src = pkgs.fetchFromGitHub {
      owner = "YoyPa";
      repo = "isw";
      rev = "7c88670504ecd4462b1825a55bdb0be2944dfe94";
      hash = "sha256-HN3egLX08CC9SLxldpCj5KHSiyV1F3HeR5NXk68NXY0=";
    };

    buildInputs = [ pkgs.python3 ];

    dontBuild = true;
    dontConfigure = true;

    postPatch = ''
      patchShebangs isw
    '';

    installPhase = ''
      install -Dm755 isw $out/bin/isw
      install -Dm644 etc/isw.conf $out/etc/isw.conf
    '';
  };
in
{
  # Load ec_sys with write support so isw can access EC registers
  boot.kernelModules = [ "ec_sys" ];
  boot.extraModprobeConfig = "options ec_sys write_support=1";

  # isw hardcodes /etc/isw.conf
  environment.etc."isw.conf".source = "${isw}/etc/isw.conf";

  environment.systemPackages = [ isw ];

  # Apply fan curve at boot and after resume from suspend/hibernate
  systemd.services.isw = {
    description = "Apply MSI fan curve via isw";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" "suspend.target" "hibernate.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "${isw}/bin/isw -w 17E2EMS1";
    };
  };
}
