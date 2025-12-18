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
`include "conv_pkg.svh"
`include "flops.svh"

module conv_lbx_fpga (

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel In                                                                   //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic [4:1]                    push_i
, input wire conv_pkg::pixel_t              dat_i
, input wire logic                          sof_i
, input wire logic                          eol_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel Out                                                                  //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic [4:1]                    pop_i

, output wire conv_pkg::pixel_t             colD_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                          clk
, input wire logic                          arst_n
);

// On an FPGA implementation, we typically expect reset to be synchronous.
// Polarity is ignored. This environment does not differentiate between
// reset strategies, so we just use the async reset signal for all
// techologies.

// ========================================================================= //
//                                                                           //
// Wire(s)                                                                   //
//                                                                           //
// ========================================================================= //

localparam ADDR_W = $clog2(conv_pkg::IMAGE_MAX_W);
typedef logic [ADDR_W-1:0] addr_t;

logic                                  addr_en;
`D_DFFE(addr_t, addr, addr_en, clk);
addr_t                                 addr;
logic [4:1]                            wen;
logic [4:1]                            ren;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// End-of-line occurs on the final pixel of the line. Otherwise, on
// Start-of-Frame, reset value of 'b1, as the first slot is set below.
assign addr_w = (sof_i ? 'b1 : (eol_i ? 'b0 : addr_r + 'b1));
assign addr_en = (push_i != '0);

// Start-of-frame is coincident with the first push. The address must
// therefore reset on the cycle cycle.
assign addr = sof_i ? 'b0 : addr;

assign wen = push_i

assign ren = (push_i & pop_i)

`P_DFFR(logic [4:1], dout_vld, 1'b0, clk, arst_n);

assign dout_vld_w = ren;

for (genvar i = 1; i < 5; i++) begin : bram_GEN

// FPGA BRAM instance offer true dual-port operation. Additionally,
// they internally resolve read/write collisions without further logic.
// These features are not seen on ASIC SRAM macros, hence the different
// implementations between FPGA and ASIC versions of the line buffer.

generic_bram #(
  .WORD_W           (conv_pkg::PIXEL_W)
, .WORDS_N          (conv_pkg::IMAGE_MAX_W)
, .HOLD_DOUT        (1'b1)
, .COLLISION        ("DEFER_WRITE")
) u_generic_bram (
// Port A: Write
  .cea              (wen[i])
, .addra            (addr)
, .dina             (dat_i)
, .rnwa             (1'b0)
, .douta            (/* UNSUSED */)
// Port B: Read
, .ceb              (ren[i])
, .addrb            (addr)
, .dinb             ('b0)
, .rnwb             (1'b1)
, .doutb            (colD_w[i])
);

// Output flops to latch data read from BRAMs. This introduces
// one additional cycle of latency, but is required to avoid
// a BRAM.dout to BRAM.din combinational path between line buffers.

logic                             colD_en;
`P_DFFE(conv_pkg::pixel_t [4:1], colD, colD_en, clk);
assign colD_en = (dout_vld_r != '0);

assign colD_en = dout_vld;

end : bram_GEN

// ========================================================================= //
//                                                                           //
// Ouputs                                                                    //
//                                                                           //
// ========================================================================= //

assign colD_o = colD;

endmodule : conv_lbx_fpga

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
