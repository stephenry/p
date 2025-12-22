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
, input wire logic                          sof_i
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
// Stall logic.
logic                                       stall;
logic                                       stall_pop;

// ------------------------------------------------------------------------- //
// Address calculations

localparam ADDR_W = $clog2(SRAM_WORDS_N);
typedef logic [ADDR_W-1:0] addr_t;

logic                                       addr_en;
`P_DFFE(addr_t, addr, addr_en, clk);
logic [1:0]                                 wen;
logic [1:0]                                 ren;

// ------------------------------------------------------------------------- //
// Push Path

logic [PIXELS_PER_WORD_N-2:0]               word_en;
conv_pkg::pixel_t [PIXELS_PER_WORD_N-2:0]   word_w;
conv_pkg::pixel_t [PIXELS_PER_WORD_N-2:0]   word_r;
logic [PIXELS_PER_WORD_N-2:0]               word_vld_w;
logic [PIXELS_PER_WORD_N-2:0]               word_vld_r;
logic [PIXELS_PER_WORD_N-1:0]               word_admit_dat;

localparam logic [PIXELS_PER_WORD_N-1:0] WORD_NEXT_INIT = 'b1;
logic                                       word_next_en;
`P_DFFRE(logic [PIXELS_PER_WORD_N-1:0], word_next, word_next_en,
           WORD_NEXT_INIT, arst_n, clk);

// Final composed word for SRAM interface.
conv_pkg::pixel_t [PIXELS_PER_WORD_N-1:0]  word_din;
logic                                      advance_push;

// ------------------------------------------------------------------------- //
// Pop Path
logic                                      advance_pop;

// ------------------------------------------------------------------------- //
// SRAM bank selection

logic [1:0]                                ce;
logic [1:0]                                rnw;
sram_word_t [1:0]                          dout;

// ------------------------------------------------------------------------- //
// SRAM pipelining

typedef struct packed {
  // Pop bank select
  logic bnk;

  logic dout_vld;
} pop_pipe_t;

logic                                      pop_pipe_en;
`P_DFFR(logic, pop_pipe_vld, 1'b0, arst_n, clk);
`P_DFFE(pop_pipe_t, pop_pipe, pop_pipe_en, clk);

// ------------------------------------------------------------------------- //
// SRAM bank mux.

logic [1:0] dout_bank_mux_sel;

