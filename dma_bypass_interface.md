# PCIe Bypass BAR Memory Map

## Overview
This document describes the memory map for the 512MB PCIe Bypass BAR used in the accelerator.

## Memory Regions

| Region Name           | Start Address  | End Address    | Size       | Description                                |
|-----------------------|----------------|----------------|-----------|--------------------------------------------|
| Weights               | 0x00000000     | 0x06400000     | 100MB      | Neural network weights storage              |
| Reserved Region 1     | 0x06400000     | 0x0C800000     | 100MB      | Reserved for future use                     |
| Biases                | 0x0C800000     | 0x0FA00000     | 50MB       | Neural network biases storage               |
| Reserved Region 2     | 0x0FA00000     | 0x1FFF7FFF     | ~261MB     | Reserved for future use                     |
| Header Buffer         | 0x1FFF8000     | 0x1FFF87FF     | 2KB        | Configuration registers for neural network operations |
| Reserved Region 3     | 0x1FFF8800     | 0x1FFFFFFF     | ~30KB      | Reserved for future use                     |

## Header Buffer Register Map

The Header Buffer region contains 128 configuration registers. Each register is 72 bits (9 bytes) wide but is mapped to a 16-byte aligned address space for efficient addressing.

| Register          | Address Range          | Description                   |
|-------------------|------------------------|-------------------------------|
| Register 0        | 0x1FFF8000 - 0x1FFF800F | Configuration register 0      |
| Register 1        | 0x1FFF8010 - 0x1FFF801F | Configuration register 1      |
| Register 2        | 0x1FFF8020 - 0x1FFF802F | Configuration register 2      |
| ...               | ...                    | ...                           |
| Register 127      | 0x1FFF87F0 - 0x1FFF87FF | Configuration register 127    |

## Header Buffer Register Format

Each 72-bit register has the following format:

| Bits    | Field              | Description                                       |
|---------|-------------------|---------------------------------------------------|
| 7:0     | XZP[7:0]           | X zero point value                                |
| 15:8    | YZP[7:0]           | Y zero point value                                |
| 31:16   | M[15:0]            | Scale factor (Xs*Ws/Ys)                           |
| 47:32   | N[15:0]            | Number of 32-byte vectors in each input tile, minus one |
| 55:48   | K[7:0]             | Number of weights tiles, minus one                 |
| 65:56   | J[9:0]             | Number of input tiles, minus one                   |

## Software Access Guidelines

When accessing the Header Buffer registers:

1. **Alignment**: All register accesses must be aligned to 16-byte boundaries.
2. **Register Access**:
   - Full register write: Write all 9 bytes at once to the register's base address
   - Byte-by-byte write: Write individual bytes at offsets 0-8 from the register's base address
3. **Register Indexing**:
   - Register N is located at: 0x1FFF8000 + (N × 16)

Note: When using system calls like `write()` that operate on a byte level, software should ensure that the correct byte offsets are used within each register's 16-byte block.
