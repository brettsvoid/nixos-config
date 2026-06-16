# MSI fan control via isw (ice-sealed wyvern)
# Reads/writes EC registers to set fan curves for MSI laptops.
# Profile 17E2EMS1 covers GE75 Raider 8SF (MS-17E2).
_: {
  flake.modules.nixos.fan-control =
    { pkgs, ... }:
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
          # Adjust fan curve for 17E2EMS1 profile
          sed -i '/^\[17E2EMS1\]/,/^\[/ {
            s/^cpu_fan_speed_6 = 90/cpu_fan_speed_6 = 100/
            s/^gpu_fan_speed_2 = 52/gpu_fan_speed_2 = 55/
            s/^gpu_fan_speed_3 = 59/gpu_fan_speed_3 = 60/
            s/^gpu_fan_speed_4 = 69/gpu_fan_speed_4 = 70/
            s/^gpu_fan_speed_5 = 79/gpu_fan_speed_5 = 80/
            s/^gpu_fan_speed_6 = 89/gpu_fan_speed_6 = 100/
          }' etc/isw.conf
        '';

        installPhase = ''
          install -Dm755 isw $out/bin/isw
          install -Dm644 etc/isw.conf $out/etc/isw.conf
        '';
      };
    in
    {
      boot.kernelModules = [ "ec_sys" ];
      boot.extraModprobeConfig = "options ec_sys write_support=1";

      # isw hardcodes /etc/isw.conf
      environment.etc."isw.conf".source = "${isw}/etc/isw.conf";

      environment.systemPackages = [ isw ];

      systemd.services.isw = {
        description = "Apply MSI fan curve via isw";
        after = [ "multi-user.target" ];
        wantedBy = [
          "multi-user.target"
          "suspend.target"
          "hibernate.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
          ExecStart = "${isw}/bin/isw -w 17E2EMS1";
        };
      };
    };
}
