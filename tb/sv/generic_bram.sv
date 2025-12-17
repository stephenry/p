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

// Behavioural model of a generic/typical FPGA BRAM module.
//
// Notable characteristics:
//
//  - The ability to retain state at DOUT.
//
//  - Aspect ratio relaxations; no requirement on minimum word count or
//    word width.
//
//  - When configured for dual-port operation, memory supports 
//    simultaneous read and write operations. Collisions are resolved
//    by prioritizing the write operation.

module generic_bram #(
// Word width in bits
  parameter int WORD_W

// Word count.
, parameter int WORDS_N = 256

// Output is latched at dout in the absence of subsequent read operations.
// State is otherwise discarded in the next cycle. When latched, dout
// is clobbered on a subsequent write operation.
, parameter bit HOLD_DOUT = 1'b0

, localparam int ADDR_W = $clog2(WORDS_N)
) (

// Port A

  input wire logic                           cea
, input wire logic [ADDR_W - 1:0]            addra
, input wire logic [WORD_W - 1:0]            dina
, input wire logic                           rnwa

, output wire logic [WORD_W - 1:0]           douta

// Port B

, input wire logic                           ceb
, input wire logic [ADDR_W - 1:0]            addrb
, input wire logic [WORD_W - 1:0]            dinb
, input wire logic                           rnwb

, output wire logic [WORD_W - 1:0]           doutb
);

endmodule : generic_bram
