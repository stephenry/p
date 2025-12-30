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

// ========================================================================= //
//                                                                           //
// Wires                                                                     //
//                                                                           //
// ========================================================================= //

typedef struct packed {
    // Y position
    logic [1:0]       pos;

    // Y
    //
    logic             y_clr;
    logic             y_inc;
    
    //  1: Inc Y
    //
    //  0: Curr Y
    // 
    logic [1:0]       y_sel;

    // X
    //  
    logic             x_clr;
    logic             x_inc;

    // 2: Prior X
    //
    // 1: Inc X
    //
    // 0: Curr X
    //
    logic [2:0]       x_sel;


    // Status:
    logic             busy;
    logic             done;
} ucode_t;

ucode_t                                ucode;

typedef struct packed {
    logic             start;

    logic [1:0]       pos;

    logic             is_first_x;
    logic             is_last_x;

    logic             is_first_y;
    logic             is_last_y;

    logic             busy;
    logic             done;
} state_t;

state_t                                state;

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

    // Idle -> A
    //
    'b1_??_??_??_?_?: ucode = 'b00__10_00__10_000__1_0;

    // A -> E
    //
    //   x  x  x  x
    //   x  x  A  B
    //   x  E  C  D
    //   x  x  x  x
    //
    'b0_00_0?_??_1_0: ucode = 'b01__00_01__00_100__1_0;

    // A -> C
    //
    //   +---+
    //   | A |
    //   | C |
    //   +---+
    //
    'b0_00_11_11_1_0: ucode = 'b11__00_01__00_001__1_0;

    // C -> Done
    //
    //   +---+
    //   | A |
    //   | C |
    //   +---+
    //
    'b0_11_11_11_1_0: ucode = 'b00__00_00__00_000__0_1;


    // A -> B
    //
    //   | x  x  x  x
    //   | A  B  x  x
    //   | C  D  x  x
    //   | x  x  x  x
    //
    'b0_00_10_??_1_0: ucode = 'b00__00_01__01_010__1_0;

    // E -> B
    //
    //   x  x  x  x  x
    //   x  x  A  B  x
    //   x  E  C  D  x
    //   x  x  x  x  x
    //
    'b0_01_?0_??_1_0: ucode = 'b00__00_01__01_010__1_0;

    // C -> D
    //
    //   x  x  x  x |
    //   x  x  A  B |
    //   x  x  C  D |
    //   x  x  x  x |
    //
    'b0_01_?1_??_1_0: ucode = 'b11__00_01__00_001__1_0;

    // D -> A'
    //
    //  | x  x  x  x |
    //  | x  x  A  B |
    //  | x  E  C  D |
    //  | A' B' x  x |
    //  | C' D' x  x |
    //  | x  x  x  x |
    //
    'b0_11_?1_?0_1_0: ucode = 'b00__01_10__10_000__1_0;

    // D -> Done
    //
    //  | x  x  x  x |
    //  | x  x  A  B |
    //  | x  x  C  D |
    //  +------------+
    //
    'b0_11_?1_?1_1_0: ucode = 'b00__00_00__00_000__0_1; 

    // Done:
    //
    'b0_??_??_??_0_1: ucode = 'b00__00_00__00_000__0_1;


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
assign coord_y_inc_o = ucode.y_inc;
assign coord_y_sel_o = ucode.y_sel;
assign coord_x_clr_o = ucode.x_clr;
assign coord_x_inc_o = ucode.x_inc;
assign coord_x_sel_o = ucode.x_sel;

endmodule: seqgen_cntrl_case
