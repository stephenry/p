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

module conv_mask_zp (

// -------------------------------------------------------------------------- //
//                                                                            //
// Kernel                                                                     //
//                                                                            //
// -------------------------------------------------------------------------- //

  input conv_pkg::kernel_t                       kernel_i
, input conv_pkg::kernel_pos_t                   kernel_pos_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Kernel (Masked)                                                            //
//                                                                            //
// -------------------------------------------------------------------------- //

, output conv_pkg::kernel_t                      kernel_masked_o

);

// ========================================================================= //
//                                                                           //
// Wire(s)                                                                   //
//                                                                           //
// ========================================================================= //

conv_pkg::kernel_t                    kernel_masked;

logic                                 kill_col_a;
logic                                 kill_col_b;
logic                                 kill_col_c;
logic                                 kill_col_d;

logic                                 kill_row_a;
logic                                 kill_row_b;
logic                                 kill_row_c;
logic                                 kill_row_d;

logic [conv_pkg::KERNEL_DIAMETER_N - 1:0]
      [conv_pkg::KERNEL_DIAMETER_N - 1:0]  zero_pad;

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// -------------------------------------------------------------------------- //
// Column masking:

//  A B X C D
//  A B X C D
//  A B O C D
//  A B X C D
//  A B X C D

assign kill_col_a = (kernel_pos_i.w1 | kernel_pos_i.w2);
assign kill_col_b =                    kernel_pos_i.w2;
assign kill_col_c =                    kernel_pos_i.e2;
assign kill_col_d = (kernel_pos_i.e1 | kernel_pos_i.e2);

// -------------------------------------------------------------------------- //
// Row masking:

//   A A A A A
//   B B B B B
//   X X O X X
//   C C C C C
//   D D D D D

assign kill_row_a = (kernel_pos_i.n1 | kernel_pos_i.n2);
assign kill_row_b =                    kernel_pos_i.n2;
assign kill_row_c =                    kernel_pos_i.s2;
assign kill_row_d = (kernel_pos_i.s1 | kernel_pos_i.s2);

// -------------------------------------------------------------------------- //

for (genvar m = 0; m < conv_pkg::KERNEL_DIAMETER_N; m++) begin: zero_pad_m_GEN

for (genvar n = 0; n < conv_pkg::KERNEL_DIAMETER_N; n++) begin: zero_pad_n_GEN

// Compute zero-pad mask.
//
assign zero_pad[m][n] = 
    ((m == 4) ? kill_row_a : 1'b0) |
    ((m == 3) ? kill_row_b : 1'b0) |
    ((m == 1) ? kill_row_c : 1'b0) |
    ((m == 0) ? kill_row_d : 1'b0) |
    ((n == 4) ? kill_col_a : 1'b0) |
    ((n == 3) ? kill_col_b : 1'b0) |
    ((n == 1) ? kill_col_c : 1'b0) |
    ((n == 0) ? kill_col_d : 1'b0);

end: zero_pad_n_GEN

end: zero_pad_m_GEN

// -------------------------------------------------------------------------- //

for (genvar m = 0; m < conv_pkg::KERNEL_DIAMETER_N; m++) begin: row_GEN
    
for (genvar n = 0; n < conv_pkg::KERNEL_DIAMETER_N; n++) begin: col_GEN

// Kill pixel if in zero-pad region.
//
assign kernel_masked[m][n] =
    ({conv_pkg::PIXEL_W{~zero_pad[m][n]}} & kernel_i[m][n]);

end: col_GEN

end: row_GEN

// ========================================================================= //
//                                                                           //
// Outputs                                                                   //
//                                                                           //
// ========================================================================= //

assign kernel_masked_o = kernel_masked;

endmodule : conv_mask_zp
