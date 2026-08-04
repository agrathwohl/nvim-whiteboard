{
  description = "nvim-whiteboard - A diagramming plugin for Neovim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      nixvimModule = { config, lib, pkgs, ... }:
        let
          cfg = config.plugins.whiteboard;
        in
        {
          options.plugins.whiteboard = {
            enable = lib.mkEnableOption "nvim-whiteboard";

            settings = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = "Options passed to require('whiteboard').setup().";
            };

            keymap = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "<leader>wb";
              description = "Key that opens a whiteboard. Set to null to bind nothing.";
            };
          };

          config = lib.mkIf cfg.enable {
            extraPlugins = [ self.packages.${pkgs.system}.default ];

            extraConfigLua = ''
              require('whiteboard').setup(${lib.generators.toLua { } cfg.settings})
            '';

            keymaps = lib.optional (cfg.keymap != null) {
              mode = "n";
              key = cfg.keymap;
              action = "<cmd>Whiteboard<cr>";
              options.desc = "Open whiteboard";
            };
          };
        };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.vimUtils.buildVimPlugin {
          pname = "nvim-whiteboard";
          version = "0.2.0";
          src = ./.;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            lua-language-server
            stylua
            luajit
          ];
        };
      }) // {
      nixvimModules.default = nixvimModule;
    };
}
