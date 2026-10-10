# ComfyUI — the node-based image and video generation UI.
# https://github.com/Comfy-Org/ComfyUI
#
# Run from a git checkout with a uv venv, not from nixpkgs. ComfyUI-Manager
# installs each custom node's Python dependencies with pip at runtime, which a
# Nix-built ComfyUI cannot take. So this module owns only what the checkout
# needs from the system, plus a launcher; the rest is state:
#
#   ~/comfyui     git checkout, with .venv on a uv-managed CPython 3.13 (the
#                 README calls it very well supported; 3.14 may break nodes)
#   ~/ai-models   its own btrfs subvolume, so that a snapshot of @home leaves
#                 the weights out. Passed to ComfyUI as --models-directory.
#
# ComfyUI-Manager is the comfyui_manager package from the checkout's
# manager_requirements.txt, switched on by --enable-manager.
#
# uv's CPython and the PyTorch wheels are generic glibc binaries, so they run
# through nix-ld, as the native Claude Code build does.
_: {
  flake.modules.nixos.apps-comfyui =
    { pkgs, ... }:
    {
      programs.nix-ld.enable = true;

      # Merged with nix-ld's base set, which nixpkgs sets in config rather
      # than as the option default. These are what opencv-python, which many
      # custom nodes pull in, links against beyond what its wheel bundles.
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
          # lacks, and builds each kernel's launcher with a C compiler from
          # PATH, where there is none outside a dev shell.
          export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
          export CC=${pkgs.stdenv.cc}/bin/cc
          # uv's CPython looks for CAs in /etc/ssl/cert.pem, which NixOS lacks,
          # and in /etc/ssl/certs, which lacks the hashed links OpenSSL needs.
          # Without this every ComfyUI-Manager fetch fails certificate checks.
          export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
          # A dev shell's PYTHONPATH (this repo's carries semgrep's python3.14
          # packages) would load 3.14 modules into the venv's 3.13 and crash.
          unset PYTHONPATH PYTHONHOME
          cd ${home}/comfyui
          # fp16_accumulation and SageAttention together cut Anima sampling
          # time on the 3080 Ti by about a quarter, with images differing only
          # in fine detail. fp16_accumulation also loads models that support
          # fp16 in fp16. SageAttention comes from the venv (uv pip install
          # sageattention); ComfyUI exits if asked for it without the
          # package, so check first.
          fast=(--fast fp16_accumulation)
          # A plain glob: writeShellApplication's bash has no compgen.
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
