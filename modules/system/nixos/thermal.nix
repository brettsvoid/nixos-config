# IIO sensor stack + Intel thermal daemon. Pair with fan-control for full
# thermal management on supported laptops.
_: {
  flake.modules.nixos.thermal =
    { pkgs, ... }:
    {
      hardware.sensor.iio.enable = true;
      services.thermald.enable = true;
      environment.systemPackages = [ pkgs.lm_sensors ];
    };
}
