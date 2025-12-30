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

module seqgen_cntrl_fsm (
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

// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                           clk
, input wire logic                           arst_n
);


// ========================================================================= //
//                                                                           //
// Wires                                                                     //
//                                                                           //
// ========================================================================= //

typedef enum logic [3:0] {
    S_IDLE = 'b0000,
    S_DONE = 'b1111
} state_t;

state_t                                state_next;
`P_DFF(state_t, state, clk);

logic                                  busy_w;
logic                                  done_w;
logic [1:0]                            pos_w;
logic                                  coord_y_clr;
logic                                  coord_y_inc;
logic [1:0]                            coord_y_sel;
logic                                  coord_x_clr;
logic                                  coord_x_inc;
logic [2:0]                            coord_x_sel;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

always_comb begin: next_state_PROC

  // Defaults:
  pos_w = 'b0;
  coord_y_clr = 'b0;
  coord_y_inc = 'b0;
  coord_y_sel = 'b00;
  coord_x_clr = 'b0;
  coord_x_inc = 'b0;
  coord_x_sel = 'b000;
  busy_w = 'b0;
  done_w = 'b0;

  // State update override on start_i.
  state_next = start_i ? S_IDLE : state_r;

  case (state_next) inside

    S_IDLE: begin

    end

    S_DONE: begin
        done_w = 1'b1;
        state_w = S_DONE;
    end

    default: begin

    end

  endcase

end: next_state_PROC

// ========================================================================= //
//                                                                           //
// Outputs                                                                   //
//                                                                           //
// ========================================================================= //

assign busy_w_o = busy_w;
assign done_w_o = done_w;
assign pos_w_o = pos_w;
assign coord_y_clr_o = coord_y_clr;
assign coord_y_inc_o = coord_y_inc;
assign coord_y_sel_o = coord_y_sel;
assign coord_x_clr_o = coord_x_clr;
assign coord_x_inc_o = coord_x_inc;
assign coord_x_sel_o = coord_x_sel; 

endmodule: seqgen_cntrl_fsm

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
