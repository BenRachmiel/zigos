rm -rf zig-out zig-cache isofiles os.iso

zig build || exit 1

mkdir -p isofiles/boot/grub

echo 'menuentry "ZigOS" {
    multiboot /boot/kernel.elf
    boot
}' > isofiles/boot/grub/grub.cfg

cp zig-out/bin/kernel.elf isofiles/boot/

grub-mkrescue -o os.iso isofiles

echo "Build complete! Run with: run-os"
