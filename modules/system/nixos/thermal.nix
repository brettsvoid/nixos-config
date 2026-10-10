# IIO sensors and the Intel thermal daemon. Pair with fan-control on MSI
# laptops.
_: {
  flake.modules.nixos.thermal =
    { pkgs, ... }:
    {
      hardware.sensor.iio.enable = true;
      services.thermald.enable = true;
      environment.systemPackages = [ pkgs.lm_sensors ];
    };
}
