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
, input wire logic                          m_tvalid_o

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
col_pos_t                    pixel_pipe_0;

logic [3:0]                  pixel_pipe_vld_r;
col_pos_t [3:0]              pixel_pipe_r;

conv_pkg::kernel_pos_t       pixel0_pos;
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

logic                        bank_vld_en;
logic [4:0]                  bank_vld_r;
logic [4:0]                  bank_vld_w;

logic                        bank_push_sel_en;
logic [4:0]                  bank_push_sel_r;
logic [4:0]                  bank_push_sel_w;

logic                        bank_pop_sel_en;
logic [4:0]                  bank_pop_sel_r;
logic [4:0]                  bank_pop_sel_w;

logic                        row_advance;
logic                        row_pos_en;
logic [4:0]                  row_pos_r;
logic [4:0]                  row_pos_w;

// Line Buffer Control
logic [4:0]                  lb_push;
logic [4:0]                  lb_pop;
conv_pkg::pixel_t            lb_dat;
logic                        lb_sof;
logic                        lb_eol;
logic [4:0]                  lb_sel;
conv_pkg::pixel_t [4:0]      lb_colD;

logic                       kernel_colD_push_vld;
logic [4:0]                 kernel_colD_push;
conv_pkg::kernel_pos_t      kernel_colD_pos;
conv_pkg::pixel_t [4:0]     kernel_colD_data;

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

assign pos_w2 = (pixel_pipe_r[2].sof | pixel_pipe_r[3].eol);
assign pos_w1 = (pixel_pipe_r[3].sof | pixel_pipe_r[4].eol);
assign pos_e2 = (pixel_pipe_r[1].eol);
assign pos_e1 = (pixel_pipe_r[2].eol);

assign pixel_pipe_0 = '{ sof: s_tuser_i, eol: s_tlast_i }; 

dp #(.W(COL_POS_W), .N(4)) u_dp_col (
  .vld_i                   (1'b1)
, .dat_i                   (pixel_pipe_0)
, .stall_i                 (cntrl_stall)
, .pipe_vld_o              (pixel_pipe_vld_r)
, .pipe_dat_o              (pixel_pipe_r)
, .vld_o                   (/* UNUSED */)
, .dat_o                   (/* UNUSED */)
, .clk                     (clk)
, .arst_n                  (arst_n)
);

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

assign pos_n2 = pixel_pipe_r[2].sof;
assign pos_n1 = pixel_pipe_r[1].sof;
assign pos_s1 = pixel_pipe_r[4].sof;
assign pos_s2 = pixel_pipe_r[3].sof;

assign row_advance = pixel_pipe_r[2].eol;

localparam logic [4:0] ROW_POS_INIT = 5'b00001;

dffre #(.W(5), .INIT(ROW_POS_INIT)) u_dffr_row_pos (
  .d(row_pos_w), .q(row_pos_r), .en(row_pos_en), .arst_n(arst_n), .clk(clk));

assign row_pos_en = (~cntrl_stall) & pixel_pipe_r[2].eol;
assign row_pos_w = {row_pos_r[3:0], pixel_pipe_r[1].sof};

// ------------------------------------------------------------------------- //
// Bank validity tracking.
//
// After the first lines, all banks become valid. This logic is present
// to inhibit reads from invalid banks during initial frame startup.

localparam logic [4:0] BANK_VLD_INIT = 5'b00000;

dffre #(.W(5), .INIT(BANK_VLD_INIT)) u_dffr_bank_vld (
  .d(bank_vld_w), .q(bank_vld_r), .en(bank_vld_en), .arst_n(arst_n), .clk(clk));

assign bank_vld_en = (~cntrl_stall) & pixel_pipe_r[2].eol;
assign bank_vld_w = { bank_vld_r[3:0], 1'b1 };

// ------------------------------------------------------------------------- //
// Position calculation (relative to pixel a pixel pipeline position 2)

assign pixel0_pos = '{
  w2: pos_w2, w1: pos_w1, e2: pos_e2, e1: pos_e1,
  n2: pos_n2, n1: pos_n1, s2: pos_s2, s1: pos_s1
};

// Pixel delay pipeline to align with Pixel 0 position.
//
dp #(.W(conv_pkg::PIXEL_W), .N(2)) u_dp_pixel (
  .vld_i                   (1'b1)
, .dat_i                   (s_tdata_i)
, .stall_i                 (cntrl_stall)
, .pipe_vld_o              (/* UNUSED */)
, .pipe_dat_o              (/* UNUSED */)
, .vld_o                   (/* UNUSED */)
, .dat_o                   (pixel0_data_r)
, .clk                     (clk)
, .arst_n                  (arst_n)
);

// ------------------------------------------------------------------------- //
// Line Buffer Push Control.
//
// Circular allocation line-buffer updated on row advance.

