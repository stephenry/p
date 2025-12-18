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

module tb (

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

, output wire conv_pkg::pixel_t              m_tdata_0_0_o
, output wire conv_pkg::pixel_t              m_tdata_0_1_o
, output wire conv_pkg::pixel_t              m_tdata_0_2_o
, output wire conv_pkg::pixel_t              m_tdata_0_3_o
, output wire conv_pkg::pixel_t              m_tdata_0_4_o

, output wire conv_pkg::pixel_t              m_tdata_1_0_o
, output wire conv_pkg::pixel_t              m_tdata_1_1_o
, output wire conv_pkg::pixel_t              m_tdata_1_2_o
, output wire conv_pkg::pixel_t              m_tdata_1_3_o
, output wire conv_pkg::pixel_t              m_tdata_1_4_o

, output wire conv_pkg::pixel_t              m_tdata_2_0_o
, output wire conv_pkg::pixel_t              m_tdata_2_1_o
, output wire conv_pkg::pixel_t              m_tdata_2_2_o
, output wire conv_pkg::pixel_t              m_tdata_2_3_o
, output wire conv_pkg::pixel_t              m_tdata_2_4_o

, output wire conv_pkg::pixel_t              m_tdata_3_0_o
, output wire conv_pkg::pixel_t              m_tdata_3_1_o
, output wire conv_pkg::pixel_t              m_tdata_3_2_o
, output wire conv_pkg::pixel_t              m_tdata_3_3_o
, output wire conv_pkg::pixel_t              m_tdata_3_4_o

, output wire conv_pkg::pixel_t              m_tdata_4_0_o
, output wire conv_pkg::pixel_t              m_tdata_4_1_o
, output wire conv_pkg::pixel_t              m_tdata_4_2_o
, output wire conv_pkg::pixel_t              m_tdata_4_3_o
, output wire conv_pkg::pixel_t              m_tdata_4_4_o

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

conv_pkg::kernel_t m_tdata;

conv u_uut (
  .s_tvalid_i        (s_tvalid_i)
, .s_tdata_i         (s_tdata_i)
, .s_tlast_i         (s_tlast_i)
, .s_tuser_i         (s_tuser_i)
, .s_tready_o        (s_tready_o)
, .m_tready_i        (m_tready_i)
, .m_tvalid_o        (m_tvalid_o)
, .m_tdata_o         (m_tdata)
, .m_tuser_o         (m_tuser_o)
, .m_tlast_o         (m_tlast_o)
, .clk               (clk)
, .arst_n            (arst_n)
);

// Unrolling m_tdata array to individual outputs for easier access
// in the C++ testbench. This could also be done using a preprocessor,
// or directly in C++.

assign m_tdata_0_0_o = m_tdata[0][0];
assign m_tdata_0_1_o = m_tdata[0][1];
assign m_tdata_0_2_o = m_tdata[0][2];
assign m_tdata_0_3_o = m_tdata[0][3];
assign m_tdata_0_4_o = m_tdata[0][4];

assign m_tdata_1_0_o = m_tdata[1][0];
assign m_tdata_1_1_o = m_tdata[1][1];
assign m_tdata_1_2_o = m_tdata[1][2];
assign m_tdata_1_3_o = m_tdata[1][3];
assign m_tdata_1_4_o = m_tdata[1][4];

assign m_tdata_2_0_o = m_tdata[2][0];
assign m_tdata_2_1_o = m_tdata[2][1];
assign m_tdata_2_2_o = m_tdata[2][2];
assign m_tdata_2_3_o = m_tdata[2][3];
assign m_tdata_2_4_o = m_tdata[2][4];

assign m_tdata_3_0_o = m_tdata[3][0];
assign m_tdata_3_1_o = m_tdata[3][1];
assign m_tdata_3_2_o = m_tdata[3][2];
assign m_tdata_3_3_o = m_tdata[3][3];
assign m_tdata_3_4_o = m_tdata[3][4];

assign m_tdata_4_0_o = m_tdata[4][0];
assign m_tdata_4_1_o = m_tdata[4][1];
assign m_tdata_4_2_o = m_tdata[4][2];
assign m_tdata_4_3_o = m_tdata[4][3];
assign m_tdata_4_4_o = m_tdata[4][4];

endmodule: tb
