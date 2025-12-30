# Project - "P"

Project "P" aka "99 Projects but a job ain't one" aka "99 Projects but a boss ain't one" aka "Steve, you've really got too much time on your hands!"

## Synopsis

Contained herein is a collection of small (but complex) hardware design challenges. Small enough to be completed in a few days, but complex enough to be challenging. There's no overarching theme, they're simply small problems specifically designed to challenge my design skills. Simulation is performed using Verilator and the verification environment is written as pseudo-UVM C++20. I have made no attempt to synthesize these designs to any particularly target or technology as I lack the tools to hand. The longterm goal of the repo. is to grow the number of projects over time.

# Projects

## Conv 

The [Conv](./projects/conv) project presents a SystemVerilog implementation of a 5x5 convolution filter for an arbitrary sized image. Notable aspects of the project include: 

- Frame dimensions are not hardcoded into logic and are instead derived from an AXI-Stream style interface. The definition of the interface made calculation of the relative position within the frame, required to compute appropriate masking, non-trivial to calculate.
- Support for backpressure across the datapath. A tricky addition which required thought when tracking position in the frame.
- FPGA and ASIC targeted Line Buffer implementations. FPGA targets allow flexible narrow (8b) BRAM that may hold state at dout on stalls, whereas typical ASIC SRAM macro require additional alignment and skid buffer logic. In the context of an ASIC, Line Buffers would typically be realized using flops, but an SRAM implemenation (although overkill) is more complex to implementation, which is the objective of this exercise.
- RTL is standardized on an ASIC-style asynchronous, active-low reset strategy. FPGA implementations however typically prefer synchronous resets. The RTL is trivial to modified as necessary, but I have not done so.

## Seqgen

The [Seqgen](./projects/seqgen) project implements a well-known control-oriented interview question. The problem is to generate a known sequence across a 2D array for variable-sizes of array. The chosen solution uses a [ucode-style](./projects/seqgen/rtl/seqgen_cntrl_case.sv) control unit for optimal PPA. Additionally, a [PLA-based](./projects/seqgen/rtl/seqgen_cntrl_pla.sv) uses the ABC Synthesis tool is used to render a Espresso-style PLA table to random-logic. This code is injected using a preprocessing stage before Verilation. A [standard FSM](./projects/seqgen/rtl/seqgen_cntrl_fsm.sv) implementation is presented, too. Such extreme lengths (PLA-style) are unnecessary for such a small, design. Nevertheless, it's quite an interesting, non-trivial approach, and, I've got too much time on my hands.

## Notable Aspects

### Scripted Verilation

Projects are defined by YAML files which are consumed by a front-end script to render and compile all Verilog sources. When combined with the C++20 based verification environment, rudimentary design parameterization can be achieved without the need for a full-blown Verilog preprocessor.

### Embedded PLA

The open-source ABC Synthesis tool is used to convert embedded PLA blocks into SystemVerilog expressions. This allows complex look-up table and control logic to be written in an optimal and X-prop efficient manner.

### C++20 Verification Environment

Verilator does not have the ability to simulate UVM therefore a pseudo-UVM like environment has been written in C++20. Individual Verilated sources are compiled to static libraries and linked to the verification runtime. The overall project is styled as a standard, modern C++ project with generated sources from Verilator. Some Python is used to performed preprocessing and project management.

## Usage

The environment has been specifically designed to operate within the provided [container](./.devcontainer/Dockerfile). All necessary tools (at fixed versions) are provided and configuration scripts are designs to search known locations in the filesystem for appropriate tools. The work/project is not designed for general consumption so no detailed instructions are provided.

## License

BSD 2-Clause License. See file headers for full license text.

Copyright (c) 2025, Stephen Henry



## License

BSD 2-Clause License. See file headers for full license text.

Copyright (c) 2025, Stephen Henry

