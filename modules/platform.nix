{
  lib,
  ...
}:
{
  options.my.platform.isWsl = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether the system is running under WSL2.

      This configuration targets WSL2. Auto-detection via /proc and
      environment variables cannot work in pure flake evaluation
      (nix build, nix flake check, and home-manager/nh switch all run
      pure, which forbids filesystem and environment access), so it
      defaults to true. Override to false when deploying to a non-WSL
      host.
    '';
  };
}
