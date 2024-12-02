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
   git clone https://github.com/yourusername/zigos.git
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

### Milestone 1: Basic Boot
- **Goal**: Display "Hello World" on screen
- **Test Criteria**: Text appears in QEMU
- **Skills**:
  - Basic Zig syntax and compilation
  - Multiboot header implementation
  - GRUB bootloader configuration
  - Basic VGA text mode output

### Milestone 2: Screen Output
- **Goal**: Implement comprehensive screen output functions
- **Test Criteria**:
  - Color text display
  - Screen clearing
  - Text scrolling
- **Skills**:
  - VGA buffer manipulation
  - Text mode color attributes
  - Screen driver architecture

### Milestone 3: Keyboard Input
- **Goal**: Handle keyboard input
- **Test Criteria**: Character input display
- **Skills**:
  - Interrupt handling (IRQ1)
  - PS/2 keyboard interface
  - Scancode translation
  - Input buffering

### Milestone 4: Basic Shell
- **Goal**: Implement command prompt
- **Test Criteria**:
  - Command input/output
  - Basic command parsing
- **Skills**:
  - String manipulation in Zig
  - Command parsing
  - Shell architecture

### Milestone 5: Memory Management
- **Goal**: Implement basic memory management
- **Test Criteria**:
  - Successful page allocation/deallocation
  - No memory leaks or crashes
- **Skills**:
  - Page table manipulation
  - Physical/virtual memory mapping
  - Memory allocation algorithms

### Milestone 6: Process Management
- **Goal**: Basic multitasking
- **Test Criteria**:
  - Multiple processes running
  - Context switching
- **Skills**:
  - Task scheduling
  - Context switching
  - Process state management

### Milestone 7: File System
- **Goal**: In-memory file system
- **Test Criteria**:
  - Basic file operations (create/read/write)
  - Directory structure
- **Skills**:
  - File system design
  - Buffer management
  - File operations

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
