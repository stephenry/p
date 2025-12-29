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

#include "tb/tb.h"

#include <algorithm>
#include <vector>

#include "tb/project.h"
#include "v/Vtb_seqgen_case.h"
#include "v/Vtb_seqgen_pla.h"

namespace {

struct TestCase {
  std::string name;
  std::size_t coord_y;
  std::size_t coord_x;
};

struct Coord {
  std::size_t coord_y;
  std::size_t coord_x;
};

template <typename T>
concept VSeqGenModule = requires(T t) {
  // Module evaluation method
  { t.eval() } -> std::same_as<void>;

  // Control signals
  t.start_i;
  t.w_i;
  t.h_i;

  t.coord_y_o;
  t.coord_x_o;
  t.busy_o;
  t.done_o;

  // Generic synchronous ports
  t.clk;
  t.arst_n;
};

struct SeqGenTestbenchInterface {
  // Slave interface

  virtual bool testcase_done() const noexcept = 0;

  virtual TestCase testcase_next() = 0;

  virtual void testcase_pop() = 0;

  virtual void testcase_add(const TestCase& tc) = 0;
};

class SeqGenTestCasesBase : public tb::GenericSynchronousTest {
 public:
  explicit SeqGenTestCasesBase(const std::string& args)
      : tb::GenericSynchronousTest(args) {}

  void add_testcase(const TestCase& tc) { test_cases_.push_back(tc); }

  void init(tb::ProjectInstanceBase* base) override {
    std::reverse(test_cases_.begin(), test_cases_.end());

    SeqGenTestbenchInterface* intf{cast_interface(base)};
    for (const TestCase& tc : test_cases_) {
      intf->testcase_add(tc);
    }
  }

 private:
  SeqGenTestbenchInterface* cast_interface(tb::ProjectInstanceBase* instance) {
    SeqGenTestbenchInterface* intf =
      dynamic_cast<SeqGenTestbenchInterface*>(instance);
    if (!intf) {
      throw std::runtime_error(
        "ProjectInstanceBase is not of type SeqGenTestbenchInterface");
    }
    return intf;
  }
  std::vector<TestCase> test_cases_;
};

template <VSeqGenModule UUT>
class SeqGenTestbench final : public tb::GenericSynchronousProjectInstance<UUT>,
                              public SeqGenTestbenchInterface {
 public:
  using base_type = tb::GenericSynchronousProjectInstance<UUT>;

  explicit SeqGenTestbench()
      : tb::GenericSynchronousProjectInstance<UUT>("SeqGenTestbench") {}

  virtual ~SeqGenTestbench() = default;

  void run(tb::ProjectTestBase* test) override {
    while (!testcase_done()) {
      // Next testcase
      const TestCase& tc{testcase_next()};

      // Run testcase
      run_testcase(tc);

      // Discard test
      testcase_pop();
    }
  }

 private:
  void run_testcase(const TestCase& tc) {
    // Reset instance
    this->perform_reset_sequence();

    // Start test
    start(true);
    last(tc);
    this->step_cycles_n(1);
    start(false);

    std::size_t timeout_cycles = 1000;
    std::vector<Coord> actual;
    while (!done()) {
      if (!busy()) {
        // Expect busy to be asserted
      }

      if (actual.size()) {
        // Busy never reached.
      }

      actual.push_back(coord());
      this->step_cycles_n(1);

      if (--timeout_cycles == 0) break;
    }

    // Cool-down period.
    for (std::size_t i = 0; i < 10; i++) {
      if (!done()) {
        // Expect done to remain asserted.
      }

      if (busy()) {
        // Expect busy to be deasserted.
      }
      this->step_cycles_n();
    }

    // Test complete!
  }

  void testcase_add(const TestCase& tc) override { test_cases_.push_back(tc); }

  bool testcase_done() const noexcept override { return test_cases_.empty(); }

  TestCase testcase_next() override {
    if (test_cases_.empty()) {
      throw std::runtime_error("No more test cases available");
    }
    return test_cases_.back();
  }

  void testcase_pop() override { test_cases_.pop_back(); }

  // Ports
  void start(bool v) noexcept { this->uut()->start_i = tb::vsupport::to_v(v); }
  void last(const TestCase& tc) noexcept {
    this->uut()->w_i = tc.coord_y;
    this->uut()->h_i = tc.coord_x;
  }
  Coord coord() const noexcept {
    Coord c{};
    c.coord_y = static_cast<std::size_t>(this->uut()->coord_y_o);
    c.coord_x = static_cast<std::size_t>(this->uut()->coord_x_o);
    return c;
  }

  bool busy() const noexcept {
    return tb::vsupport::from_v<bool>(this->uut()->busy_o);
  }

  bool done() const noexcept {
    return tb::vsupport::from_v<bool>(this->uut()->done_o);
  }

  std::size_t cycle() override {
    return tb::GenericSynchronousProjectInstance<UUT>::cycle();
  }

  SeqGenTestbenchInterface* cast_interface(tb::ProjectInstanceBase* instance) {
    SeqGenTestbenchInterface* intf =
      dynamic_cast<SeqGenTestbenchInterface*>(instance);
    if (!intf) {
      throw std::runtime_error(
        "ProjectInstanceBase is not of type SeqGenTestbenchInterface");
    }
    return intf;
  }

  void set_clk(bool v) override { this->uut()->clk = tb::vsupport::to_v(v); }
  void set_rst(bool v) override { this->uut()->arst_n = tb::vsupport::to_v(v); }

 private:
  std::vector<TestCase> test_cases_;
};

class SeqGenTestCases final : public SeqGenTestCasesBase {
 public:
  explicit SeqGenTestCases(const std::string& args)
      : SeqGenTestCasesBase(args) {
    test_cases_ = {{"3x3", 3, 3}, {"4x4", 4, 4}, {"7x7", 7, 7}};
    for (const TestCase& tc : test_cases_) {
      add_testcase(tc);
    }
  }

 private:
  std::vector<TestCase> test_cases_;
};

}  // namespace

namespace projects::seqgen {

void register_project() {
  TB_PROJECT_CREATE(seqgen);

  // Verilog case statement implementation
  TB_PROJECT_ADD_INSTANCE(seqgen, cfg_case, SeqGenTestbench<Vtb_seqgen_case>);

  // PLA implementation
  TB_PROJECT_ADD_INSTANCE(seqgen, cfg_pla, SeqGenTestbench<Vtb_seqgen_pla>);

  TB_PROJECT_ADD_TEST(seqgen, generic_tester, SeqGenTestCases);
  TB_PROJECT_FINALIZE(seqgen);
}

}  // namespace projects::seqgen
