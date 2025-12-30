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

module seqgen_cntrl_pla (
// -------------------------------------------------------------------------- //
//                                                                            //
// State (In)                                                                 //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                          start_i

, input wire logic                          busy_r_i
, input wire logic                          done_r_i
, input wire logic [1:0]                    pos_r_i

, input wire logic                          is_first_x_i
, input wire logic                          is_last_x_i

, input wire logic                          is_first_y_i
, input wire logic                          is_last_y_i

// -------------------------------------------------------------------------- //
//                                                                            //
// State (Out)                                                                //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire logic                         busy_w_o
, output wire logic                         done_w_o
, output wire logic [1:0]                   pos_w_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Cntrl (Out)                                                                //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire logic                         coord_y_clr_o
, output wire logic                         coord_y_inc_o
, output wire logic [1:0]                   coord_y_sel_o
, output wire logic                         coord_x_clr_o
, output wire logic                         coord_x_inc_o
, output wire logic [2:0]                   coord_x_sel_o
);

// PLA_BEGIN
//
// .i start_i pos_r_i[1:0] is_first_x_i is_last_x_i is_first_y_i \
//     is_last_y_i busy_r_i done_r_i
//
// .o pos_w_o[1:0] coord_y_clr_o coord_y_inc_o coord_y_sel_o[1:0] \
//     coord_x_clr_o coord_x_inc_o coord_x_sel_o[2:0] busy_w_o done_w_o
//
// 1 -- -- -- - -   00 10 00 10 000 1 0
// 0 00 0- -- 1 0   01 00 01 00 100 1 0
// 0 00 11 11 1 0   11 00 01 00 001 1 0
// 0 11 11 11 1 0   00 00 00 00 000 0 1
// 0 00 10 -- 1 0   00 00 01 01 010 1 0
// 0 01 -0 -- 1 0   00 00 01 01 010 1 0
// 0 01 -1 -- 1 0   11 00 01 00 001 1 0
// 0 11 -1 -0 1 0   00 01 10 10 000 1 0
// 0 11 -1 -1 1 0   00 00 00 00 000 0 1
// 0 -- -- -- 0 1   00 00 00 00 000 0 1
//
// .e
// PLA_END

endmodule: seqgen_cntrl_pla
