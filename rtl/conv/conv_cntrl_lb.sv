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

module conv_cntrl_lb (

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel In                                                                   //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic [4:0]                    push_i
, input wire logic [4:0]                    pop_i
, input wire conv_pkg::pixel_t              dat_i
, input wire logic                          sof_i
, input wire logic                          eol_i
, input wire logic [4:0]                    sel_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel Out                                                                  //
//                                                                            //
// -------------------------------------------------------------------------- //

, output conv_pkg::pixel_t [4:0]            colD_o

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

conv_pkg::pixel_t [4:0]               lbx_colD;
conv_pkg::pixel_t [4:0]               colD;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

generate case (conv_pkg::TARGET)

"FPGA": begin: conv_lbx_fpga_GEN
/*
conv_cntrl_lb_fpga u_conv_cntrl_lb_fpga (
//
  .push_i                 (push_i)
, .pop_i                  (pop_i)
, .dat_i                  (dat_i)
, .sof_i                  (sof_i) 
, .eol_i                  (eol_i)
//
, .colD_o                 (lbx_colD)
//
, .clk                    (clk)
, .arst_n                 (arst_n)
);
*/
end : conv_lbx_fpga_GEN

"ASIC": begin: conv_cntrl_lb_asic_GEN
/*
conv_cntrl_lb_asic u_conv_cntrl_lb_asic (
//
  .push_i                 (push_i)
, .pop_i                  (pop_i)
, .dat_i                  (dat_i)
, .sof_i                  (sof_i) 
, .eol_i                  (eol_i)
//
, .colD_o                 (lbx_colD)
//
, .clk                    (clk)
, .arst_n                 (arst_n)
);
*/
end: conv_cntrl_lb_asic_GEN

default: begin : conv_cntrl_lb_default_GEN

// TODO(stephenry): some static assertion here.

end : conv_cntrl_lb_default_GEN

endcase
endgenerate

// ------------------------------------------------------------------------- //

always_comb begin: rotator_PROC

/*
  case (sel_i) inside
    4'b0001: colD = {lbx_colD[2], lbx_colD[3], lbx_colD[4], lbx_colD[1]};
    4'b0010: colD = {lbx_colD[3], lbx_colD[4], lbx_colD[1], lbx_colD[2]};
    4'b0100: colD = {lbx_colD[4], lbx_colD[1], lbx_colD[2], lbx_colD[3]};
    4'b1000: colD = {lbx_colD[1], lbx_colD[2], lbx_colD[3], lbx_colD[4]};
    default: colD = 'x;
  endcase
*/
end : rotator_PROC

// ========================================================================= //
//                                                                           //
// Ouputs                                                                    //
//                                                                           //
// ========================================================================= //

assign colD_o = colD;

endmodule : conv_cntrl_lb
