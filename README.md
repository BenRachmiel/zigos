# ZigOS - A Simple Operating System in Zig

Welcome to ZigOS! This project is an educational operating system implementation using the Zig programming language. Follow along as we build an operating system from scratch, learning about both Zig and OS development principles along the way.

## 🎯 Project Goals

- Learn Zig programming language fundamentals
- Understand low-level OS concepts through hands-on implementation
- Create a minimal but functional operating system
- Document the learning process for others to follow

## 🛠️ Development Environment

This project uses [Nix Flakes](https://nixos.wiki/wiki/Flakes) to provide a consistent development environment. The development shell includes all necessary tools for OS development, including QEMU for testing, GDB for debugging, and various utilities for binary manipulation.

### Prerequisites

1. Install Nix with flakes enabled:
   ```bash
   # For multi-user installation
   sh <(curl -L https://nixos.org/nix/install) --daemon
   
   # Enable flakes in ~/.config/nix/nix.conf
   experimental-features = nix-command flakes
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/BenRachmiel/zigos.git
   cd zigos
   ```

3. Enter the development environment:
   ```bash
   nix develop
   ```

### Available Development Tools

The development environment provides:

- **Zig Toolchain**
  - `zig`: The Zig compiler and build system
  - `zls`: Zig Language Server for IDE integration

- **OS Development**
  - `qemu`: Virtual machine for testing
  - `grub2`: Bootloader utilities
  - `nasm`: Assembly language compiler
  - `gdb`: GNU debugger

- **Build Tools**
  - `gnumake`: Build automation
  - `binutils`: Binary utilities
  - `xorriso`: ISO creation
  - `hexdump`/`xxd`: Binary file analysis

### Useful Commands

The development shell provides several aliases for common operations:

```bash
run-os    # Run the OS in QEMU
debug-os  # Run with interrupt logging (creates qemu.log)
gdb-os    # Run with GDB server enabled for debugging
```

## 🗺️ Development Roadmap

### Milestone 1: Basic Boot ✓
- [x] Multiboot header implementation
- [x] GRUB bootloader configuration
- [x] Basic VGA text mode output
- [x] "Hello World" display
- Status: **Completed**

### Milestone 2: Screen Output ✓
- [x] VGA buffer manipulation
- [x] Color text display
- [x] Screen clearing
- [x] Text scrolling
- [x] Boot banner display
- Status: **Completed**

### Milestone 3: Keyboard Input ✓
- [x] Interrupt handling (IRQ1)
- [x] PS/2 keyboard interface
- [x] Scancode translation
- [x] Input buffering
- Status: **Completed**

### Milestone 4: Basic Shell
- [x] Command prompt display
- [x] Basic input handling
- [ ] Command parsing system
- [ ] Basic command execution
- [ ] Shell environment setup
- Status: **Partially Complete**

### Milestone 5: Memory Management
#### Phase 1: Foundation
- [x] GDT & Basic Segmentation
  * [x] Review and enhance current GDT
  * [x] Implement proper segment bounds
  * [x] Set up user/kernel separation
  * [x] Add essential TSS support
- [ ] Physical Memory Management
  * [ ] Parse multiboot memory map
  * [ ] Implement frame allocator
  * [ ] Add allocation tracking
- [ ] Debug Infrastructure
  * [ ] Memory state visualization
  * [ ] Basic memory dumps
  * [ ] Allocation tracking tools

#### Phase 2: Virtual Memory
- [ ] Basic Paging Setup
  * [ ] Identity mapping for kernel
  * [ ] 4KB page management
  * [ ] Page table system
  * [ ] Page fault handler
- [ ] Initial Protection
  * [ ] Kernel/user space separation
  * [ ] Write protection
  * [ ] Guard pages

#### Phase 3: Memory Allocation
- [ ] Kernel Heap
  * [ ] Slab allocator
  * [ ] Buddy system
  * [ ] Memory pools
- [ ] User Space Memory
  * [ ] Basic heap management
  * [ ] Allocation tracking

#### Phase 4: Advanced Features
- [ ] Enhanced Protection
  * [ ] Copy-on-write
  * [ ] Memory mapped files
  * [ ] Shared memory regions
- [ ] Optimization
  * [ ] Memory compaction
  * [ ] Pressure handling
- [ ] Advanced Debugging
  * [ ] Leak detection
  * [ ] Use-after-free detection
Status: **In Planning**

### Milestone 6: Process Management
- [ ] Task scheduling
- [ ] Context switching
- [ ] Process creation/destruction
- [ ] Inter-process communication
- [ ] Basic synchronization primitives
Status: **Not Started**

### Milestone 7: File System
- [ ] Virtual File System (VFS) interface
- [ ] In-memory file system
- [ ] Basic file operations
- [ ] Directory structure
- [ ] File descriptors
Status: **Not Started**
## 📝 Development Process

For each milestone:

1. **Implementation**
   - Write the necessary code
   - Follow Zig best practices
   - Keep code modular and well-documented

2. **Testing**
   - Test in QEMU
   - Use GDB for debugging when needed
   - Verify against milestone criteria

3. **Error Handling**
   - Implement comprehensive error cases
   - Add error recovery mechanisms
   - Document error conditions

4. **Documentation**
   - Update README with new features
   - Document key learning points
   - Add code comments for complex sections

5. **Review**
   - Ensure stability before moving forward
   - Refactor if necessary
   - Commit working changes

## 🔍 Debugging Tips

1. Use QEMU's debug features:
   ```bash
   # View interrupt logging
   debug-os
   cat qemu.log
   
   # Connect GDB
   gdb-os
   # In another terminal
   gdb
   (gdb) target remote :1234
   ```

2. Add debug output:
   ```zig
   // Debug print function
   pub fn debugPrint(comptime fmt: []const u8, args: anytype) void {
       // Implementation
   }
   ```

## 📚 Resources

- [Zig Documentation](https://ziglang.org/documentation/master/)
- [OSDev Wiki](https://wiki.osdev.org/)
- [Writing an OS in Rust](https://os.phil-opp.com/) (concepts apply to Zig as well)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)

## 📄 License

This project is licensed under the unlicense - see the LICENSE on GitHub for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
