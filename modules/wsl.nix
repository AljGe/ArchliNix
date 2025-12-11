{
  config,
  lib,
  ...
}: let
  isWsl = builtins.pathExists "/proc/sys/fs/binfmt_misc/WSLInterop";
  shellLdAppend = "$" + "{LD_LIBRARY_PATH:+:" + "$" + "{LD_LIBRARY_PATH}}";
  xdgConfigHome = config.xdg.configHome;
in {
  options.wsl = {
    enable = lib.mkEnableOption "WSL-specific settings";
    trimDesktopPackages = lib.mkOption {
      type = lib.types.bool;
      default = isWsl;
      description = "Skip GUI-only packages when running under WSL.";
    };
  };

  config = lib.mkIf (config.wsl.enable or isWsl) {
    home.sessionVariables.VK_DRIVER_FILES = "${xdgConfigHome}/vulkan/icd.d/nvidia_wsl.json";

    home.sessionVariablesExtra = ''
      export LD_LIBRARY_PATH="/usr/lib/wsl/lib${shellLdAppend}"
    '';

    xdg.configFile."vulkan/icd.d/nvidia_wsl.json".text = ''
      {
        "file_format_version" : "1.0.0",
        "ICD": {
          "library_path": "/usr/lib/wsl/lib/libnvwgf2umx.so",
          "api_version" : "1.3.0"
        }
      }
    '';
  };
}
