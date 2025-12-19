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
`include "flops.svh"
`include "conv_pkg.svh"

// Generic model to perform a convolution operation on streaming data.

module conv (

// -------------------------------------------------------------------------- //
//                                                                            //
// Input                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                           s_tvalid_i
, input wire conv_pkg::pixel_t               s_tdata_i
, input wire logic                           s_tlast_i
, input wire logic                           s_tuser_i

, output wire logic                          s_tready_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Output                                                                     //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                           m_tready_i
//
, output wire logic                          m_tvalid_o
, output wire conv_pkg::kernel_t             m_tdata_o
, output wire logic                          m_tuser_o
, output wire logic                          m_tlast_o


// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                           clk
, input wire logic                           arst_n
);

// ========================================================================= //
//                                                                           //
// Wire(s)                                                                   //
//                                                                           //
// ========================================================================= //

// kerneling wires:
//
logic [4:0]                                 kernel_colD_push;
conv_pkg::kernel_pos_t                      kernel_colD_pos;
conv_pkg::pixel_t [4:0]                     kernel_colD_data;

logic                                       kernel_vld;
conv_pkg::kernel_t                          kernel_dat;
conv_pkg::kernel_pos_t                      kernel_pos;
conv_pkg::kernel_t                          kernel_dat_masked;

// Output registers:
//
`P_DFFR(logic, m_tvalid, 1'b0, arst_n, clk);

logic                                       m_tdata_en;
`P_DFFE(conv_pkg::kernel_t, m_tdata, m_tdata_en, clk);
`P_DFFE(logic, m_tuser, m_tdata_en, clk);
`P_DFFE(logic, m_tlast, m_tdata_en, clk);

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// ------------------------------------------------------------------------- //
//

conv_cntrl u_conv_cntrl (  
//
  .s_tvalid_i              (s_tvalid_i)
, .s_tdata_i               (s_tdata_i)
, .s_tuser_i               (s_tuser_i)
, .s_tlast_i               (s_tlast_i)
, .s_tready_o              (s_tready_o)
//
, .m_tready_i              (m_tready_i)
, .m_tvalid_o              (m_tvalid_o)
//
, .kernel_colD_push_o      (kernel_colD_push)
, .kernel_colD_pos_o       (kernel_colD_pos)
, .kernel_colD_data_o      (kernel_colD_data)
//
, .clk                     (clk)
, .arst_n                  (arst_n)
);

// ------------------------------------------------------------------------- //
//


conv_kernel u_conv_kernel (
//
  .colD_push_i               (kernel_colD_push)
, .colD_dat_i                (kernel_colD_data)
, .colD_pos_i                (kernel_colD_pos)
//
, .kernel_vld_o              (kernel_vld)
, .kernel_dat_o              (kernel_dat)
, .kernel_pos_o              (kernel_pos)
//
, .clk                       (clk)
, .arst_n                    (arst_n)
);

// ------------------------------------------------------------------------- //
// Combinational mask logic to zero out pixels that are outside the image
// boundaries according to the nominated extension strategy.

conv_mask u_conv_mask (
//
  .kernel_i                 (kernel_dat)
, .kernel_pos_i             (kernel_pos)
//
, .kernel_masked_o          (kernel_dat_masked)
);

// ------------------------------------------------------------------------- //
//
assign m_tvalid_w = kernel_vld;
assign m_tdata_w = kernel_dat_masked;

assign m_tuser_w = 1'b0;
assign m_tlast_w = 1'b0;

// ========================================================================= //
//                                                                           //
// Ouputs                                                                    //
//                                                                           //
// ========================================================================= //

assign m_tvalid_o = m_tvalid_r;
assign m_tdata_o = m_tdata_r;
assign m_tuser_o = m_tuser_r;
assign m_tlast_o = m_tlast_r;

endmodule : conv

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
