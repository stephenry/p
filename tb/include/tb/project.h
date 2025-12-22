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
  struct {
    bool reset_async = true;

    bool reset_active_high = false;

  } opts;

 public:
  explicit GenericSynchronousProjectInstance(const std::string& name)
      : ProjectInstanceBase(ProjectInstanceBase::Type::GenericSynchronous,
                            name) {}

  virtual ~GenericSynchronousProjectInstance() = default;

  virtual void elaborate();
  virtual void initialize();
  virtual void run(ProjectTestBase* test);
  virtual void finalize();

 protected:
  virtual void set_clk(bool v) = 0;
  virtual void set_rst(bool v) = 0;

  // Handle to UUT
  UUT* uut() const { return uut_.get(); }

 private:
  // Perform reset sequence
  void perform_reset_sequence();

  // Step n clock cycles (with ticks per cycle)
  void step_cycles_n(std::size_t cycles_n = 1, std::size_t ticks_n = 10);

  std::unique_ptr<UUT> uut_;

  GenericSynchronousTest* test_{nullptr};
};

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::elaborate() {}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::initialize() {
  opts.reset_async = true;
  opts.reset_active_high = false;
  set_clk(false);
  set_rst(!opts.reset_active_high);
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::run(ProjectTestBase* test) {
  GenericSynchronousTest* sync_test =
      dynamic_cast<GenericSynchronousTest*>(test);
  if (!sync_test) {
    // Malformed test case, not of expected type.
    throw std::runtime_error("Test is not of type GenericSynchronousTest");
  }

  perform_reset_sequence();

  // Run main test
  step_cycles_n(1000);
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
      uut_->eval();
    }

    // Falling edge
    set_clk(false);
    for (std::size_t i = 0; i < half_ticks_n; ++i) {
      uut_->eval();
      if (i == 0) {
        // Invoke on_negedge callback
        test_->on_negedge(this);
      }
    }
  }
}

template <typename UUT>
void GenericSynchronousProjectInstance<UUT>::finalize() {}

}  // namespace tb

#endif  // TB_TB_PROJECT_H
