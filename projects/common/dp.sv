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

module dp #(
// Width of each stage
  parameter int W

// Total number of stages
, parameter int N 

// Deconfigure validity tracking to save resources
, parameter bit TRACK_VALIDITY = 1'b1
) (
// -------------------------------------------------------------------------- //
//                                                                            //
// Input                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //
  input wire logic                               vld_i
, input wire [W - 1:0]                           dat_i

, input wire logic                               stall_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Output                                                                     //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire logic [N:1]                        pipe_vld_o
, output wire logic [N:1][W - 1:0]               pipe_dat_o

, output wire logic                              vld_o
, output wire logic [W - 1:0]                    dat_o

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

logic [N:1][W - 1:0]              dat_w;
logic [N:1][W - 1:0]              dat_r;
logic [N:1]                       vld_w;
logic [N:1]                       vld_r;
logic [N:1]                       dat_en;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// ------------------------------------------------------------------------- //
//
for (genvar i = 1; i < (N + 1); i = i + 1) begin : dat_en_GEN

if (i == 1) begin : dat_en_1_GEN
    assign dat_en[i] = vld_i & ~stall_i;
end : dat_en_1_GEN
else begin : dat_en_x_GEN
    assign dat_en[i] = stall_i ? 1'b0 : (!TRACK_VALIDITY || vld_r[i - 1]);
end : dat_en_x_GEN

end : dat_en_GEN

// ------------------------------------------------------------------------- //
//
for (genvar i = 1; i < (N + 1); i = i + 1) begin : dat_GEN

if (i == 1) begin : dat_1_GEN
    assign dat_w[i] = dat_i;
end : dat_1_GEN
else begin : dat_x_GEN
    assign dat_w[i] = dat_r[i - 1];
end : dat_x_GEN

end : dat_GEN

// ------------------------------------------------------------------------- //
//
if (TRACK_VALIDITY) begin : GEN_TRACK_VALIDITY

for (genvar i = 1; i < (N + 1); i = i + 1) begin : vld_GEN

if (i == 1) begin : vld_1_GEN
    assign vld_w[i] = stall_i ? vld_r [i] : vld_i;
end : vld_1_GEN
else begin : vld_x_GEN
    assign vld_w[i] = stall_i ? vld_r [i] : vld_r[i - 1];
end : vld_x_GEN

end : vld_GEN

end: GEN_TRACK_VALIDITY

// ------------------------------------------------------------------------- //
//
for (genvar i = 1; i < (N + 1); i = i + 1) begin : dp_stages_GEN

// State
dffe #(.W(W)) u_dp_stage (
  .d(dat_w[i]), .q(dat_r [i]), .en(dat_en [i]), .clk(clk)
);

if (TRACK_VALIDITY) begin : GEN_TRACK_VALIDITY_FLOP
// Validity
dffr #(.W(1), .INIT(1'b0)) u_dp_vld (
  .d(vld_w[i]), .q(vld_r [i]), .arst_n(arst_n), .clk(clk)
);
end: GEN_TRACK_VALIDITY_FLOP

end : dp_stages_GEN

// ========================================================================= //
//                                                                           //
// Ouputs                                                                    //
//                                                                           //
// ========================================================================= //

if (N > 0) begin : GEN_OUTPUTS

assign pipe_vld_o = TRACK_VALIDITY ? vld_r : 'b0;
assign pipe_dat_o = dat_r;

assign vld_o = TRACK_VALIDITY ? vld_r[N] : 1'b1;
assign dat_o = dat_r[N];

end else begin : GEN_NO_OUTPUTS

// Degenerate case.
assign pipe_vld_o = TRACK_VALIDITY ? vld_i : 'b0;
assign pipe_dat_o = dat_i;

assign vld_o = TRACK_VALIDITY ? vld_i : 1'b1;
assign dat_o = dat_i;

end : GEN_NO_OUTPUTS

endmodule : dp

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
