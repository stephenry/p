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

module conv_lbx_asic (

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel In                                                                   //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic [4:1]                    push_i
, input wire logic                          pop_i
, input wire conv_pkg::pixel_t              dat_i
, input wire logic                          sof_i
, input wire logic [4:1]                    eol_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel Out                                                                  //
//                                                                            //
// -------------------------------------------------------------------------- //

, output conv_pkg::pixel_t [4:1]            colD_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                          clk
, input wire logic                          arst_n
);

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

logic [1:0][4:1]                       ce;
logic [1:0][4:1]                       rnw;
conv_pkg::pixel_t [1:0][4:1]           dout;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// Bank selection flop.
`D_DFFR(logic, bank_sel, 'b0, clk, arst_n);

// Bank selection is relative to the write port. Bank selection is inverted
// on end-of-line.
assign bank_sel_w = (push_i & eol_i) ? ~bank_sel_r : bank_sel_r;

// End-of-line occurs on the final pixel of the line. Otherwise, on
// Start-of-Frame, reset value of 'b1, as the first slot is set below.
assign addr_w = (sof_i ? 'b1 : (eol_i ? 'b0 : addr_r + 'b1));
assign addr_en = (push_i != '0);

// Start-of-frame is coincident with the first push. The address must
// therefore reset on the cycle cycle.
assign addr = sof_i ? 'b0 : addr;

assign wen = push_i

assign ren = (push_i & pop_i)

// Chip-enable signals for SRAMs.
assign ce[1] = ( bank_sel_r ? (wen | ren) : '0);   // Bank 1
assign ce[0] = (~bank_sel_r ? (wen | ren) : '0);   // Bank 0

// Read-not-write signals for SRAMs.
assign rnw[1] = ( bank_sel_r ? ~wen : '1); // Bank 1
assign rnw[0] = (~bank_sel_r ? ~wen : '1); // Bank 0

`P_DFF(logic, dout_bnk, clk);
assign dout_bnk_w = bank_sel_r;

`P_DFFR(logic [4:1], dout_vld, 1'b0, clk, arst_n);
assign dout_vld_w = ren;

for (genvar i = 1; i < 5; i++) begin: sram_GEN

// Generic ASIC SRAM bank style. Ping-Pong buffer implementation to implement
// dual-ported concurrent read/write functionality.

for (genvar bnk = 0; bnk < 2; bnk++) begin: bank_GEN

generic_sram #(
  .DATA_W        (conv_pkg::PIXEL_W)
, .WORDS_N       (conv_pkg::IMAGE_MAX_W)
) u_generic_sram (
  .ce            (ce[bnk][i])
, .addr          (addr)
, .din           (dat_i)
, .rnw           (rnw[bnk][i])
, .dout          (dout[bnk][i])
);

end: bank_GEN

// Output flops to latch data read from BRAMs. This introduces
// one additional cycle of latency, but is required to avoid
// a BRAM.dout to BRAM.din combinational path between line buffers.

logic                             colD_en;
`P_DFFE(conv_pkg::pixel_t [4:1], colD, colD_en, clk);

assign colD_en = dout_vld;

// Mux data from the appropriate bank based on the bank select flop.
for (genvar i = 1; i < 5; i++) begin: dout_bank_sel_GEN

assign colD_w[i] = (dout_bnk_r[i] ? dout[1][i] : dout[0][i]);

end: dout_bank_sel_GEN

// ========================================================================= //
//                                                                           //
// Ouputs                                                                    //
//                                                                           //
// ========================================================================= //

assign colD_o = colD;

endmodule : conv_lbx_asic

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
