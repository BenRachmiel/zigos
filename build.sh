#!/bin/bash
set -e

# Set up the grub-mkrescue alias for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias grub-mkrescue='podman run --rm -v "$PWD":/build:Z zigos-builder grub-mkrescue'
fi

# Build the kernel
zig build

# Create ISO directory structure
rm -rf isodir
mkdir -p isodir/boot/grub
cp zig-out/bin/kernel.elf isodir/boot/

# Create GRUB config
cat > isodir/boot/grub/grub.cfg << EOF
menuentry "ZigOS" {
    multiboot /boot/kernel.elf
}
EOF

# Create the ISO
if [[ "$OSTYPE" == "darwin"* ]]; then
    podman run --rm -v "$PWD":/build:Z zigos-builder grub-mkrescue -o os.iso isodir
else
    grub-mkrescue -o os.iso isodir
fi

echo "Build complete! Run with: run-os"
