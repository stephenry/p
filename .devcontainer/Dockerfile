ARG VARIANT="jammy"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}
RUN apt-get update \
  && DEBIAN_FRONTEND=noninterative \
    apt-get install --no-install-recommends -y \
      autoconf \
      bc \
      bison \
      build-essential \
      default-jre \
      flex \
      lcov \
      libfl-dev \
      libgoogle-perftools-dev \
      help2man \
      pkg-config \
      gdb \
      cmake \
      python3-dev \
      python3-orderedmultidict \
      python3-pip \
      python3-psutil \
      python3-venv \
      clangd-14 \
      clang-tidy-14 \
      clang-format-14 \
      tclsh \
      swig \
      uuid-dev \
      zlib1g-dev \
      emacs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Build ABC
WORKDIR /tools
RUN git clone https://github.com/berkeley-abc/abc.git \
 && cd abc \
 && make -j8

ENV ABC_ROOT=/tools/abc

# Build VerilogPerl
cpan install Verilog::Language

# Build Verilator
ARG VERILATOR_VER="5.034"
WORKDIR /tools
RUN wget https://github.com/verilator/verilator/archive/refs/tags/v${VERILATOR_VER}.tar.gz \
  && tar -zxf v${VERILATOR_VER}.tar.gz \
  && cd verilator-${VERILATOR_VER} \
  && autoconf \
  && ./configure \
  && make \
  && cd .. \
  && rm -rf v${VERILATOR_VER}.tar.gz

# Required for the build system.
ENV VERILATOR_ROOT="/tools/verilator-${VERILATOR_VER}"
