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

`include "asserts.svh"
`include "common_defs.svh"
`include "conv_pkg.svh"
`include "flops.svh"
`include "cfg_pkg.svh"
`include "tb_pkg.svh"

module conv_cntrl (

// -------------------------------------------------------------------------- //
//                                                                            //
// Control                                                                    //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                          s_tvalid_i
, input wire conv_pkg::pixel_t              s_tdata_i
, input wire logic                          s_tuser_i
, input wire logic                          s_tlast_i

, output wire logic                         s_tready_o

, input wire logic                          m_tready_i

, output wire logic                         kernel_colD_vld_o
, output wire logic [4:0]                   kernel_colD_push_o
, output conv_pkg::kernel_pos_t             kernel_colD_pos_o
, output conv_pkg::pixel_t [4:0]            kernel_colD_data_o

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

typedef struct packed {
  logic                 sof;
  logic                 eol;
} col_pos_t;

localparam int COL_POS_W = $bits(col_pos_t);

// Interface Delay Pipeline
logic                        pixel_pipe_0_vld;
col_pos_t                    pixel_pipe_0_pos;
conv_pkg::pixel_t            pixel_pipe_0_dat;

logic [4:1]                  pixel_pipe_vld_r;
col_pos_t [4:1]              pixel_pipe_r;
conv_pkg::pixel_t            pixel_pipe_N_dat_r;

logic                        pixel0_vld_r;
conv_pkg::kernel_pos_t       pixel0_pos_r;
conv_pkg::pixel_t            pixel0_data_r;

logic                        pos_w2;
logic                        pos_w1;
logic                        pos_e2;
logic                        pos_e1;

logic                        pos_n2;
logic                        pos_n1;
logic                        pos_s2;
logic                        pos_s1;

logic                        cntrl_stall;

logic                        bank_push_sel_en;
logic [4:0]                  bank_push_sel_r;
logic [4:0]                  bank_push_sel_w;

logic                        row_pos_en;
logic [3:0]                  row_pos_r;
logic [3:0]                  row_pos_w;
logic [4:0]                  row_vld_r;
logic [4:0]                  row_vld_w;

// Line Buffer Control
logic [4:0]                  lb_push;
logic [4:0]                  lb_pop;
conv_pkg::pixel_t            lb_dat;
logic                        lb_sol;
logic                        lb_eol;
conv_pkg::pixel_t [4:0]      lb_colD;

typedef struct packed {
  logic [4:0]                pop;
  logic [4:0]                push;
  conv_pkg::pixel_t          dat;
  conv_pkg::kernel_pos_t     pos;
  logic [4:0]                row_vld;
} egress_pipe_t;
localparam int EGRESS_PIPE_W = $bits(egress_pipe_t);

logic                        egress_pipe_in_vld;
egress_pipe_t                egress_pipe_in;

logic                        egress_pipe_out_vld_r;
egress_pipe_t                egress_pipe_out_r;

logic                        kernel_colD_vld_pre;
logic                        kernel_colD_vld;
logic [4:0]                  kernel_colD_push;
conv_pkg::kernel_pos_t       kernel_colD_pos;
conv_pkg::pixel_t [4:0]      kernel_colD_data;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// ------------------------------------------------------------------------- //
// Stall computation.
//
// The core datapath cannot tolerate pipeline bubbles because all pipeline
// stages must be occupied to determin current pixel position in the frame.
// All pipeline stages must be valid. Design maintains support for
// back-pressure from downstream modules. But, for correct operation,
// core micro-architecture expects a continuous stream of valid data pumping
// pixels through the convolution engine.

assign cntrl_stall = (~s_tvalid_i | ~m_tready_i);

// Similarly, datapath as no capability to absorb back-pressure. So
// it is simply reflected upstream.
assign s_tready_o = m_tready_i;

// ------------------------------------------------------------------------- //
// Pixel position and data delay pipeline.

assign pixel_pipe_0_vld = s_tvalid_i;
assign pixel_pipe_0_pos = '{ sof: s_tuser_i, eol: s_tlast_i }; 
assign pixel_pipe_0_dat = s_tdata_i;

dp #(.W(COL_POS_W), .N(4)) u_dp_col (
  .vld_i                   (pixel_pipe_0_vld)
, .dat_i                   (pixel_pipe_0_pos)
, .stall_i                 (cntrl_stall)
, .pipe_vld_o              (pixel_pipe_vld_r)
, .pipe_dat_o              (pixel_pipe_r)
, .vld_o                   (/* UNUSED */)
, .dat_o                   (/* UNUSED */)
, .clk                     (clk)
, .arst_n                  (arst_n)
);

