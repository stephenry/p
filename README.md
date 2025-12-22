# P - Hardware Verification Framework

A hardware verification framework for SystemVerilog RTL designs using Verilator-based simulation and C++ testbenches.

## Overview

This project provides a CMake-based build system for developing and testing hardware designs written in SystemVerilog. It uses Verilator to convert SystemVerilog RTL into C++ models, which are then verified using C++ testbenches.

### Current Projects

- **conv**: A convolution operation module for streaming data processing
  - Supports multiple configurations (ASIC/FPGA targets, zero-padding strategies)
  - Implements kernel-based convolution on pixel streams

## Prerequisites

### Required Dependencies

- **CMake** (>= 3.22)
- **Verilator**: Hardware simulation tool
  - Set `VERILATOR_ROOT` environment variable to your Verilator installation
- **Python 3**: For RTL compilation scripts
- **C++ Compiler**: Supporting C++20 standard
- **PyYAML**: Python package (automatically installed in virtual environment)

### Environment Setup

Export the Verilator installation path:

```bash
export VERILATOR_ROOT=/path/to/verilator
```

## Building the Project

### Configure

```bash
mkdir build
cd build
cmake ..
```

This will:
- Detect Verilator installation
- Create a Python virtual environment in `build/.venv`
- Install required Python dependencies (PyYAML)

### Build

```bash
cmake --build .
```

The build process:
1. Renders RTL from SystemVerilog sources using Python scripts
2. Runs Verilator to generate C++ models from SystemVerilog
3. Compiles C++ testbenches and links them with Verilated models

### Options

- **VCD Tracing**: Enable waveform generation
  ```bash
  cmake -DOPT_VCD_ENABLE=ON ..
  ```

## Running Tests

After building, run the test suite:

```bash
ctest
```

Or run tests with verbose output:

```bash
ctest --verbose
```

Run specific test executables directly:

```bash
./test/main
```

## Project Structure

```
.
├── CMakeLists.txt          # Top-level build configuration
├── cmake/                  # CMake modules
│   ├── FindVerilatorPkg.cmake  # Verilator detection and setup
│   └── SetupVenv.cmake         # Python virtual environment setup
├── projects/               # Hardware projects
│   ├── common/            # Common/shared RTL components
│   └── conv/              # Convolution module
│       ├── rtl/           # SystemVerilog source files
│       ├── tb.cc          # C++ testbench
│       └── CMakeLists.txt # Project build configuration
├── py/                    # Python RTL compilation tools
│   ├── rtl.py            # RTL processing and Verilator invocation
│   ├── compile.py.in     # RTL compilation entry point
│   └── requirements.txt  # Python dependencies
├── tb/                    # Testbench library
│   ├── include/tb/       # C++ testbench headers
│   ├── src/              # C++ testbench implementation
│   └── sv/               # SystemVerilog testbench components
└── test/                  # Test driver
    └── main.cc           # Test entry point
```

## Adding New Projects

To add a new hardware project:

1. Create a project directory under `projects/`
2. Add RTL sources in a `rtl/` subdirectory
3. Create a YAML configuration file (e.g., `project.yaml.in`) specifying:
   - Top module name
   - Source file list
   - Include dependencies
   - Preprocessor defines
4. Create a C++ testbench (`tb.cc`)
5. Add a `CMakeLists.txt` using the `generate_project()` macro:

```cmake
generate_project(
    NAME my_project
    YAML_IN ${CMAKE_CURRENT_SOURCE_DIR}/config.yaml.in
    CC_SRCS ${CMAKE_CURRENT_SOURCE_DIR}/tb.cc
)
```

## YAML Configuration

Project YAML files define the RTL compilation parameters:

```yaml
# Top-level module name for Verilator
top: my_top_module

# SystemVerilog source files
sources:
    - path/to/source1.sv
    - path/to/source2.sv

# Include other YAML configurations
include:
    - path/to/common.yaml

# Preprocessor defines
defines:
    MY_DEFINE: value
```

## License

BSD 2-Clause License. See file headers for full license text.

Copyright (c) 2025, Stephen Henry

