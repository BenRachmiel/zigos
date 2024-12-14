#!/usr/bin/env bash
set -e
rm -rf zig-out zig-cache isofiles os.iso

# Set up the grub-mkrescue alias for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias grub-mkrescue='podman run --rm -v "$PWD":/build:Z zigos-builder grub-mkrescue'
fi

# Build the kernel
zig build || exit 1

# Create ISO directory structure
mkdir -p isofiles/boot/grub

# Create GRUB config
echo 'menuentry "ZigOS" {
    multiboot /boot/kernel.elf
    boot
}' > isofiles/boot/grub/grub.cfg

# Copy kernel to ISO directory
cp zig-out/bin/kernel.elf isofiles/boot/

# Create the ISO
if [[ "$OSTYPE" == "darwin"* ]]; then
    podman run --rm -v "$PWD":/build:Z zigos-builder grub-mkrescue -o os.iso isofiles
else
    grub-mkrescue -o os.iso isofiles
fi

echo "Build complete! Run with: run-os"
