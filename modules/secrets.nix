{ config, ... }:
let
  homeDir = config.home.homeDirectory;
  xdgConfigHome = config.xdg.configHome;
  gitUserConf = "${xdgConfigHome}/git/user.conf";
  jjUserConf = "${xdgConfigHome}/jj/config.toml";
in
{
  sops = {
    age.keyFile = "${homeDir}/.config/sops/age/keys.txt";
    defaultSopsFile = ../secrets/secrets.yaml;
    secrets."example_secret" = { };
    secrets."github_private_mail" = { };
    secrets."github_private_name" = { };
    templates."example.env" = {
      content = ''
        EXAMPLE_SECRET=${config.sops.placeholder."example_secret"}
      '';
      path = "${homeDir}/.config/example/.env";
    };
    templates."git-user.conf" = {
      content = ''
        [user]
          name = ${config.sops.placeholder."github_private_name"}
          email = ${config.sops.placeholder."github_private_mail"}
      '';
      path = gitUserConf;
    };
    templates."jj-user.conf" = {
      content = ''
        [user]
          name = "${config.sops.placeholder."github_private_name"}"
          email = "${config.sops.placeholder."github_private_mail"}"

        [ui]
          default-command = "log"
          editor = "nano"
      '';
      path = jjUserConf;
    };
  };
}
