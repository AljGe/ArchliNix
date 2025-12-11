{
  config,
  lib,
  ...
}: let
  cfg = config.wsl;
  isWsl = config.my.platform.isWsl or false;
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

  config = lib.mkIf (cfg.enable or isWsl) {
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

    my.packages.enableCompute = lib.mkDefault (!cfg.trimDesktopPackages);
    my.packages.enableMonitoring = lib.mkDefault (!cfg.trimDesktopPackages);
    my.packages.enableGui = lib.mkDefault (!cfg.trimDesktopPackages);
    my.packages.enableFonts = lib.mkDefault (!cfg.trimDesktopPackages);
  };
}
