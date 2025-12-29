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

#ifndef TB_TB_PROJECT_H
#define TB_TB_PROJECT_H

#include "tb/tb.h"
#include "vsupport.h"

namespace tb {

class GenericSynchronousTest : public ProjectTestBase {
  template <typename UUT>
  friend class GenericSynchronousProjectInstance;

 protected:
  explicit GenericSynchronousTest(const std::string& args)
      : ProjectTestBase(args) {}

  virtual void on_negedge(ProjectInstanceBase* instance) = 0;

 public:
  virtual ~GenericSynchronousTest() = default;
};

template <typename UUT>
class GenericSynchronousProjectInstance : public ProjectInstanceBase {
 protected:
  enum class State {
    ELABORATION,
    IN_RESET,
    POST_RESET,
    WIND_DOWN,
    FINALIZED,
  };

  struct {
    bool reset_async = true;

    bool reset_active_high = false;
  } opts;

 public:
  explicit GenericSynchronousProjectInstance(const std::string& name);
  virtual ~GenericSynchronousProjectInstance();

  virtual void elaborate() override;
  virtual void initialize() override;
  virtual void run(ProjectTestBase* test) override;
  virtual void finalize() override;
  virtual void eval() override;
  virtual std::size_t cycle();

 protected:
  virtual void set_clk(bool v) = 0;
  virtual void set_rst(bool v) = 0;

  // Handle to UUT
  UUT* uut() const { return uut_.get(); }

 private:
  bool vcd_en_{true};

  // Construct VCD trace
  void construct_trace();

  void destruct_trace();

  void evaluate_timestep();

  // Perform reset sequence
  void perform_reset_sequence();

  // Step n clock cycles (with ticks per cycle)
  void step_cycles_n(std::size_t cycles_n = 1, std::size_t ticks_n = 10);

  std::unique_ptr<UUT> uut_;
  std::unique_ptr<VerilatedContext> uut_ctxt_;
  std::unique_ptr<VerilatedVcdC> uut_vcd_;

  GenericSynchronousTest* test_{nullptr};

  State state_;
};

template <typename UUT>
GenericSynchronousProjectInstance<UUT>::GenericSynchronousProjectInstance(
  const std::string& name)
    : ProjectInstanceBase(ProjectInstanceBase::Type::GenericSynchronous, name) {
}

template <typename UUT>
GenericSynchronousProjectInstance<UUT>::~GenericSynchronousProjectInstance() {
  // Check proper finalization.
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::elaborate() {
  state_ = State::ELABORATION;
  uut_ctxt_ = std::make_unique<VerilatedContext>();
  if constexpr (UUT::traceCapable) {
    uut_ctxt_->traceEverOn(true);
  }
  uut_ = std::make_unique<UUT>(uut_ctxt_.get(), "uut");
  if constexpr (UUT::traceCapable) {
    if (tb_options.enable_waveform_dumping && vcd_en_) {
      construct_trace();
    }
  }
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::evaluate_timestep() {
  uut_ctxt_->timeInc(1);
  uut_->eval();
  if constexpr (UUT::traceCapable) {
    if (tb_options.enable_waveform_dumping && vcd_en_) {
      uut_vcd_->dump(uut_ctxt_->time());
    }
  }
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::construct_trace() {
  uut_vcd_ = std::make_unique<VerilatedVcdC>();
  uut_->trace(uut_vcd_.get(), 99);
  uut_vcd_->open("uut_trace.vcd");
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::destruct_trace() {
  // Allow some window period.

  step_cycles_n(5);

  state_ = State::WIND_DOWN;
  uut_vcd_->close();
  uut_vcd_.reset();
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::initialize() {
  opts.reset_async = true;
  opts.reset_active_high = false;
  set_clk(false);
  set_rst(!opts.reset_active_high);
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::run(ProjectTestBase* test) {
  test_ = dynamic_cast<GenericSynchronousTest*>(test);
  if (!test_) {
    // Malformed test case, not of expected type.
    throw std::runtime_error("Test is not of type GenericSynchronousTest");
  }

  // Perform initialization.
  state_ = State::IN_RESET;
  perform_reset_sequence();

  // Run main test
  state_ = State::POST_RESET;
  step_cycles_n(100);
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::perform_reset_sequence() {
  // Init reset
  set_rst(!opts.reset_active_high);
  step_cycles_n(5);

  // Apply reset
  set_rst(opts.reset_active_high);
  step_cycles_n(5);

  // De-assert reset
  set_rst(!opts.reset_active_high);
  step_cycles_n(5);
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::step_cycles_n(
  std::size_t cycles_n, std::size_t ticks_n) {
  const std::size_t half_ticks_n = ticks_n / 2;

  while (cycles_n--) {
    // Rising edge
    set_clk(true);
    for (std::size_t i = 0; i < half_ticks_n; ++i) {
      evaluate_timestep();
    }

    // Falling edge
    set_clk(false);
    for (std::size_t i = 0; i < half_ticks_n; ++i) {
      evaluate_timestep();
      if (i == 0 && (state_ == State::POST_RESET)) {
        // Invoke on_negedge callback
        test_->on_negedge(this);
      }
    }
  }
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::finalize() {
  // Call UUT finalization blocks.
  uut_->final();

  // Wind-down simulation and close trace if enabled.
  if constexpr (UUT::traceCapable) {
    if (uut_vcd_) {
      destruct_trace();
    }
  }

  // VerilatedContext must be destructed after UUT. If not, the verilated
  // instance crashes specularly during destruction. This could have
  // been enforced by declaring these instances in reverse order, but this is
  // more explicit.
  uut_.reset();
  uut_ctxt_.reset();

  // Advance state to finalized.
  state_ = State::FINALIZED;
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::eval() {
  // Call UUT finalization blocks.
  uut_->eval();
}

template <typename UUT>
std::size_t GenericSynchronousProjectInstance<UUT>::cycle() {
  // Call UUT finalization blocks.
  return uut_->tb_cycle_o;
}

}  // namespace tb

#endif  // TB_TB_PROJECT_H
