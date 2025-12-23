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

`ifndef RTL_CONV_CONV_PKG_SVH
`define RTL_CONV_CONV_PKG_SVH

`include "tb_pkg.svh"

package conv_pkg;

// Image Width
localparam int IMAGE_MAX_W = 4096;

// Image Height
localparam int IMAGE_MAX_H = 4096;

// Pixel width in bits
localparam int PIXEL_W = 8;

// Pixel type
typedef logic [PIXEL_W - 1:0] pixel_t;

// Convoution kernel diameter, must be odd.
//
// (NOTE: RTL has not been written with sufficient parameterization to allow 
// for this value to be changed.)
localparam int KERNEL_DIAMETER_N = 5;

typedef pixel_t [KERNEL_DIAMETER_N - 1:0] pixel_span_t;

// Kernel type (KERNEL_N * KERNEL_N pixels)
typedef pixel_t [KERNEL_DIAMETER_N - 1:0][KERNEL_DIAMETER_N - 1:0] kernel_t;

// Position map for convolution kernel:

//        A          B                    C         D
//   +--------------------------------------------------+
// A | {N2,W2} | {N2,W1} | { N2, X} | {N2,E1} | {N2,E2} |
// B | {N1,W2} | {N1,W1} | { N1, X} | {N1,E1} | {N1,E2} |
//   | { X,W2} | { X,W1} | {  X, X} | { X,E1} | { X,E2} |
// C | {S1,W2} | {S1,W1} | { S1, X} | {S1,E1} | {S1,E2} |
// D | {S2,W2} | {S2,W1} | { S2, X} | {S2,E1} | {S2,E2} |
//   +--------------------------------------------------+

// Window position structure:
typedef struct packed {

    // West
    logic w2;
    logic w1;

    // East:
    logic e1;
    logic e2;

    // North:
    logic n2;
    logic n1;

    // South:
    logic s1;
    logic s2;

} kernel_pos_t;

localparam int KERNEL_POS_W = $bits(kernel_pos_t);

endpackage : conv_pkg

`endif /* RTL_CONV_CONV_PKG_SVH */
