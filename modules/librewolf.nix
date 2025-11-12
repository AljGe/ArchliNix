{
  config,
  lib,
  pkgs,
  ...
}: let
  mkEngine = {
    template,
    params ? [],
    icon ? null,
  }: let
    url = {inherit template params;};
  in
    lib.filterAttrs (k: v: v != null) {
      urls = [url];
      inherit icon;
    };
in {
  programs.librewolf = {
    enable = true;
    package = pkgs.librewolf;

    profiles.default = {
      id = 0;
      name = "Default";
      isDefault = true;

      search = {
        force = true;
        default = "gruble";
        privateDefault = "ddg";
        order = ["gruble" "ddg" "nixpkgs" "nix_options" "arch_wiki" "mdn" "github"];
        engines = {
          gruble = mkEngine {
            template = "https://www.gruble.de/?preferences=eJx1WMuO4zgS_JrxRRhjZnqxiz34NMBed4Cdu0CRKSlbFKnmw7bq6zeoJ1mqPpS7HSSTyWRmZNBSBOqsY_KPjgw5oW9amC6Kjh5C44uVQtODzE3EYKUdJ02BHirKIf119taKJ0trakfe6ie5x41HrK4nZ9_z428X6TZS6K16_PXf__1986IlT8LJ_vHbLfQ00sNzsnqDgaiDr2HL0KsOonn8R2hPN2X5tG4Fvt6t627rstqHGQ4m726STCBXC82dGfH_bb1QT2EkqXrbd0V_RHJzzaYOHGBgcZRNy4YDjEpntV7BdVVyS67BmmFIkwzrcG_DQLN_KGoF_L9Fp-vWulGEwKZ7TI5CmG-KvWg0fCDTsUG0v_3zt81wvQX-lz_-PMDqyYqsr-v1Xwz9uxNdXXsrWehqJMUCoJBtNNkkxKahyuOihrperuETutr9ekUlomKMjdGzTEOa3sIoxyJ3UegJ_leaTXxXk5BD2gSbhTRmjPBV8p-fVNct63V_42ECd7p8mYZqZOesyyZMuMgKn8kRV6wUSC0lNvuG39ZXLx5439APuW-NYBUvQLUGIgvICg-C291yw5rTXxaZhoPsI3KhgBokPYV91dQUuwXFXXd6v9zSXUp5V7kVqW1UrRaOBOfL5YRcackRcnXbAFnoPUBcvOSEr9hLPRkVkq2dafr09XrqBKZLOK5CEX2gXI4LV-SDCIwJFoXpEqK6CnmdaoKt8fkW8GbGSa45TPCPVWbjoIprUmdjpWcn_iKRDJ321mQZxYTp-Ew7jvY7TynY5yzUHs2U-_X7O4sFjqRCL8II_slhRygG24YXbqdS7FDlqd7X22gdm4GFzBfMc3bUjvijB7lkCLhFNNt6fOljU0mb0iGbQUgSO-6TrFXIDJUbsbbDkSct5lQk_sywfGS0SIo8uGAgcoktEj3nidCLxon0sW3Zo4rJrRewAvQ-EhBG_D3RwvKddTVZH46L6mMHOutacaRshlRKBOEp-C-GPKjj4A0eu-gyB9mI7By4WocEnPMJP3jOa_U7-96eAUMtO-HmKl2-5yxeH79uQye0z7UtLsZ06DN5qNIoBQcG0yIU6aRt4wPd3X4G9DghJ2H2r5xqF5lUaVTIgdqPvqj58TU2OgdMuiz8ZYcz054bZhYio5eo9VMo9OOCoDO4wtGehddWzZ5yMkKXE-POgnYik1g_p5uEHUHbA5xAHJhsCTmabBbttTuw3-ly4rdokKkXZtoHLvwAQrwSzAF-YegY2k19taygmik2oOfn7mJsNMtK2VGwWe2f_ezY5kcUrmg8C3B1x5FSHC5d23HXBxSHzU04GwIkCzYOlrLiX30eZ89l_kGCtL0Pl-L2trNFD1yAq28rfIn4Cr9IghxPOmYvo_f3aYaO23NZCqXmRFxj3KpzveNfe6vpgnsahQkIrZcYFy5PMdSRGDPqtsNsg0VFD6mc9mwKyXGsFsXpcnTzNoyqOa29uJnzBS-rW4eU11NflM3v3779633u5unDJKeyurLfiYYrcg3thhdptrDzxNqG0zWD4nRF8Sfgam-FC3MrdLk9F5u5o3HnpInIhdjk9b7kIPYfkoJ4UZMNzUIWkXIR3JSv1aiChbcz7GXfPFiDEqr8bKyZR8pzl4ZPjq_QNRsX-JqNoF4Zimx-dollsqXx_UJTyYCnZbXI0y0KL7xjesTLZHOShhwhawpG5-akc2-jkwT9d7blgkyG7t7ZjDg8GbwZIJPwrDgDgC0ILRRdYBWtC34DyRZPgYWUVkGda1v35mdeJg3EuBTjdAq2NHvTPZkKXaJRfv9CAie0uJkFudxAonWkms_pT_bUDjaR8n5OGV2SrUX6IDaMkhcuZEuVTVKjggzaLwdHSDKhWHmov0JXhnm0aEUmi2-rnE1ac6_aFuQ95EoCyzn6M2JdothdzKx6bKczqLKGXHfed6cLwt201iWSG17EcsMu0dzwLziw3_bb9FDOYAPOJHzWVzWN41ztDLuIvk8dZp0RPbmfjSUV97OxZBlx-mIYKfIsxYbAi01Z85O9juFe-B5U_cUMdSqm9_IyOi8LHWNg2lXqIk6gyE9RWYqUNLa2b7E9VspxcAlRwIthfzZMKjHjOWnCSz51t22U028J5PPsnTjJYSiVTONY1KTHa0Ml2bRfGfzAAQvj87QX9o8XyqJQDwkoE2iFLrm2wlfaF3i4Q-zZl8_fc47wfHU5904sdj2VdfwIXikjj3egHCzqvtX2db61YxNNiDvjRejy6I_78anUp_TLT07XO_ipCxzwF7pEs8Kjy60ZuMc5Go9Xju_z96zoS1JegHKj2cZPDfBAjlevYA1mSTmTTXvyWPxOkniqsAwgLSlkcZqUigfZd78cLB-83GA--OlnmHxoicYZFMUyfFhTRHxEBx7xZq2OV4squVWlRnh4bJ0yPOTiy4b0OE7X-qlUXyG4O2eLL6-LBbiefIUvZ17hsgeFf-y_n5y_mE06ok_6R9ICaB51-oHN4YzPrJXuc3rQGnQblkNFouYf_wd31t3S";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          };
          nixpkgs = mkEngine {
            template = "https://search.nixos.org/packages";
            params = [
              {
                name = "type";
                value = "packages";
              }
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          };
          nix_options = mkEngine {
            template = "https://search.nixos.org/options";
            params = [
              {
                name = "type";
                value = "options";
              }
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          };
          arch_wiki = mkEngine {
            template = "https://wiki.archlinux.org/index.php";
            params = [
              {
                name = "search";
                value = "{searchTerms}";
              }
            ];
          };
          mdn = mkEngine {
            template = "https://developer.mozilla.org/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          };
          github = mkEngine {
            template = "https://github.com/search";
            params = [
              {
                name = "q";
                value = "{searchTerms}";
              }
            ];
          };
        };
      };

      bookmarks = {
        force = true;
        settings = [
          {
            name = "Nix";
            toolbar = true;
            bookmarks = [
              {
                name = "Packages";
                url = "https://search.nixos.org/packages";
              }
              {
                name = "Options";
                url = "https://search.nixos.org/options";
              }
              {
                name = "Home Manager";
                url = "https://nix-community.github.io/home-manager/options.xhtml";
              }
            ];
          }
          {
            name = "Docs";
            toolbar = true;
            bookmarks = [
              {
                name = "Arch Wiki";
                url = "https://wiki.archlinux.org/";
              }
              {
                name = "MDN";
                url = "https://developer.mozilla.org/";
              }
              {
                name = "GitHub";
                url = "https://github.com/";
              }
            ];
          }
        ];
      };

      containers = {
        Personal = {
          id = 1;
          icon = "fingerprint";
          color = "toolbar";
        };
        Work = {
          id = 2;
          icon = "briefcase";
          color = "orange";
        };
        Shopping = {
          id = 3;
          icon = "cart";
          color = "pink";
        };
      };
      containersForce = true;
      extensions = {
        packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          clearurls
          libredirect
          localcdn
          sidebery
          tree-style-tab
          sponsorblock
          i-dont-care-about-cookies
          darkreader
          proton-pass
        ];
        force = true;
      };
      userChrome = "
          :root { --tab-min-height: 26px; }
          #TabsToolbar { height: 26px !important; }
        ";
    };

    settings = {
      "browser.startup.homepage" = "about:blank";
      "browser.shell.checkDefaultBrowser" = false;
      "browser.tabs.warnOnClose" = false;
      # UI theme, density, and dark mode preference
      "browser.theme.toolbar-theme" = 0; # follow system
      "browser.in-content.dark-mode" = true;
      "ui.systemUsesDarkTheme" = 1;
      "browser.uidensity" = 1; # compact
      "privacy.firstparty.isolate" = true;
      "privacy.resistFingerprinting.letterboxing" = true;
      "privacy.sanitize.sanitizeOnShutdown" = true;
      "network.cookie.lifetimePolicy" = 2;
      "dom.security.https_only_mode" = true;
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      "extensions.pocket.enabled" = false;
      # Auto-enable installed extensions and disable recommendations/promotions
      "extensions.autoDisableScopes" = 0; # don't auto-disable newly installed add-ons
      "extensions.enabledScopes" = 15; # enable all scopes
      "extensions.htmlaboutaddons.recommendations.enabled" = false;
      "extensions.getAddons.showPane" = false;
      "browser.discovery.enabled" = false;
      # Disable remote suggestions in urlbar
      "browser.urlbar.suggest.trending" = false;
      "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
      "browser.urlbar.suggest.quicksuggest.sponsored" = false;
    };

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      PasswordManagerEnabled = false;
      DontCheckDefaultBrowser = true;
      DisablePocket = true;
      DisableFormHistory = true;
      DNSOverHTTPS = {
        Enabled = true;
        Locked = false;
        ProviderURL = "https://cloudflare-dns.com/dns-query";
      };
      ExtensionSettings = {"*".installation_mode = "allowed";};
    };
  };
}
