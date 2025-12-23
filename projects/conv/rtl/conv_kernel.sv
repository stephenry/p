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

module conv_kernel (

// -------------------------------------------------------------------------- //
//                                                                            //
// Input                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                               colD_vld_i
, input wire logic [4:0]                         colD_push_i
, input conv_pkg::pixel_span_t                   colD_dat_i
, input conv_pkg::kernel_pos_t                   colD_pos_i

// -------------------------------------------------------------------------- //
//                                                                            //
// kernel                                                                     //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire logic                              kernel_vld_o
, output conv_pkg::kernel_t                      kernel_dat_o
, output conv_pkg::kernel_pos_t                  kernel_pos_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                               clk
, input wire logic                               arst_n
);

// ========================================================================= //
//                                                                           //
// Wire(s)                                                                   //
//                                                                           //
// ========================================================================= //

logic                                  dp_stall;

conv_pkg::pixel_t
  [conv_pkg::KERNEL_DIAMETER_N - 1:0]
  [conv_pkg::KERNEL_DIAMETER_N - 1:1]  dp_pixel_row_dat_r;

localparam int DP_POS_N = 2;

conv_pkg::kernel_t                     kernel_dat;

typedef struct packed {
  logic                         vld;
  conv_pkg::kernel_pos_t        pos;
} dp_cntrl_t;

localparam int DP_CNTRL_W = $bits(dp_cntrl_t);

logic                                  dp_cntrl_vld_in;
dp_cntrl_t                             dp_cntrl_in;


logic                                  dp_cntrl_vld_out;
dp_cntrl_t                             dp_cntrl_out;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

assign dp_stall = (colD_push_i == '0);

assign dp_cntrl_vld_in = colD_vld_i;
assign dp_cntrl_in = '{vld: colD_vld_i, pos: colD_pos_i};

// ------------------------------------------------------------------------- //
//
for (genvar n = 0; n < conv_pkg::KERNEL_DIAMETER_N; n++) begin: n_GEN

dp #(
  .W(conv_pkg::PIXEL_W)
, .N(conv_pkg::KERNEL_DIAMETER_N - 1)
) u_dp_pixel_row (
  .vld_i                    (colD_push_i[n])
, .dat_i                    (colD_dat_i[n])  
, .stall_i                  (dp_stall)
//
, .pipe_vld_o               ()
, .pipe_dat_o               (dp_pixel_row_dat_r[n])
//
, .vld_o                    (/* UNUSED */)
, .dat_o                    (/* UNUSED */)
//
, .clk                      (clk)
, .arst_n                   (arst_n)
);

end: n_GEN

dp #(
  .W(DP_CNTRL_W)
, .N(DP_POS_N)
) u_dp_cntrl (
  .vld_i                    (dp_cntrl_vld_in)
, .dat_i                    (dp_cntrl_in)  
, .stall_i                  (dp_stall)
//
, .pipe_vld_o               (/* UNUSED */)
, .pipe_dat_o               (/* UNUSED */)
//
, .vld_o                    (dp_cntrl_vld_out)
, .dat_o                    (dp_cntrl_out)
//
, .clk                      (clk)
, .arst_n                   (arst_n)
);

// ------------------------------------------------------------------------- //
//
for (genvar m = 0; m < conv_pkg::KERNEL_DIAMETER_N; m++) begin: kernel_dat_GEN

assign kernel_dat[m] = { dp_pixel_row_dat_r[m], colD_dat_i[m] };

end: kernel_dat_GEN

// ========================================================================= //
//                                                                           //
// Outputs                                                                   //
//                                                                           //
// ========================================================================= //

assign kernel_vld_o = dp_cntrl_vld_out & dp_cntrl_out.vld;
assign kernel_dat_o = kernel_dat;
assign kernel_pos_o = dp_cntrl_out.pos;

endmodule : conv_kernel

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
