{
  lib,
  ...
}: let
  isWslDetected = builtins.pathExists "/proc/sys/fs/binfmt_misc/WSLInterop";
in {
  options.my.platform.isWsl = lib.mkOption {
    type = lib.types.bool;
    default = isWslDetected;
    description = "Whether the system is running under WSL (auto-detected, overridable).";
  };
}

