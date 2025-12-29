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

module seqgen_cntrl_case (
// -------------------------------------------------------------------------- //
//                                                                            //
// State (In)                                                                 //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                          start_i

, input wire logic                          busy_r_i
, input wire logic                          done_r_i
, input wire logic                          pos_r_i

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
, output wire logic                         pos_w_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Cntrl (Out)                                                                //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire logic                         coord_y_clr_o
, output wire logic                         coord_y_upt_o
, output wire logic                         coord_x_clr_o
, output wire logic                         coord_x_upt_o
, output wire logic [3:0]                   coord_x_sel_o
);

// ========================================================================= //
//                                                                           //
// Wires                                                                     //
//                                                                           //
// ========================================================================= //

typedef struct packed {
    logic             start;

    logic             pos;

    logic             is_first_x;
    logic             is_last_x;

    logic             is_first_y;
    logic             is_last_y;

    logic             busy;
    logic             done;
} state_t;

state_t                                state;

typedef struct packed {
    logic             pos;

    logic             y_clr;
    logic             y_upt;

    logic             x_clr;
    logic             x_upt;
    logic [3:0]       x_sel;

    logic             busy;

    logic             done;
} ucode_t;

ucode_t                                ucode;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

assign state = '{
  start: start_i,

  pos: pos_r_i,

  is_first_x: is_first_x_i,
  is_last_x: is_last_x_i,

  is_first_y: is_first_y_i,
  is_last_y: is_last_y_i,

  busy: busy_r_i,
  done: done_r_i
};

always_comb begin: cntrl_PROC


    case (state) inside

    // Start:
    'b1_?_??_??_?_?: ucode = 'b0_00_00_1000_1_0;

    // End:
    'b0_?_??_??_?_1: ucode = 'b0_00_00_0000_0_1;

    // Reset:
    'b0_?_??_??_0_0: ucode = 'b0_00_00_000_0_0;

    // Fallthrough, should never be reached.
    default:         ucode = 'x;
  
  endcase

end: cntrl_PROC

// ========================================================================= //
//                                                                           //
// Outputs                                                                   //
//                                                                           //
// ========================================================================= //

assign pos_w_o = ucode.pos;
assign busy_w_o = ucode.busy;
assign done_w_o = ucode.done;

assign coord_y_clr_o = ucode.y_clr;
assign coord_y_upt_o = ucode.y_upt;
assign coord_x_clr_o = ucode.x_clr;
assign coord_x_upt_o = ucode.x_upt;
assign coord_x_sel_o = ucode.x_sel;

endmodule: seqgen_cntrl_case
