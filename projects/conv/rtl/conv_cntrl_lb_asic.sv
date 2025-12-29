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
`include "flops.svh"
`include "common_pkg.svh"

module conv_cntrl_lb_asic (

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel In                                                                   //
//                                                                            //
// -------------------------------------------------------------------------- //

  input wire logic                          push_i
, input wire logic                          pop_i
, input wire conv_pkg::pixel_t              dat_i
, input wire logic                          sol_i
, input wire logic                          eol_i

// -------------------------------------------------------------------------- //
//                                                                            //
// Pixel Out                                                                  //
//                                                                            //
// -------------------------------------------------------------------------- //

, output conv_pkg::pixel_t                  colD_o

// -------------------------------------------------------------------------- //
//                                                                            //
// Misc.                                                                      //
//                                                                            //
// -------------------------------------------------------------------------- //

, input wire logic                          clk
, input wire logic                          arst_n
);

// ========================================================================= //
//                                                                           //
// Wire(s)                                                                   //
//                                                                           //
// ========================================================================= //

// Nominmal SRAM word with for ASIC implementation. In general, SRAM
// compilers do not allow small word widths (i.e. a single pixel), so
// we define a larger word with an then inject additional logic to pack
// and unpack pixel data.
localparam int SRAM_W = 128;
typedef logic [SRAM_W-1:0] sram_word_t;

// Pixels per SRAM word.
localparam int PIXELS_PER_WORD_N =
  common_pkg::ceil(SRAM_W, conv_pkg::PIXEL_W);

// Maximum number of SRAM words
localparam int SRAM_WORDS_N =
  common_pkg::ceil(conv_pkg::IMAGE_MAX_W, PIXELS_PER_WORD_N);

// ------------------------------------------------------------------------- //
// Address calculations

localparam ADDR_W = $clog2(SRAM_WORDS_N);
typedef logic [ADDR_W-1:0] addr_t;

logic                                       addr_clr;
logic                                       addr_en;
`P_DFFE(addr_t, addr, addr_en, clk);

// ------------------------------------------------------------------------- //
// Push Path

logic [PIXELS_PER_WORD_N-2:0]               word_en;
conv_pkg::pixel_t [PIXELS_PER_WORD_N-2:0]   word_w;
conv_pkg::pixel_t [PIXELS_PER_WORD_N-2:0]   word_r;
logic [PIXELS_PER_WORD_N-2:0]               word_vld_w;
logic [PIXELS_PER_WORD_N-2:0]               word_vld_r;
logic [PIXELS_PER_WORD_N-1:0]               word_admit_dat;

logic                                       word_is_last;
logic                                       word_next_en;
`P_DFFE(logic [PIXELS_PER_WORD_N-1:0], word_next, word_next_en, clk);
logic [PIXELS_PER_WORD_N-1:0]               word_next;

// Final composed word for SRAM interface.
conv_pkg::pixel_t [PIXELS_PER_WORD_N-1:0]  word_din;
logic                                      advance_push;

// ------------------------------------------------------------------------- //
// Pop Path
logic                                      advance_pop_pre;
logic                                      advance_pop;

// ------------------------------------------------------------------------- //
// SRAM bank selection

logic                                      ce;
logic                                      rnw;
sram_word_t                                dout;

// ------------------------------------------------------------------------- //
// SRAM pipelining
typedef struct packed {
  logic       dout_vld;
  logic       pop;
  logic       eol;
} pop_pipe_t;