// Pixel delay pipeline to align with Pixel 0 position.
//
dp #(.W(conv_pkg::PIXEL_W), .N(2)) u_dp_pixel (
  .vld_i                   (pixel_pipe_0_vld)
, .dat_i                   (pixel_pipe_0_dat)
, .stall_i                 (cntrl_stall)
, .pipe_vld_o              (/* UNUSED */)
, .pipe_dat_o              (/* UNUSED */)
, .vld_o                   (/* UNUSED */)
, .dat_o                   (pixel_pipe_N_dat_r)
, .clk                     (clk)
, .arst_n                  (arst_n)
);

// ------------------------------------------------------------------------- //
// Column position determination.
//
//  0: Ingress
//
//  1: Pixel +1
//
//  2: Pixel  0 (Determination Stage)
//
//     W2 iff: [Pixel  0 SOF] or [Pixel -1 EOL]
//
//     W1 iff: [Pixel -1 SOF] or [Pixel -2 EOL]
//
//     E1 iff: [Pixel +1 EOL]
//
//     E2 iff: [Pixel  0 EOL]
//
//  3: Pixel -1
//
//  4: Pixel -2
//
// (Qualified on line validity)

assign pos_w2 =
    pixel_pipe_r[2].sof
  | (pixel_pipe_vld_r[3] & pixel_pipe_r[3].eol);

assign pos_w1 = 
    (pixel_pipe_vld_r[3] & pixel_pipe_r[3].sof)
  | (pixel_pipe_vld_r[4] & pixel_pipe_r[4].eol);

assign pos_e1 = pixel_pipe_r[1].eol;
assign pos_e2 = pixel_pipe_r[2].eol;

// ------------------------------------------------------------------------- //
// Row position determination.
//
//  0: Line -2
//
//  1: Line -1
//
//  2: Line 0 (Determination Stage)
//
//    N2 iff: [Line  0 SOF]
//
//    N1 iff: [Line -1 SOF]
//
//    S1 iff: [Line +2 SOF]
//
//    S2 iff: [Line +1 SOF]
//
//  3: Line +1
//
//  4: Line +2
//
assign pos_n2 = row_vld_r[2] & row_pos_r[2];
assign pos_n1 = row_vld_r[2] & row_pos_r[3] & row_vld_r[3];
assign pos_s1 = row_vld_r[2] & row_pos_r[0] & row_vld_r[0];
assign pos_s2 = row_vld_r[2] & row_pos_r[1] & row_vld_r[1];

// ------------------------------------------------------------------------- //
//

localparam logic [3:0] ROW_POS_INIT = 4'b0000;
dffre #(.W(4), .INIT(ROW_POS_INIT)) u_dffr_row_pos (
  .d(row_pos_w), .q(row_pos_r), .en(row_pos_en), .arst_n(arst_n), .clk(clk));

localparam logic [4:0] ROW_VLD_INIT = 5'b00000;
dffre #(.W(5), .INIT(ROW_VLD_INIT)) u_dffr_row_vld (
  .d(row_vld_w), .q(row_vld_r), .en(row_pos_en), .arst_n(arst_n), .clk(clk));

