{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      systems,
      treefmt-nix,
      ...
    }:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs (import systems) (
          system:
          f (
            import nixpkgs {
              inherit system;
              config = { };
            }
          )
        );
      treefmtEval = eachSystem (
        pkgs:
        treefmt-nix.lib.evalModule pkgs (_: {
          projectRootFile = "flake.nix";
          programs = {
            deadnix.enable = true;
            mdformat.enable = true;
            nixfmt.enable = true;
            statix.enable = true;
            zig.enable = true;
          };
          settings.global.excludes = [ ".envrc" ];
        })
      );
    in
    {
      devShells = eachSystem (pkgs: {
        default =
          with pkgs;
          mkShell {
            packages = [
              hyperfine
              lldb
              treefmtEval.${stdenv.hostPlatform.system}.config.build.wrapper
              zls
            ]
            ++ lib.optionals stdenv.isLinux [
              gdb
              gf
              perf
              poop
            ];

            nativeBuildInputs = [
              zig
            ];

            shellHook = lib.optionalString stdenv.isDarwin ''
              # https://github.com/ziglang/zig/issues/18998
              unset NIX_CFLAGS_COMPILE
              unset NIX_LDFLAGS
            '';
          };
      });
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);
      checks = eachSystem (pkgs: {
        treefmt = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper;
      });
    };
}
