{
  description = "ZigOS Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Zig development
            zig
            zls # Zig Language Server

            # OS Development tools
            qemu
            xorriso # For creating bootable ISOs
            grub2 # For bootloader
            nasm # For any assembly needs
            gdb # For debugging

            # Build tools
            gnumake
            binutils

            # Helpful utilities
            hexdump # For examining binary files
            xxd # For creating hex dumps
          ];

          # Set up QEMU aliases for easy testing
          shellHook = ''
            # Test OS with QEMU
            alias run-os="qemu-system-i386 -cdrom os.iso"
            
            # Test with debug output
            alias debug-os="qemu-system-i386 -cdrom os.iso -d int -D qemu.log"
            
            # Test with GDB debugging enabled
            alias gdb-os="qemu-system-i386 -cdrom os.iso -s -S"

            echo "ZigOS Development Environment"
            echo "Available commands:"
            echo "  run-os    - Run OS in QEMU"
            echo "  debug-os  - Run OS with interrupt logging"
            echo "  gdb-os    - Run OS with GDB server enabled"
          '';
        };

        # Basic template for new OS projects
        templates.default = {
          path = ./template;
          description = "Basic ZigOS project template";
        };
      });
}
