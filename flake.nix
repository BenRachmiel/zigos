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
            zig
            zls
            qemu
            xorriso
            grub2
            nasm
            gdb
            gnumake
            binutils
            hexdump
            xxd
            file
            elfutils 
          ];

          shellHook = ''
            # Existing aliases
            alias run-os="qemu-system-i386 -cdrom os.iso"
            
            # Enhanced debug commands
            alias run-os-debug="qemu-system-i386 -kernel zig-out/bin/kernel.elf -d guest_errors,int -D qemu.log -no-reboot -no-shutdown"
            alias dump-header="readelf -x .multiboot zig-out/bin/kernel.elf"
            alias check-sections="readelf -S zig-out/bin/kernel.elf"

            echo "ZigOS Development Environment"
            echo "Available commands:"
            echo "  run-os           - Run OS in QEMU with GRUB"
            echo "  run-os-debug     - Run kernel directly with debug output"
            echo "  dump-header      - Show multiboot header contents"
            echo "  check-sections   - Show ELF section information"
          '';
        };
      });
}
