//========================================================================== //
// Copyright (c) 2025, Stephen Henry
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//========================================================================== //

`include "common_defs.svh"

// Behavioural model of a generic/typical ASIC SRAM module.
//
// Characteristics:
//
//  - Single ported operation.
//
//  - Dout is not retained between cycles.
//
//  - No aspect ration relaxations apply. Expect a minimum bit count
//    of ~10kb to be compilable.

module generic_sram #(
// Word width in bits
  parameter int WORD_W

// Word count.
, parameter int WORDS_N = 256

, localparam int ADDR_W = $clog2(WORDS_N)
) (
  input wire logic                           ce
, input wire logic [ADDR_W - 1:0]            addr
, input wire logic [WORD_W - 1:0]            din
, input wire logic                           rnw

, output wire logic [WORD_W - 1:0]           dout

, input wire logic                           clk
);

logic [WORD_W - 1:0] mem [0:WORDS_N - 1];

logic                scrambled_dout_update_r;
logic [WORD_W - 1:0] scrambled_dout_r;

// Write update process.
always_ff @(posedge clk) begin: write_PROC
  if (ce && ~rnw) begin
    mem[addr] <= din;
  end
end: write_PROC

// Read update process; reads from memory when ce & rnw is asserted.
// Otherwise, returns a scrambled version of the last read data.
always_ff @(posedge clk) begin: read_PROC
  dout <= (ce & rnw) ? mem[addr] : scrambled_dout_r;
end: read_PROC

// Block to scramble dout when not being updated.
always_ff @(posedge clk) begin: scramble_dout_PROC
  scrambled_dout_update_r <= (ce & rnw);
  if (scrambled_dout_update_r) begin
    scrambled_dout_r <= ~dout;
  end
end: scramble_dout_PROC

endmodule : generic_sram
