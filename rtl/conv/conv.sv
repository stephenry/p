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

// Controller:
logic                                       cntrl_intf_vld;
logic                                       cntrl_intf_sof;
logic                                       cntrl_intf_eol;
conv_pkg::pixel_t                           cntrl_intf_dat;

// Stall:
logic                                       stall;

// Line Buffer wires:
logic [conv_pkg::KERNEL_DIAMETER_N - 1:0]   lb_vld;
conv_pkg::pixel_t
  [conv_pkg::KERNEL_DIAMETER_N - 1:0]       lb_dat;

// kerneling wires:
//
logic                                       col0_push;
logic [conv_pkg::KERNEL_DIAMETER_N - 1:0]   col0_vld;
conv_pkg::pixel_span_t                      col0_data;
conv_pkg::kernel_pos_t                      col0_pos;


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
assign stall = m_tvalid_r & ~m_tready_i;

// ------------------------------------------------------------------------- //
//


// ------------------------------------------------------------------------- //
//

// As per. problem definition, tuser is defined as Start-Of-Frame (SOF),
// tlast is defined as End-Of-Line (EOL).
//
assign cntrl_intf_vld = s_tvalid_i;
assign cntrl_intf_sof = s_tuser_i;
assign cntrl_intf_eol = s_tlast_i;
assign cntrl_intf_dat = s_tdata_i;

conv_cntrl u_conv_cntrl (  
//
  .intf_vld_i              (cntrl_intf_vld)
  .intf_sof_i              (cntrl_intf_sof)
, .intf_eol_i              (cntrl_intf_eol)
, .intf_dat_i              (cntrl_intf_dat)
//
, .pos_vld_o               ()
, .pos_o                   ()
//
, .lbx_nl_o                ()
, .lbx_we_o                ()
, .lbx_re_o                ()
, .lb0_dat_o               (lb_dat[0])
//
, .clk                     (clk)
, .arst_n                  (arst_n)
);

for (genvar i = 1; i < conv_pkg::KERNEL_DIAMETER_N; i++) begin : conv_lb_GEN

conv_lbx u_conv_lbx (
//
  .pixel_vld_i             ()
, .pixel_dat_i             ()
, .pixel_eol_i             ()
//
, .pixel_vld_o             (lbx_vld[i])
, .pixel_dat_o             (lbx_dat[i])
//
, .stall_i                 (stall)
//
, .clk                     (clk)
, .arst_n                  (arst_n)
);

end : conv_lb_GEN

conv_lb0 u_conv_lb0 (
//
  .pixel_vld_i             ()
, .pixel_dat_i             ()
, .pixel_eol_i             ()
//
, .pixel_vld_o             (lb_vld[0])
, .pixel_dat_o             (lb_dat[0])
//
, .stall_i                 (stall)
//
, .clk                     (clk)
, .arst_n                  (arst_n)
);

// ------------------------------------------------------------------------- //
//

assign col0_push = 'b0;
assign col0_vld = {lbx_vld, lb0_vld};
assign col0_data = {lbx_dat, lb0_dat};
assign col0_pos = '0;

conv_kernel u_conv_kernel (
//
  .col_push_i                (col0_push)
, .col_vld_i                 (col0_vld)
, .col_dat_i                 (col0_data)
, .col_pos_i                 (col0_pos)
//
, .kernel_vld_o              ()
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

assign s_tready_o = ~stall;

endmodule : conv

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
