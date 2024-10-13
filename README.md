
# x86_Baesd Text-Mode Missile Command

## Overview

This project is a text-mode implementation of the classic arcade game **Missile Command**, designed to run within the Linux kernel using x86 assembly. The game leverages the Linux **real-time clock (RTC) driver**, allowing players to control missile silos and defend cities from incoming enemy missiles. The game involves kernel-space and user-space components that communicate using IOCTL system calls.

This project provides hands-on experience with:
- x86 assembly programming
- Linux kernel development
- Device drivers
- RTC tasklets

## Project Structure

The project is divided into two primary components:
1. **Kernel-space code**: Manages the state of missiles and performs real-time updates using tasklets triggered by RTC interrupts.
2. **User-space code**: Handles user input, game logic, and renders the display on the text-mode video screen.

## Key Features

- **Missile Management**: Each missile's state (position, velocity, explosion status) is managed in a linked list residing in kernel space.
- **Game Components**: Includes the player's crosshairs, cities, and missiles (both friendly and enemy).
- **Real-Time Clock (RTC)**: The game is driven by RTC interrupts, which trigger tasklets that update the state of the game in real-time.
- **Ioctl Commands**: Several IOCTL commands allow communication between user-space and kernel-space, such as starting the game, moving the crosshairs, and adding missiles.
  
## Getting Started

### Prerequisites

1. **Linux Kernel**: You'll need a Linux kernel (version 2.6.22.5 or compatible) configured and ready to build the RTC driver.
2. **Git**: The project is managed using Git, so make sure you have Git installed.

### Setup

1. Clone the project repository:

2. Apply the provided patch (`mp1.diff`) to your Linux kernel:
   ```bash
   cp mp1.diff /workdir/source/linux-2.6.22.5
   cd /workdir/source/linux-2.6.22.5
   cat mp1.diff | patch -p1
   ```
3. Compile the kernel with the applied patch:
   ```bash
   cd ~/build
   make
   ```

### Running the Game

1. After compiling and booting the kernel, run the game from the user-space using the test program:
   ```bash
   cd /workdir/mp1
   make
   su -c ./utest
   ```
   This will launch the user-space test program, allowing you to test the game's functionality.

### Testing in Kernel Space

Once you're confident in the functionality, copy the assembly file to your kernel source directory:
```bash
cp /workdir/mp1/mp1.S /workdir/source/linux-2.6.22.5/drivers/char
```
Rebuild the kernel and test the code in kernel space using:
```bash
su -c ./ktest
```

## Ioctl Commands

The following IOCTL commands are supported:

- **Start Game (0)**: Initializes game variables and begins the game.
- **Add Missile (1)**: Adds a missile to the game based on the user’s input.
- **Move Crosshairs (2)**: Moves the player's crosshairs to a new position.
- **Get Status (3)**: Retrieves the current score and city statuses.
- **End Game (4)**: Cleans up and ends the game.

## Data Structures

- **struct missile**: Stores data related to each missile, including its position, velocity, explosion status, and the character to render on screen.
- **Linked List**: Manages active missiles using a pointer to the next missile in the list.

## Compilation & Debugging

### User-Space Test Harness
To test the functionality of your code outside the kernel, use the provided user-level test harness:
```bash
make
su -c ./utest
```
### Kernel-Space Testing
When testing inside the kernel, use the `ktest` program to verify the behavior:
```bash
su -c ./ktest
```

### Debugging Tips

- Use `gdb` to debug the user-space test harness:
   ```bash
   su -c "gdb utest"
   ```
- For kernel-space debugging, use the `disas` command to disassemble functions like `mp1_rtc_tasklet` or `mp1_ioctl`.