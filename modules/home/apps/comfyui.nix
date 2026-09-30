# ComfyUI — the node-based image and video generation UI.
# https://github.com/Comfy-Org/ComfyUI
#
# Run from a git checkout with a uv venv, not from nixpkgs. ComfyUI-Manager
# installs each custom node's Python dependencies with pip at runtime, which a
# Nix-built ComfyUI cannot take. So this module owns only what the checkout
# needs from the system, plus a launcher; the rest is state:
#
#   ~/comfyui     git checkout, with .venv on a uv-managed CPython 3.13 (the
#                 README calls 3.13 "very well supported"; 3.14 "works but
#                 some custom nodes may have issues")
#   ~/ai-models   its own btrfs subvolume, so that a snapshot of @home leaves
#                 the weights out. Passed to ComfyUI as --models-directory.
#
# ComfyUI-Manager is no longer a clone in custom_nodes/: it is the
# comfyui_manager package from the checkout's manager_requirements.txt,
# switched on by --enable-manager.
#
# uv's CPython and the PyTorch wheels are generic glibc binaries, so they run
# through nix-ld, as the native Claude Code build does.
_: {
  flake.modules.nixos.apps-comfyui =
    { pkgs, ... }:
    {
      programs.nix-ld.enable = true;

      # Added to nix-ld's base set, not in place of it: nixpkgs defines that
      # set in the module's config, not as the option's default, so the two
      # lists merge. These are what opencv-python, which many custom nodes
      # pull in, links against beyond the libraries its wheel bundles: found
      # from the NEEDED entries of cv2*.so and opencv_python.libs/*.
      programs.nix-ld.libraries = with pkgs; [
        libGL
        glib
        libx11
        libxcb
        libxext
        libsm
        libice
      ];
    };

  flake.modules.homeManager.apps-comfyui =
    { config, pkgs, ... }:
    let
      home = config.home.homeDirectory;

      comfyui = pkgs.writeShellApplication {
        name = "comfyui";
        text = ''
          # libcuda.so.1 ships with the driver in /run/opengl-driver/lib, which
          # is not on nix-ld's library path. Without it, PyTorch finds no GPU.
          export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
          # PyTorch runs some ops as Triton kernels (Anima sampling hits one).
          # Triton finds libcuda by running /sbin/ldconfig -p, which NixOS
          # does not have, then builds each kernel's launcher with a C compiler
          # from PATH, which is empty outside a dev shell. Without these,
          # sampling fails on /sbin/ldconfig, then on "Failed to find C
          # compiler".
          export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
          export CC=${pkgs.stdenv.cc}/bin/cc
          # uv's CPython looks for CAs in /etc/ssl/cert.pem, which NixOS does
          # not have, and in /etc/ssl/certs, which lacks the hashed links
          # OpenSSL reads a directory through. Without this, ComfyUI-Manager
          # fails every HTTPS fetch with CERTIFICATE_VERIFY_FAILED.
          export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
          # The venv is the whole environment. A dev shell's PYTHONPATH (this
          # repo's puts semgrep's python3.14 packages on it) would otherwise
          # load 3.14-built modules into the venv's 3.13 and crash on import.
          unset PYTHONPATH PYTHONHOME
          cd ${home}/comfyui
          # Measured with Anima on the 3080 Ti, these two cut sampling time by
          # about a quarter, and the images differ only in fine detail.
          # fp16_accumulation also makes ComfyUI load models that list fp16 as
          # supported in fp16. SageAttention is a Triton attention kernel from
          # the venv (uv pip install sageattention); ComfyUI exits at start-up
          # if asked for it without the package, so the flag waits for it.
          fast=(--fast fp16_accumulation)
          # A plain glob: the script's non-interactive bash has no compgen.
          for dir in .venv/lib/python3*/site-packages/sageattention; do
            if [[ -d $dir ]]; then fast+=(--use-sage-attention); fi
          done
          exec .venv/bin/python main.py --models-directory ${home}/ai-models --enable-manager "''${fast[@]}" "$@"
        '';
      };
    in
    {
      home.packages = [
        pkgs.uv
        comfyui
      ];
    };
}
