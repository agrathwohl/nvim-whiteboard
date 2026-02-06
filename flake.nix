{
  description = "nvim-whiteboard - A powerful diagramming plugin for Neovim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = pkgs.vimUtils.buildVimPlugin {
            pname = "nvim-whiteboard";
            version = "0.1.0";
            src = ./.;
          };
        };

        # For nixvim integration
        nixvimModules.default = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.plugins.whiteboard;
          in
          {
            options.plugins.whiteboard = {
              enable = mkEnableOption "Enable nvim-whiteboard plugin";
              
              settings = mkOption {
                type = types.attrs;
                default = {};
                description = "Plugin configuration options";
              };
            };

            config = mkIf cfg.enable {
              extraPlugins = [ self.packages.${pkgs.system}.default ];
              
              extraConfigLua = ''
                require('whiteboard').setup(${pkgs.lib.generators.toLua cfg.settings})
              '';
              
              # Keymaps
              maps.normal = mkMerge [
                (mkIf (cfg.settings.keymaps or {} != {}) {
                  "<leader>wb" = {
                    action = "<cmd>Whiteboard<cr>";
                    desc = "Open Whiteboard";
                  };
                })
              ];
            };
          };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            lua-language-server
            stylua
          ];
        };
      });
}
