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

`ifndef TB_SV_TB_PKG_SVH
`define TB_SV_TB_PKG_SVH

`ifdef TB_PKG_UNDEF

`undef TB_STRINGIFY
`undef TB_STATIC_ASSERT
`undef TB_ERROR

`else

`define TB_STRINGIFY(__x) `"__x`"

// TB parameterization support macros. Ought to be deconfigured from synthesis
// builds.
`define TB_STATIC_ASSERT(__cond, __msg) \
    initial begin \
        if (!(__cond)) begin \
            tb_pkg::tb_error(`__FILE__, `__LINE__, __msg); \
        end \
    end

`define TB_ERROR(__msg) \
    initial begin \
        tb_pkg::tb_error(`__FILE__, `__LINE__, __msg); \
    end

`endif

package tb_pkg;

import "DPI-C" task tb_error(
    input string filename, input int lineno, input string msg);

endpackage: tb_pkg;

`endif
