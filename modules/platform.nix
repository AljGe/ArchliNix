{
  lib,
  ...
}: let
  wslInterop = builtins.pathExists "/proc/sys/fs/binfmt_misc/WSLInterop";
  wslDistro = (builtins.getEnv "WSL_DISTRO_NAME") != "";
  kernelVersion =
    if builtins.pathExists "/proc/version"
    then builtins.readFile "/proc/version"
    else "";
  kernelHasMicrosoft = (builtins.match ".*[Mm]icrosoft.*" kernelVersion) != null;
  isWslDetected = wslInterop || wslDistro || kernelHasMicrosoft;
in {
  options.my.platform.isWsl = lib.mkOption {
    type = lib.types.bool;
    default = isWslDetected;
    description = "Whether the system is running under WSL (auto-detected, overridable).";
  };
}