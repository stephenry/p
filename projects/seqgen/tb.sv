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
`include "seqgen_pkg.svh"

// Filename does not match module name. Lint violation suppressed by
// -Wno-DECLFILENAME flag.
module tb`TB_CFG__SUFFIX (

// -------------------------------------------------------------------------- //
//                                                                            //
// Input                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                          start_i

, input wire seqgen_pkg::coord_t            w_i
, input wire seqgen_pkg::coord_t            h_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Output                                                                     //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire seqgen_pkg::coord_t           coord_y_o
, output wire seqgen_pkg::coord_t           coord_x_o

, output wire logic                         busy_o
, output wire logic                         done_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Parameterizations                                                          //
//                                                                            //
// -------------------------------------------------------------------------- //


// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                           clk
, input wire logic                           arst_n

// -------------------------------------------------------------------------- //
//                                                                            //
// TB Boilerplate                                                             //
//                                                                            //
// -------------------------------------------------------------------------- //

`TB_BOILERPLATE_PORTS
);

`TB_BOILERPLATE_BODY(clk, arst_n)

seqgen_pkg::coord_t w_last, h_last;

assign w_last = w_i - 'd1;

assign h_last = h_i - 'd1;

// ========================================================================= //
//                                                                           //
// UUT                                                                       //
//                                                                           //
// ========================================================================= //

seqgen uut (
  .start_i              (start_i)
, .w_i                  (w_last)
, .h_i                  (h_last)
, .coord_y_o            (coord_y_o)
, .coord_x_o            (coord_x_o)
, .busy_o               (busy_o)
, .done_o               (done_o)
, .clk                  (clk)
, .arst_n               (arst_n)
);

// -------------------------------------------------------------------------- //
//                                                                            //
// Parameterizations                                                          //
//                                                                            //
// -------------------------------------------------------------------------- //

endmodule: tb`TB_CFG__SUFFIX