localparam logic [4:0] BANK_PUSH_SEL_INIT = 5'b00001;

dffre #(.W(5), .INIT(BANK_PUSH_SEL_INIT)) u_dffr_bank_push_sel (
  .d(bank_push_sel_w), .q(bank_push_sel_r),
  .en(bank_push_sel_en), .arst_n(arst_n), .clk(clk));

assign bank_push_sel_en = row_pos_en;
assign bank_push_sel_w = {bank_push_sel_r[3:0], bank_push_sel_r[4]};

assign lb_push = cntrl_stall ? 5'b00000 : bank_push_sel_r;
assign lb_dat = pixel0_data_r;
assign lb_sof = pixel0_pos.w2;
assign lb_eol = pixel0_pos.e2;

// ------------------------------------------------------------------------- //
// Line Buffer Pop Control.

localparam logic [4:0] BANK_POP_SEL_INIT = 5'b00001;

dffre #(.W(5), .INIT(BANK_POP_SEL_INIT)) u_dffr_bank_pop_sel (
  .d(bank_pop_sel_w), .q(bank_pop_sel_r),
  .en(bank_pop_sel_en), .arst_n(arst_n), .clk(clk));

assign bank_pop_sel_en = (~cntrl_stall) & pixel_pipe_r[2].eol;
assign bank_pop_sel_w = {bank_pop_sel_r[3:0], bank_pop_sel_r[4]};

assign lb_pop = cntrl_stall ? 5'b00000 : bank_vld_r;
assign lb_sel = bank_pop_sel_r;

generate case (cfg_pkg::TARGET)

"FPGA": begin: conv_lb_fpga_GEN

for (genvar i = 0; i < 5; i++) begin: lb_GEN

conv_cntrl_lb_fpga u_conv_cntrl_lb_fpga (
//
  .push_i                 (lb_push[i])
, .pop_i                  (lb_pop[i])
, .dat_i                  (lb_dat)
, .sof_i                  (lb_sof) 
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
, .sof_i                  (lb_sof) 
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
// Line buffer rotator.

// Rotate line-buffer outputs based on image position.

always_comb begin: lb_rotator_PROC

  case (5'b0000) inside
    5'b00001: kernel_colD_data = {
        lb_colD[3], lb_colD[4], lb_colD[0], lb_colD[1], lb_colD[2]
      };

    5'b00010: kernel_colD_data = {
        lb_colD[4], lb_colD[0], lb_colD[1], lb_colD[2], lb_colD[3]
      };

    5'b00100: kernel_colD_data = {
        lb_colD[0], lb_colD[1], lb_colD[2], lb_colD[3], lb_colD[4]
      };
    
    5'b01000: kernel_colD_data = {
        lb_colD[1], lb_colD[2], lb_colD[3], lb_colD[4], lb_colD[0]
      };
    
    5'b10000: kernel_colD_data = {
        lb_colD[2], lb_colD[3], lb_colD[4], lb_colD[0], lb_colD[1]
      };

    default: kernel_colD_data = 'x;
  endcase

end : lb_rotator_PROC

// ------------------------------------------------------------------------- //
// Delay pipeline to align pixel position with latency across line-buffer.

dp #(
  .W                       (conv_pkg::KERNEL_POS_W)
, .N                       (2)
, .TRACK_VALIDITY          (1'b0)
) u_dp_kernel_colD_pos (
  .vld_i                   (1'b1)
, .dat_i                   (pixel0_pos)
, .stall_i                 (cntrl_stall)
, .pipe_vld_o              (/* UNUSED */)
, .pipe_dat_o              (/* UNUSED */)
, .vld_o                   (/* UNUSED */)
, .dat_o                   (kernel_colD_pos)
, .clk                     (clk)
, .arst_n                  (arst_n)
);

dp #(
  .W                       (5)
, .N                       (2)
, .TRACK_VALIDITY          (1'b1)
) u_dp_kernel_colD_push (
  .vld_i                   (bank_vld_r[2])
, .dat_i                   (bank_pop_sel_r)
, .stall_i                 (cntrl_stall)
, .pipe_vld_o              (/* UNUSED */)
, .pipe_dat_o              (/* UNUSED */)
, .vld_o                   (kernel_colD_push_vld)
, .dat_o                   (kernel_colD_push)
, .clk                     (clk)
, .arst_n                  (arst_n)
);

// ========================================================================= //
//                                                                           //
// Ouputs                                                                    //
//                                                                           //
// ========================================================================= //

assign kernel_colD_push_o = kernel_colD_push_vld ? kernel_colD_push : 'b0;
assign kernel_colD_pos_o = kernel_colD_pos;
assign kernel_colD_data_o = kernel_colD_data;

endmodule : conv_cntrl

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