assign row_pos_en = 
    pixel_pipe_vld_r[1]
  & (~cntrl_stall)
  & (pixel_pipe_r[2].eol | pixel_pipe_r[1].sof);

assign row_pos_w = {row_pos_r[2:0], pixel_pipe_r[1].sof};
assign row_vld_w = {row_vld_r[3:0], 1'b1};

// ------------------------------------------------------------------------- //
// Pixel 0 registers.

assign pixel0_vld_r = pixel_pipe_vld_r[2];

assign pixel0_pos_r = '{
  w2: pos_w2, w1: pos_w1, e1: pos_e1, e2: pos_e2,
  n2: pos_n2, n1: pos_n1, s1: pos_s1, s2: pos_s2
};

assign pixel0_data_r = pixel_pipe_N_dat_r;

// ------------------------------------------------------------------------- //
// Line Buffer Push Control.
//
// Circular allocation line-buffer updated on row advance.

localparam logic [4:0] BANK_PUSH_SEL_INIT = 5'b00000;
dffre #(.W(5), .INIT(BANK_PUSH_SEL_INIT)) u_dffr_bank_push_sel (
  .d(bank_push_sel_w), .q(bank_push_sel_r),
  .en(bank_push_sel_en), .arst_n(arst_n), .clk(clk));

