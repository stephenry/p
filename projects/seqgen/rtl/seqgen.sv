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
`include "flops.svh"

// Well known interview question to design a small controller to emit
// the following sequence.
//
//  +-----------------------------------------------------------+
//  | (  0,  0)   (  0,   1)   (  0,  2)   ... (  0, X - 1 )
//  | (  1,  0)   (  1,   1)   (  1,  2)   ... (  1, X - 1 )
//  | (  2,  0)   (  2,   1)   (  2,  2)   ... (  2, X - 1 )
//  | (  3,  0)   (  3,   1)   (  3,  2)   ... (  3, X - 1 )
//  | (  4,  0)   (  4,   1)   (  4,  2)   ... (  4, X - 1 )
//  |   ...         ...         ...              ...        ...
//  +-----------------------------------------------------------+
//
// Sequence as follows:
//
//  (0, 0) -> (0, 1) -> (1, 0) -> (0, 2) -> (1, 1) -> (2, 0) -> ...
//
// Constraints:
//
//   - Y-axis is constrained to be a power of 2.
//
// Notes:
//
// Focus on PPA optimization. Two implementations of the controller
// are provided: one using a PLA style implementation, and another
// using a generic Verilog case posment.
//
// At the limit, a controller as simple as this would not require such
// a focus on PPA, but this is a toy example for educational purposes.
//
// Inspired by the project at: 
//
//   https://github.com/comestime/RTL4Interview/Seq_Gen
//


module seqgen (

// -------------------------------------------------------------------------- //
//                                                                            //
// Inputs                                                                     //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                          start_i

, input wire seqgen_pkg::coord_t            w_last_i
, input wire seqgen_pkg::coord_t            h_last_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Outputs                                                                    //
//                                                                            //
// -------------------------------------------------------------------------- //

, output wire seqgen_pkg::coord_t           coord_y_o
, output wire seqgen_pkg::coord_t           coord_x_o

, output wire logic                         busy_o
, output wire logic                         done_o

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

// Control
//
`P_DFF(logic [1:0], pos, clk);
`P_DFF(logic, busy, clk);
`P_DFF(logic, done, clk);

logic                                   is_first_x;
logic                                   is_last_x;

logic                                   is_first_y;
logic                                   is_last_y;

seqgen_pkg::coord_t                     inc_x;
seqgen_pkg::coord_t                     inc_y;

// Output flops
//
logic                                   coord_x_inc;
logic                                   coord_x_cur;
`P_DFF(seqgen_pkg::coord_t, coord_x, clk);

logic                                   coord_y_inc;
logic                                   coord_y_cur;
`P_DFF(seqgen_pkg::coord_t, coord_y, clk);
// Tie-offs
logic                                  inc_y_carry;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// Controller

generate case (cfg_pkg::IMPL)

  "pla": begin: cntrl_pla_GEN
    seqgen_cntrl_pla u_cntrl (
    //
      .start_i              (start_i)
    //
    , .busy_r_i             (busy_r)
    , .done_r_i             (done_r)
    , .pos_r_i              (pos_r)
    //
    , .is_first_x_i         (is_first_x)
    , .is_last_x_i          (is_last_x)
    , .is_first_y_i         (is_first_y)
    , .is_last_y_i          (is_last_y)
    //
    , .busy_w_o             (busy_w)
    , .done_w_o             (done_w)
    , .pos_w_o              (pos_w)
    //
    , .coord_x_inc_o        (coord_x_inc)
    , .coord_x_cur_o        (coord_x_cur)
    , .coord_y_inc_o        (coord_y_inc)
    , .coord_y_cur_o        (coord_y_cur)
    );
  end: cntrl_pla_GEN

  "case": begin: cntrl_case_GEN
    seqgen_cntrl_case u_cntrl (
    //
      .start_i              (start_i)
    //
    , .busy_r_i             (busy_r)
    , .done_r_i             (done_r)
    , .pos_r_i              (pos_r)
    //
    , .is_first_x_i         (is_first_x)
    , .is_last_x_i          (is_last_x)
    , .is_first_y_i         (is_first_y)
    , .is_last_y_i          (is_last_y)
    //
    , .busy_w_o             (busy_w)
    , .done_w_o             (done_w)
    , .pos_w_o              (pos_w)
    //
    , .coord_x_inc_o        (coord_x_inc)
    , .coord_x_cur_o        (coord_x_cur)
    , .coord_y_inc_o        (coord_y_inc)
    , .coord_y_cur_o        (coord_y_cur)
    );
  end: cntrl_case_GEN

  default: begin

  end

endcase
endgenerate

assign inc_x = 
    ({cfg_pkg::COORD_W{coord_y_inc}} & coord_y_r)
  | ({cfg_pkg::COORD_W{coord_x_inc}} & coord_x_r)
  ;

// Shared incrementer:
inc #(.W(cfg_pkg::COORD_W)) u_inc (
  .x_i(inc_x), .y_o(inc_y), .carry_o(inc_y_carry)
);

assign coord_y_w =
    ({cfg_pkg::COORD_W{coord_y_inc}} & inc_y)
  | ({cfg_pkg::COORD_W{coord_y_cur}} & coord_y_r)
  ;

assign coord_x_w =
    ({cfg_pkg::COORD_W{coord_x_inc}} & inc_x)
  | ({cfg_pkg::COORD_W{coord_x_cur}} & coord_x_r)
  ;

assign is_first_x = (coord_x_r == '0);
assign is_last_x = (coord_x_r == w_last_i);

assign is_first_y = (coord_y_r == '0);
assign is_last_y = (coord_y_r == h_last_i);

// ========================================================================= //
//                                                                           //
// Outputs                                                                   //
//                                                                           //
// ========================================================================= //

assign coord_y_o = coord_y_r;
assign coord_x_o = coord_x_r;

assign busy_o = busy_r;
assign done_o = done_r;

// ========================================================================= //
//                                                                           //
// UNUSED                                                                    //
//                                                                           //
// ========================================================================= //

logic UNUSED__tie_off;
assign UNUSED__tie_off = |{ inc_y_carry, arst_n };

endmodule: seqgen

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
