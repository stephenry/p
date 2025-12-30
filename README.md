# Project - "P"

Project "P" aka "99 Projects but a job ain't one" aka "99 Projects but a boss ain't one" aka "Steve, you've really got too much time on your hands!"

## Synopsis

Contained herein is a collection of small (but complex) hardware design challenges. Small enough to be completed in a few days, but complex enough to be challenging. 

# Projects

## Conv 

The [Conv](./projects/conv) project presents a SystemVerilog implementation of a 5x5 convolution filter for an arbitrary sized image. Notable aspects of the project include: 

- Frame dimensions are not hardcoded into logic and are instead derived from an AXI-Stream style interface. The definition of the interface made calculation of the relative position within the frame, required to compute appropriate masking, non-trivial to calculate.
- Support for backpressure across the datapath. A tricky addition which required thought when tracking position in the frame.
- FPGA and ASIC targeted Line Buffer implementations. FPGA targets allow flexible narrow (8b) BRAM that may hold state at dout on stalls, where as typical ASIC SRAM require additional alignment and skid buffer logic.

## Seqgen

The [Seqgen](./project/seqgen) project implements a well-known control-oriented interview question. The problem is to generate a known sequence across a 2D array for variable-sizes of array. The chosen solution used a ucode-style [control unit](./project/seqgen/rtl/seqgen_cntrl_case.sv) for optimal PPA. Additionally, a [second solution](./project/seqgen/rtl/seqgen_cntrl_pla.sv) uses the ABC Synthesis tool is used to render Espresso-style PLA logic to random-logic. This code is injected using a preprocessing stage before Verilation.

## Notable Aspects

### Scripted Verilation

Projects are defined by YAML files which are consumed by a front-end script to render and compile all Verilog sources. 

### Embedded PLA

The open-source ABC Synthesis tool is used to convert embedded PLA blocks into SystemVerilog expressions. This allows complex look-up table and control logic to be written in an optimal and X-prop efficient manner.


## License

BSD 2-Clause License. See file headers for full license text.

Copyright (c) 2025, Stephen Henry



## License

BSD 2-Clause License. See file headers for full license text.

Copyright (c) 2025, Stephen Henry

