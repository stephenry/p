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

// Generic model to perform a convolution operation on streaming data.

module conv #(
  // Pixel width in bits
  parameter int PIXEL_W = 8

  // Kernel extension strategy: "ZERO_PAD" | "REPLICATE"
, parameter string EXTEND_STRATEGY = "ZERO_PAD"

  // Kernel diameter, must be odd.
, parameter int KERNEL_DIAMETER_N = 5

  // Parameter to define the target platform (e.g., "FPGA" or "ASIC").
, parameter string TARGET = "FPGA"

  // Total number of pixels emitted by the kernel
, localparam int KERNEL_SIZE_N = (KERNEL_DIAMETER_N * 2)
) (

// -------------------------------------------------------------------------- //
//                                                                            //
// Input                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                           s_tvalid_i
, input wire logic [PIXEL_W - 1:0]           s_tdata_i
, input wire logic                           s_tlast_i
, input wire logic                           s_tuser_i

, output wire logic                          s_tready_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Output                                                                     //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                           m_tready_i
//
, output wire logic                          m_tvalid_o
, output wire logic [KERNEL_SIZE_N - 1:0][PIXEL_W - 1:0] 
                                             m_tdata_o
, output wire logic                          m_tuser_o
, output wire logic                          m_tlast_o
);

endmodule : conv
