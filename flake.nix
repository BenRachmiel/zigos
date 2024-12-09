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
        
        dockerfileContent = ''
          FROM debian:bookworm-slim
          RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
              grub2-common \
              xorriso \
              mtools
          WORKDIR /build
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            zls
            qemu
            nasm
            gnumake
            binutils
            file
            llvm
          ] ++ (if stdenv.isDarwin then [
            podman
          ] else [
            xxd
            elfutils
            grub2
            gdb
            xorriso
            mtools
          ]);

          shellHook = ''
            ${if pkgs.stdenv.isDarwin then ''
              echo "Initializing podman machine..."
              podman machine init || true
              podman machine start || true
              
              if ! command -v grub-mkrescue &> /dev/null; then
                echo "Setting up build container..."
                if ! podman image exists zigos-builder; then
                  echo "${dockerfileContent}" > Dockerfile
                  podman build -t zigos-builder .
                fi
                alias grub-mkrescue='podman run --rm -v "$PWD":/build:Z zigos-builder grub-mkrescue'
              fi
              alias run-os="qemu-system-i386 -cdrom os.iso -device VGA,xres=1280,yres=800 -display cocoa,zoom-to-fit=on"
              alias run-os-debug="qemu-system-i386 -kernel zig-out/bin/kernel.elf -d guest_errors,int -D qemu.log -no-reboot -no-shutdown -device VGA,xres=1280,yres=800 -display cocoa,zoom-to-fit=on"
            '' else ''
              alias run-os="qemu-system-i386 -cdrom os.iso"
              alias run-os-debug="qemu-system-i386 -kernel zig-out/bin/kernel.elf -d guest_errors,int -D qemu.log -no-reboot -no-shutdown"
            ''}
            
            echo "ZigOS Development Environment"
            echo "Available commands:"
            echo "  run-os        - Run OS in QEMU"
            echo "  run-os-debug  - Run with debug output"
          '';
        };
      });
}
