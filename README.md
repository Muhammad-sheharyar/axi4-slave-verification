# AXI4-Full Slave Verification (WRAP + FIXED)

SystemVerilog layered testbench for verifying an AXI4-Full slave supporting FIXED and WRAP burst modes, following the AMBA AXI4 specification (ARM IHI 0022E).

## Project Overview

- **DUT:** AXI4-Full Slave (128-byte memory, 32-bit data bus, 4-bit ID)
- **Verification:** UVM-style layered testbench (Transaction, Generator, Driver, Monitor, Scoreboard, Environment)
- **Simulator:** Synopsys VCS L-2016.06
- **Waveform:** GTKWave

## Features Verified

- FIXED and WRAP burst types
- Burst lengths: 2, 4, 8, 16 beats
- Burst sizes: 1, 2, 4 bytes/beat
- AW/W/B handshake protocol
- Memory content verification (byte-by-byte scoreboarding)
- Read-back verification (AR/R channels)
- Functional coverage (100% on burst type × length × size cross)

## Files

| File | Role |
|---|---|
| `axi_slave.sv` | DUT (AXI4-Full Slave) |
| `interface.sv` | AXI4 interface with clocking blocks |
| `transaction.sv` | Write transaction class |
| `generator.sv` | Randomized stimulus generator |
| `driver.sv` | Pin-level driver (AW/W/B) |
| `monitor.sv` | Protocol monitor + functional coverage |
| `scoreboard.sv` | Reference model + memory comparison |
| `environment.sv` | Orchestration + read-back check |
| `test.sv` | Top-level test |
| `testbench_top.sv` | Top module |

## Results

- **20+ randomized transactions** — all pass
- **128/128 memory bytes** verified (write + read-back)
- **100% functional coverage**
- **11 DUT bugs** found and fixed (documented in report)

## How to Run

```bash
vcs -sverilog testbench_top.sv axi_slave.sv -full64 -debug_all
./simv

```

## Layered Testbench Architecture

![Layered Testbench](LayerTest_Bench)

## AXI4 Slave Block Diagram

![AXI4 Slave](images/axi_slave_block.png)
