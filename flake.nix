{
  description = "Soft pair editing for Neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        plugin = pkgs.vimUtils.buildVimPlugin {
          pname = "softpair.nvim";
          version = "0.1.0";
          src = self;
          meta = {
            description = "Soft pair editing for Neovim";
            homepage = "https://github.com/so-vanilla/softpair.nvim";
            license = pkgs.lib.licenses.gpl3Plus;
          };
        };
      in
      {
        packages = {
          default = plugin;
          softpair-nvim = plugin;
        };

        checks = {
          default =
            pkgs.runCommand "softpair.nvim-check"
              {
                nativeBuildInputs = with pkgs; [
                  neovim
                  stylua
                ];
              }
              ''
                    cp -r ${self} source
                    chmod -R u+w source
                    cd source
                    export HOME="$TMPDIR"
                stylua --check lua plugin tests
                    nvim --headless -u tests/minimal_init.lua -c "lua require('softpair.tests').run()" -c "qa!"
                    touch "$out"
              '';

          package = plugin;
        };

        formatter = pkgs.nixfmt-tree;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            devenv
            git
            lua-language-server
            neovim
            nixd
            nixfmt
            stylua
          ];
        };
      }
    );
}