// ------------------------------------------------------------------------- //
// SRAM skid buffer
logic                                      skid_en;
`P_DFFE(sram_word_t, skid, skid_en, clk);
`P_DFFR(logic, skid_vld, 'b0, arst_n, clk);

logic                                      skid_sel_en;
`P_DFFRE(logic [PIXELS_PER_WORD_N-1:0], skid_sel, skid_sel_en, 'b1,
   arst_n, clk);
conv_pkg::pixel_t                          skid_demux;


// ------------------------------------------------------------------------- //
// SRAM bank selection
sram_word_t                                dout_demux;

conv_pkg::pixel_t                          dout_demux_skid;
logic                                      skid_demux_bypass;
logic                                      colD_en;
`P_DFFE(conv_pkg::pixel_t, colD, colD_en, clk);


// ========================================================================= //
//                                                                           //
// Logic                                                                     //
//                                                                           //
// ========================================================================= //

// ------------------------------------------------------------------------- //
// Stall logic.

// Datapath is considered stalled whenever there is no push. Note, a pop
// operation must be concurrent with a push to avoid SRAM collisions.
// Therefore, no additional qualified is required.
assign stall = (push_i == '0);

// ------------------------------------------------------------------------- //
// Push Path

// One-Hot pointer to the next pixel position within the SRAM word.
//
assign word_next_en = (~stall);
assign word_next_w = eol_i ? 'b1 : (word_next_r << 1);

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

  assign word_en[i] = (word_next_r[i] & (~stall));
  assign word_w[i] = dat_i;

  assign word_vld_w[i] = 
     word_vld_r [i] ? (~eol_i) : word_next_r[i] & (~stall);

end: reg_GEN

if (i < (PIXELS_PER_WORD_N - 1)) begin : not_last_GEN

  assign word_admit_dat[i] =
    eol_i & word_next_r[i] & (~word_vld_r[i]);

  assign word_din[i] = word_admit_dat[i] ? dat_i : word_r[i];

end: not_last_GEN
else begin: last_GEN

  assign word_admit_dat[i] = (word_vld_r == '1);

  assign word_din[i] = word_admit_dat[i] ? dat_i : '0;

end: last_GEN

end: din_pack_GEN

// Advance push whenever (1) the datapath is not
// stalled, and (2) either end-of-line is reached or the current word
// being composed is admitted (i.e. full).
assign advance_push =
    (~stall)                                                     // (1)
  & (eol_i | (word_admit_dat != 'b0));                           // (2)

// ------------------------------------------------------------------------- //
// Pop path

// Advance pop whenever (1) there is a pop request, (2) the datapath is not
// stalled, and (3) the skid buffer is not full or the skid buffer is
// being drained and is reading the last pixel.
assign advance_pop = 
    pop_i                                                        // (1)
  & (~stall)                                                     // (2)
  & (~skid_vld_r | skid_sel_r[PIXELS_PER_WORD_N - 1]);           // (3)

// ------------------------------------------------------------------------- //
// Address calculation

// End-of-line occurs on the final pixel of the line. Otherwise, on
// Start-of-Frame, reset value of 'b1, as the first slot is set below.
assign addr_w = eol_i ? 'b0 : (addr_r + 'b1);
assign addr_en = advance_push;

// ------------------------------------------------------------------------- //
// Bank selection logic.

// Bank selection is relative to the write port. It is the next bank
// to be written on subsequent pushes. Pops take place from the opposite
// bank. This assumes that the alternate bank has been previously filled.

// Bank selection flop.
logic                             bank_sel_en;
`P_DFFRE(logic, bank_sel, bank_sel_en, 'b0, clk, arst_n);

assign bank_sel_en = (~stall) & eol_i;
assign bank_sel_w = ~bank_sel_r;

// ------------------------------------------------------------------------- //
// SRAM control signals.

// Upto 1 write supported per cycle.
assign wen[1] = ( bank_sel_r & advance_push) ? push_i : 1'b0;
assign wen[0] = (~bank_sel_r & advance_push) ? push_i : 1'b0;

assign ren[1] = (~bank_sel_r & advance_pop) ? pop_i : 1'b0;
assign ren[0] = ( bank_sel_r & advance_pop) ? pop_i : 1'b0;
// Chip-enable signals for SRAMs.
assign ce[1] = ( bank_sel_r ? (wen[1] | ren[1]) : 1'b0);
assign ce[0] = (~bank_sel_r ? (wen[0] | ren[0]) : 1'b0);

// Read-not-write signals for SRAMs.
assign rnw[1] = ( bank_sel_r ? ~wen[1] : '1);
assign rnw[0] = (~bank_sel_r ? ~wen[0] : '1);

// ------------------------------------------------------------------------- //
// SRAM pipelining.

assign pop_pipe_en = advance_pop;
assign pop_pipe_w = '{bnk : bank_sel_r, dout_vld: (ren != '0)};

// ------------------------------------------------------------------------- //
// SRAM instances.

// Generic ASIC SRAM bank style. Ping-Pong buffer implementation to implement
// dual-ported concurrent read/write functionality.

for (genvar bnk = 0; bnk < 2; bnk++) begin: bank_GEN

generic_sram #(
  .WORD_W          (SRAM_W)
, .WORDS_N         (SRAM_WORDS_N)
) u_generic_sram (
  .ce              (ce[bnk])
, .addr            (addr_r)
, .din             (word_din)
, .rnw             (rnw[bnk])
, .dout            (dout[bnk])
);

end: bank_GEN

// ------------------------------------------------------------------------- //
// SRAM bank mux.

assign dout_bank_mux_sel = pop_pipe_r.bnk ? 2'b10 : 2'b01;

mux #(.N(2), .W(SRAM_W)) u_dout_bank_mux (
  .x_i             (dout)
, .sel_i           (dout_bank_mux_sel)
, .y_o             (dout_demux)
);
  
// ------------------------------------------------------------------------- //
// SRAM skid buffer

// Qualified pop stall signal asserted only whenever a pop operation is
// present.
assign stall_pop = stall & pop_pipe_vld_r;

// Skid is always latched regardless of downstream backpressure as
// state is stored by the skid flops.
assign skid_en = pop_pipe_vld_r & pop_pipe_r.dout_vld;
assign skid_w = dout_demux;

// Skid becomes valid whenever (1) it is loaded from SRAM. It remains
// valid when (2) stalled or when not reading the last pixel.
assign skid_vld_w =
    skid_en                                                        // (1)
  | skid_vld_r & (stall_pop | ~skid_sel_r[PIXELS_PER_WORD_N - 1]); // (2)

// Skid selection logic is loaded on skid enable. It is shifted
// whenever valid and there is no stall.
assign skid_sel_en = skid_en | (skid_vld_r & ~stall_pop);

// On skid load (1) select first pixel for next cycle if currently
// stalled otherwise select second pixel, otherwise (2) shift selection
// to next pixel.
//
assign skid_sel_w = 
    skid_en
  ? (stall_pop ? 'b01 : 'b10)                                      // (1)
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
  skid_demux_bypass ? dout_demux[conv_pkg::PIXEL_W - 1:0] : skid_demux;

//
assign colD_en = (~stall_pop) & (skid_en | skid_vld_r);

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
