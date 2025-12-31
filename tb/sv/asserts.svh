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

`ifndef TB_RTL_ASSERTS_SVH
`define TB_RTL_ASSERTS_SVH

`ifdef ASSERTS_UNDEF

`undef P_ASSERT_C
`undef P_ASSERT_CR

`else

`define P_ASSERT_C(__clk, __cond) \
    property AssertProperty```__LINE__``; \
      @(posedge __clk) \
      __cond; \
    endproperty : AssertProperty```__LINE__`` \
    assert property (AssertProperty```__LINE__``) \
      else $error($sformatf("ASSERTION FAILED at %s:%d", `__FILE__, `__LINE__))

`define P_ASSERT_CR(__clk, __rst, __cond) \
    property AssertProperty```__LINE__``; \
      @(posedge __clk) disable iff (!__rst) \
      __cond; \
    endproperty : AssertProperty```__LINE__`` \
    assert property (AssertProperty```__LINE__``) \
      else $error($sformatf("ASSERTION FAILED at %s:%d", `__FILE__, `__LINE__))

`endif

`endif /* TB_RTL_ASSERTS_SVH */
