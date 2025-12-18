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

module conv_lbx (

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel In                                                                   //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                          pixel_vld_i
, input wire conv_pkg::pixel_t              pixel_dat_i
, input wire logic                          pixel_eol_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel Out                                                                  //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire logic                         pixel_vld_o
, output wire conv_pkg::pixel_t             pixel_dat_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Control                                                                    //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                          stall_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                          clk
, input wire logic                          arst_n
);

generate case (conv_pkg::TARGET)

"FPGA": begin: conv_lbx_fpga_GEN

conv_lbx_fpga u_conv_lbx_fpga (
  //
    .pixel_vld_i             (pixel_vld_i)
  , .pixel_dat_i             (pixel_dat_i)
  , .pixel_eol_i             (pixel_eol_i)
  //
  , .pixel_dat_o             (pixel_dat_o)
  , .pixel_vld_o             (pixel_vld_o)
  //
  , .clk                     (clk)
  , .arst_n                  (arst_n)
);

end : conv_lbx_fpga_GEN

"ASIC": begin: conv_lbx_asic_GEN

conv_lbx_asic u_conv_lbx_asic (
  //
    .pixel_vld_i             (pixel_vld_i)
  , .pixel_dat_i             (pixel_dat_i)
  , .pixel_eol_i             (pixel_eol_i)
  //
  , .pixel_dat_o             (pixel_dat_o)
  , .pixel_vld_o             (pixel_vld_o)
  //
  , .clk                     (clk)
  , .arst_n                  (arst_n)
);

end: conv_lbx_asic_GEN

default: begin : conv_lbx_default_GEN

// TODO(stephenry): some static assertion here.

end : conv_lbx_default_GEN

endcase
endgenerate

endmodule : conv_lbx
