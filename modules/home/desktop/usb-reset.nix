# usb-reset: unbind and rebind every xHCI USB controller.
#
# On 13 November 2026 the desktop's controller wedged after 12 days up: everything behind
# the KVM failed with "Timeout while waiting for setup device command". This brought it
# back. Every USB device drops for a few seconds, so run it over SSH if input is dead.
{
  flake.modules.homeManager.desktop-usb-reset =
    { pkgs, ... }:
    let
      usb-reset = pkgs.writeShellApplication {
        name = "usb-reset";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          driver=/sys/bus/pci/drivers/xhci_hcd
          controllers=()
          for dev in "$driver"/0000:*; do
            [ -e "$dev" ] && controllers+=("''${dev##*/}")
          done
          if [ ''${#controllers[@]} -eq 0 ]; then
            echo "usb-reset: no controller is bound to xhci_hcd" >&2
            exit 1
          fi
          for c in "''${controllers[@]}"; do
            echo "Resetting $c"
            echo "$c" | sudo tee "$driver/unbind" >/dev/null
            sleep 2
            echo "$c" | sudo tee "$driver/bind" >/dev/null
          done
        '';
      };
    in
    {
      home.packages = [ usb-reset ];
    };
}