assign bank_push_sel_en = row_pos_en;
assign bank_push_sel_w = 
    (row_vld_r == 'b0)
  ? 5'b00001
  : {bank_push_sel_r[3:0], bank_push_sel_r[4]};

assign lb_push = pixel0_vld_r & (~cntrl_stall) ? bank_push_sel_r : 5'b00000;
assign lb_dat = pixel0_data_r;
assign lb_sol = pixel0_pos_r.w2;
assign lb_eol = pixel0_pos_r.e2;

// Push upto one back per cycle.
`P_ASSERT_CR(clk, arst_n, $onehot0(lb_push));

// ------------------------------------------------------------------------- //
// Line Buffer Pop Control.

assign lb_pop = (lb_push != '0) ? (row_vld_r & ~bank_push_sel_r) : 5'b00000;

// May not pop from a bank that is not being pushed to.
`P_ASSERT_CR(clk, arst_n, (lb_push & lb_pop) == 'b0);

// ------------------------------------------------------------------------- //
// Line Buffer Instantiation.

generate case (cfg_pkg::TARGET)

"FPGA": begin: conv_lb_fpga_GEN

for (genvar i = 0; i < 5; i++) begin: lb_GEN

conv_cntrl_lb_fpga u_conv_cntrl_lb_fpga (
//
  .push_i                 (lb_push[i])
, .pop_i                  (lb_pop[i])
, .dat_i                  (lb_dat)
, .sol_i                  (lb_sol) 
, .eol_i                  (lb_eol)
//
, .colD_o                 (lb_colD[i])
//
, .clk                    (clk)
, .arst_n                 (arst_n)
);

end : lb_GEN

end: conv_lb_fpga_GEN

"ASIC": begin: conv_cntrl_lb_asic_GEN

for (genvar i = 0; i < 5; i++) begin: lb_GEN

conv_cntrl_lb_asic u_conv_cntrl_lb_asic (
//
  .push_i                 (lb_push[i])
, .pop_i                  (lb_pop[i])
, .dat_i                  (lb_dat)
, .sol_i                  (lb_sol) 
, .eol_i                  (lb_eol)
//
, .colD_o                 (lb_colD[i])
//
, .clk                    (clk)
, .arst_n                 (arst_n)
);

end : lb_GEN

end: conv_cntrl_lb_asic_GEN

default: begin : conv_cntrl_lb_default_GEN

`TB_ERROR("Unsupported TARGET in conv_cntrl.sv");

end : conv_cntrl_lb_default_GEN

endcase
endgenerate

// ------------------------------------------------------------------------- //
// Egress pipeline

assign egress_pipe_in_vld = (lb_push != 'b0);
assign egress_pipe_in =
  '{ pop: lb_pop, push: lb_push, dat: pixel0_data_r, pos: pixel0_pos_r,
     row_vld: row_vld_r };

dp #(
  .W                       (EGRESS_PIPE_W)
, .N                       (2)
, .TRACK_VALIDITY          (1'b1)
) u_dp_kernel_colD_pos (
  .vld_i                   (egress_pipe_in_vld)
, .dat_i                   (egress_pipe_in)
, .stall_i                 (cntrl_stall)
, .pipe_vld_o              (/* UNUSED */)
, .pipe_dat_o              (/* UNUSED */)
, .vld_o                   (egress_pipe_out_vld_r)
, .dat_o                   (egress_pipe_out_r)
, .clk                     (clk)
, .arst_n                  (arst_n)
);

// ------------------------------------------------------------------------- //
// Line buffer rotator.

// Rotate line-buffer outputs based on image position.
always_comb begin: kernel_colD_rotator_PROC

  case (egress_pipe_out_r.push) inside
    5'b00001: kernel_colD_data = {
        lb_colD[1], lb_colD[2], lb_colD[3], lb_colD[4], egress_pipe_out_r.dat
      };

    5'b00010: kernel_colD_data = {
        lb_colD[2], lb_colD[3], lb_colD[4], lb_colD[0], egress_pipe_out_r.dat
      };

    5'b00100: kernel_colD_data = {
        lb_colD[3], lb_colD[4], lb_colD[0], lb_colD[1], egress_pipe_out_r.dat
      };
    
    5'b01000: kernel_colD_data = {
        lb_colD[4], lb_colD[0], lb_colD[1], lb_colD[2], egress_pipe_out_r.dat
      };
    
    5'b10000: kernel_colD_data = {
        lb_colD[0], lb_colD[1], lb_colD[2], lb_colD[3], egress_pipe_out_r.dat
      };

    default: kernel_colD_data = 'x;
  endcase

end : kernel_colD_rotator_PROC

// Pixel validity determination. Kernel is valid when the center pixel is valid.
always_comb begin: kernel_colD_vld_PROC

  case (egress_pipe_out_r.push) inside
    5'b00001: kernel_colD_vld_pre = egress_pipe_out_r.row_vld[3];
    5'b00010: kernel_colD_vld_pre = egress_pipe_out_r.row_vld[4];
    5'b00100: kernel_colD_vld_pre = egress_pipe_out_r.row_vld[0];
    5'b01000: kernel_colD_vld_pre = egress_pipe_out_r.row_vld[1];
    5'b10000: kernel_colD_vld_pre = egress_pipe_out_r.row_vld[2];
    default:  kernel_colD_vld_pre = 1'bx;
  endcase

end: kernel_colD_vld_PROC

`P_ASSERT_CR(clk, arst_n, $onehot0(egress_pipe_out_r.push));

assign kernel_colD_vld =
  kernel_colD_vld_pre & egress_pipe_out_vld_r & (~cntrl_stall);

assign kernel_colD_pos = egress_pipe_out_r.pos;

// Kernel column D outputs.
assign kernel_colD_push = 
    egress_pipe_out_vld_r
  ? (kernel_colD_vld ? (egress_pipe_out_r.push | egress_pipe_out_r.pop) : '0)
  : 'b0;

// ========================================================================= //
//                                                                           //
// Outputs                                                                   //
//                                                                           //
// ========================================================================= //

assign kernel_colD_vld_o = kernel_colD_vld;
assign kernel_colD_push_o = kernel_colD_push;
assign kernel_colD_pos_o = kernel_colD_pos;
assign kernel_colD_data_o = kernel_colD_data;

endmodule : conv_cntrl

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF

`define ASSERTS_UNDEF
`include "asserts.svh"
`undef ASSERTS_UNDEF
