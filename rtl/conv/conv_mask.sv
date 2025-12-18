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

module conv_mask (

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

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //


generate case (conv_pkg::EXTEND_STRATEGY)

"ZERO_PAD": begin: zero_pad_GEN

conv_mask_zp u_conv_mask_zp (
    .kernel_i           (kernel_i)
  , .kernel_pos_i       (kernel_pos_i)
  , .kernel_masked_o    (kernel_masked)
);

end: zero_pad_GEN

"REPLICATE": begin : replicate_GEN

// TODO(stephenry): implement replicate strategy.

end : replicate_GEN

default: begin: default_GEN

// TODO(stephenry): static assertion to go here.

end : default_GEN

endcase
endgenerate

// ========================================================================= //
//                                                                           //
// Ouputs                                                                    //
//                                                                           //
// ========================================================================= //

assign kernel_masked_o = kernel_masked;

endmodule : conv_mask