`P_DFFR(pop_pipe_t, pop_pipe, 3'b000, clk, arst_n);

// ------------------------------------------------------------------------- //
// SRAM skid buffer
logic                                      skid_en;
`P_DFFE(sram_word_t, skid, skid_en, clk);
logic                                      skid_vld_pre;
logic                                      skid_vld_kill;
`P_DFFR(logic, skid_vld, 'b0, clk, arst_n);

logic                                      skid_sel_en;
`P_DFFE(logic [PIXELS_PER_WORD_N-1:0], skid_sel, skid_sel_en, clk);
conv_pkg::pixel_t                          skid_demux;
logic                                      skid_demux_bypass;
logic                                      colD_en;
`P_DFFE(conv_pkg::pixel_t, colD, colD_en, clk);

// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// ------------------------------------------------------------------------- //
// Push Path

// One-Hot pointer to the next pixel position within the SRAM word.
//
assign word_is_last = word_next_r[PIXELS_PER_WORD_N - 1] | eol_i;

assign word_next_en = push_i;
assign word_next_w = sol_i ? 'b10 : word_is_last ? 'b01 : (word_next_r << 1);
assign word_next = sol_i ? 'b1 : word_next_r;

// Logic to compose an SRAM word for some arbitrary word width and
// line buffer pixel width.
//
for (genvar i = 0; i < PIXELS_PER_WORD_N; i++) begin: din_pack_GEN

if (i < (PIXELS_PER_WORD_N - 1)) begin : reg_GEN

  dffe #(.W(conv_pkg::PIXEL_W)) u_word_reg (
    .d(word_w[i]), .q(word_r[i]), .en(word_en[i]), .clk(clk)
  );

  dffr #(.W(1), .INIT(1'b0)) u_word_vld_reg (    
    .d(word_vld_w[i]), .q(word_vld_r[i]), .arst_n(arst_n), .clk(clk)
  );

  assign word_en[i] = (word_next[i] & push_i);
  assign word_w[i] = dat_i;

  assign word_vld_w[i] = 
     word_vld_r [i] ? (~word_is_last) : word_next[i] & push_i;

end: reg_GEN

if (i < (PIXELS_PER_WORD_N - 1)) begin : not_last_GEN

  assign word_admit_dat[i] =
    eol_i & word_next[i] & (~word_vld_r[i]);

  assign word_din[i] = word_admit_dat[i] ? dat_i : word_r[i];

end: not_last_GEN
else begin: last_GEN

  assign word_admit_dat[i] = word_next[i];

  assign word_din[i] = word_admit_dat[i] ? dat_i : '0;

end: last_GEN

end: din_pack_GEN

// Advance push whenever (1) the datapath is not
// stalled, and (2) either end-of-line is reached or the current word
// being composed is admitted (i.e. full).
assign advance_push =
    push_i                                                       // (1)
  & (eol_i | (word_admit_dat != 'b0));                           // (2)

// ------------------------------------------------------------------------- //
// Pop path

// Advance pop whenever (1) there is a pop request, (2) the datapath is not
// stalled, and (3) the skid buffer is not full or the skid buffer is
// being drained and is reading the last pixel.
assign advance_pop_pre = 
  pop_i & (~skid_vld_r | skid_sel_r[PIXELS_PER_WORD_N - 1]);

if (PIXELS_PER_WORD_N > 1) begin: advance_pop_multi_GEN
  // For multi-pixel words, only advance pop when the output
  // of the SRAM is invalid, or, whenever the last pixel of the line
  // is present at the output of the SRAM.
  assign advance_pop =
    advance_pop_pre & (pop_pipe_r.eol | ~pop_pipe_r.dout_vld);
end: advance_pop_multi_GEN
else begin: advance_pop_single_GEN
  assign advance_pop = advance_pop_pre;
end: advance_pop_single_GEN

// ------------------------------------------------------------------------- //
// Address calculation

// End-of-line occurs on the final pixel of the line. Otherwise, on
// Start-of-Frame, reset value of 'b1, as the first slot is set below.
assign addr_clr = (push_i | pop_i) & eol_i;
assign addr_w = addr_clr ? 'b0 : (addr_r + 'b1);
assign addr_en = (addr_clr | advance_push | advance_pop);

// ------------------------------------------------------------------------- //
// SRAM control signals.

// Chip-enable signals for SRAMs.
assign ce = (advance_push | advance_pop);

// Read-not-write signals for SRAMs.
assign rnw = advance_pop;

// ------------------------------------------------------------------------- //
// SRAM pipelining.
assign pop_pipe_w = '{dout_vld: advance_pop, pop: pop_i, eol: eol_i};

// ------------------------------------------------------------------------- //
// SRAM instances.

generic_sram #(
  .WORD_W          (SRAM_W)
, .WORDS_N         (SRAM_WORDS_N)
) u_generic_sram (
  .ce              (ce)
, .addr            (addr_r)
, .din             (word_din)
, .rnw             (rnw)
, .dout            (dout)
, .clk             (clk)
);
  
// ------------------------------------------------------------------------- //
// SRAM skid buffer

// Skid is always latched regardless of downstream backpressure as
// state is stored by the skid flops.
assign skid_en = pop_pipe_r.dout_vld;
assign skid_w = dout;

// Skid becomes valid whenever (1) it is loaded from SRAM. It remains
// valid when (2) stalled or when not reading the last pixel.
assign skid_vld_pre =
    pop_pipe_r.dout_vld
  | skid_vld_r & (~pop_pipe_r.pop | ~skid_sel_r[PIXELS_PER_WORD_N - 1]);

assign skid_vld_kill =
  skid_vld_r & pop_pipe_r.pop & pop_pipe_r.eol;

assign skid_vld_w = skid_vld_pre & (~skid_vld_kill);

// Skid selection logic is loaded on skid enable. It is shifted
// whenever valid and there is no stall.
assign skid_sel_en = pop_pipe_r.dout_vld | (skid_vld_r & pop_pipe_r.pop);

// On skid load (1) select first pixel for next cycle if currently
// stalled otherwise select second pixel, otherwise (2) shift selection
// to next pixel.
//
assign skid_sel_w = 
    pop_pipe_r.dout_vld
  ? ( pop_pipe_r.pop ? 'b10 : 'b01)                                // (1)
  : {skid_sel_r[PIXELS_PER_WORD_N-2:0], 1'b0};                     // (2)

// Mux out selected pixel.
mux #(.N(PIXELS_PER_WORD_N), .W(conv_pkg::PIXEL_W)) u_skid_mux (
  .x_i             (skid_r)
, .sel_i           (skid_sel_r)
, .y_o             (skid_demux)
);

// Bypass skid whenever it is not valid. Expectation is data is available
// at the SRAM output directly.
assign skid_demux_bypass = skid_en;

// On bypass, first pixel arrives from SRAM output directly.
assign colD_w =
  skid_demux_bypass ? dout[conv_pkg::PIXEL_W - 1:0] : skid_demux;

//
assign colD_en = pop_i & (skid_en | skid_vld_r);

// ========================================================================= //
//                                                                           //
// Outputs                                                                   //
//                                                                           //
// ========================================================================= //

assign colD_o = colD_r;

endmodule : conv_cntrl_lb_asic

`define FLOPS_UNDEF
`include "flops.svh"
`undef FLOPS_UNDEF
