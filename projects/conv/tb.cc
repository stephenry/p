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
#include <deque>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <memory>
#include <optional>

#include "tb/project.h"
#include "tb/vsupport.h"

// instances
#include "v/Vtb_asic_zeropad.h"

namespace {

// Forwards:
template <typename T>
class FrameGenerator;

template <typename T, std::size_t N>
struct Kernel {
  static_assert(N % 2 == 1, "Kernel size N must be odd.");

  using value_type = T;

  constexpr static std::size_t size() noexcept { return N; }
  constexpr static std::ptrdiff_t offset() noexcept { return (N / 2); }

  T data[N][N];

  void os(std::ostream& os) const;
};

template <typename T, std::size_t N>
void Kernel<T, N>::os(std::ostream& os) const {
  for (std::size_t j = size(); j > 0; --j) {
    for (std::size_t i = size(); i > 0; --i) {
      os << std::setw(2) << std::hex
         << static_cast<uint32_t>(data[j - 1][i - 1]) << ' ';
    }
    os << '\n';
  }
}

template <typename T, std::size_t N>
bool equal(const Kernel<T, N>& lhs, const Kernel<T, N>& rhs) {
  for (std::size_t j = 0; j < lhs.size(); ++j) {
    for (std::size_t i = 0; i < lhs.size(); ++i) {
      if (lhs.data[j][i] != rhs.data[j][i]) {
        return false;
      }
    }
  }
  return true;
}

template <typename T>
struct SlaveInterfaceIn {
  explicit SlaveInterfaceIn() {
    tvalid = false;
    tdata = T{0};
    tlast = false;
    tuser = false;
  }
  bool tvalid;
  T tdata;
  bool tlast;  // End-Of-Line (EOL)
  bool tuser;  // Start-Of-Frame (SOF)
};

struct SlaveInterfaceOut {
  bool tready;
};

template <typename T, std::size_t N>
struct MasterInterfaceOut {
  bool m_tvalid;
  Kernel<T, N> m_tdata;
};

struct MasterInterfaceIn {
  explicit MasterInterfaceIn() { m_tready = true; }
  explicit MasterInterfaceIn(bool tready) { m_tready = tready; }

  bool m_tready;
};

template <typename T>
class Frame {
  friend class FrameGenerator<T>;

  explicit Frame(std::size_t width, std::size_t height)
      : width_(width), height_(height) {
    data_.resize(width * height);
    std::fill(data_.begin(), data_.end(), T{});
  }

  void set_pixel(std::size_t y, std::size_t x, uint8_t value) noexcept {
    data_[y * width() + x] = value;
  }

 public:
  std::size_t width() const noexcept { return width_; }
  std::size_t height() const noexcept { return height_; }

  uint8_t get_pixel(std::size_t y, std::size_t x) const noexcept {
    return data_[y * width() + x];
  }

 private:
  std::size_t width_;
  std::size_t height_;

  std::vector<T> data_;
};

template <typename T>
class FrameGenerator {
 public:
  enum class Pattern {
    Incremental,
    ByRow,
    ByCol,
    Random,
  };

  explicit FrameGenerator(
    std::size_t width, std::size_t height, Pattern pattern)
      : width_(width), height_(height), pattern_(pattern) {}

  Frame<T> generate() {
    // Populate frame based on pattern
    switch (pattern_) {
      case Pattern::ByRow:
        // Fill frame with row-based values
        return generate_by(true);
        break;
      case Pattern::ByCol:
        // Fill frame with row-based values
        return generate_by(false);
        break;
      case Pattern::Incremental:
        // Fill frame with incremental values
        return generate_incremental();
        break;
      case Pattern::Random:
        // Fill frame with random values
        return generate_random();
        break;
    }
    throw std::runtime_error("Unknown frame pattern");
  }

 private:
  Frame<T> generate_by(bool row = true) {
    T pixel{};
    Frame<T> frame(width_, height_);
    for (std::size_t y = 0; y < height_; ++y) {
      for (std::size_t x = 0; x < width_; ++x) {
        frame.set_pixel(y, x, row ? y : x);
      }
    }
    return frame;
  }

  // Generate frame with incremental pixel values.
  Frame<T> generate_incremental() {
    T pixel{};
    Frame<T> frame(width_, height_);
    for (std::size_t y = 0; y < height_; ++y) {
      for (std::size_t x = 0; x < width_; ++x) {
        frame.set_pixel(y, x, pixel++);
      }
    }
    return frame;
  }

  // Generate frame with random pixel values.
  Frame<T> generate_random() {
    Frame<T> frame(width_, height_);
    for (std::size_t y = 0; y < height_; ++y) {
      for (std::size_t x = 0; x < width_; ++x) {
        frame.set_pixel(y, x, tb::RANDOM.uniform<T>());
      }
    }
    return frame;
  }

  std::size_t width_;
  std::size_t height_;
  Pattern pattern_;
};

template <typename T, std::size_t N>
class ConvolutionEngine {
 public:
  enum class ExtendStrategy {
    ZeroPad,
    Replicate,
  };

  explicit ConvolutionEngine(const Frame<T>& frame,
    ExtendStrategy extend_strategy = ExtendStrategy::ZeroPad)
      : frame_(frame), extend_strategy_(extend_strategy) {}

  template <typename FwdIt>
  void generate(FwdIt it) const {
    for (std::size_t y = 0; y < frame_.height(); ++y) {
      for (std::size_t x = 0; x < frame_.width(); ++x) {
        *++it = compute_kernel(y, x);
      }
    }
  }

 private:
  Kernel<T, N> compute_kernel(std::size_t y, std::size_t x) const {
    Kernel<T, N> kernel{};
    for (std::size_t j = 0; j < N; ++j) {
      for (std::size_t i = 0; i < N; ++i) {
        const int kernel_y = static_cast<int>(y) + static_cast<int>(j) -
                             static_cast<int>(Kernel<T, N>::offset());
        const int kernel_x = static_cast<int>(x) + static_cast<int>(i) -
                             static_cast<int>(Kernel<T, N>::offset());

        const std::size_t jj = Kernel<T, N>::size() - j - 1;
        const std::size_t ii = Kernel<T, N>::size() - i - 1;
        kernel.data[jj][ii] = compute_pixel(kernel_y, kernel_x);
      }
    }
    return kernel;
  }

  T compute_pixel(int y, int x) const {
    // Handle boundary conditions based on extend strategy
    if ((y < 0 || y >= static_cast<int>(frame_.height())) ||
        (x < 0 || x >= static_cast<int>(frame_.width()))) {
      switch (extend_strategy_) {
        case ExtendStrategy::ZeroPad:
          return T{0};
        case ExtendStrategy::Replicate:
          // TODO
          break;
      }
    }
    return frame_.get_pixel(y, x);
  }

  const Frame<T>& frame_;
  ExtendStrategy extend_strategy_;
};

template <typename T>
concept VConvModule = requires(T t) {
  // Module evaluation method
  { t.eval() } -> std::same_as<void>;

  // Slave interface ports
  t.s_tvalid_i;
  t.s_tdata_i;
  t.s_tlast_i;
  t.s_tuser_i;
  t.s_tready_o;

  // Master interface ports
  t.m_tready_i;
  t.m_tvalid_o;

  // Module parameterizations
  t.cfg_target_o;
  t.cfg_extend_strategy_o;

  // Generic synchronous ports
  t.clk;
  t.arst_n;
};

struct ConvTestbenchInterface {
  virtual ~ConvTestbenchInterface() = default;

  virtual void s_idle() noexcept { s_in(SlaveInterfaceIn<vluint8_t>{}); }
  virtual SlaveInterfaceIn<vluint8_t> s_in() const noexcept = 0;
  virtual void s_in(const SlaveInterfaceIn<vluint8_t>& in) noexcept = 0;
  virtual SlaveInterfaceOut s_out() const noexcept = 0;

  virtual void m_idle() noexcept { m_in(MasterInterfaceIn{}); }
  virtual MasterInterfaceIn m_in() const noexcept = 0;
  virtual void m_in(const MasterInterfaceIn& in) noexcept = 0;
  virtual MasterInterfaceOut<vluint8_t, 5> m_out() const noexcept = 0;

  virtual void eval() = 0;
  virtual std::size_t cycle() = 0;
};

class FrameTransactor {
 public:
  explicit FrameTransactor() { init(); }
  virtual ~FrameTransactor() = default;

  void init(Frame<vluint8_t>* next_frame = nullptr) noexcept {
    pixel_x_ = 0;
    pixel_y_ = 0;
    frame_ = next_frame;
  }

  bool frame_exhausted() const noexcept { return !frame_; }

  SlaveInterfaceIn<vluint8_t> next() {
    SlaveInterfaceIn<vluint8_t> in{};
    in.tvalid = true;
    in.tdata = frame_->get_pixel(pixel_y_, pixel_x_);
    in.tlast = (pixel_x_ == (frame_->width() - 1));
    in.tuser = ((pixel_x_ == 0) && (pixel_y_ == 0));
    return in;
  }

  void advance() noexcept {
    const bool is_col_last = (pixel_x_ == (frame_->width() - 1));
    const bool is_line_last = (pixel_y_ == (frame_->height() - 1));

    if (is_col_last && !is_line_last) {
      // End of line, advance to next row.
      ++pixel_y_;
      pixel_x_ = 0;
    } else if (is_col_last && is_line_last) {
      // Final pixel has been consumed.
      frame_ = nullptr;
    } else {
      // Otherwise, advance to next pixel in current line.
      pixel_x_++;
    }
  }

  std::size_t pixel_y_{0};
  std::size_t pixel_x_{0};
  Frame<vluint8_t>* frame_{nullptr};
};

class ConvTestDriver : public tb::GenericSynchronousTest {
  // Slave interface
  SlaveInterfaceIn<vluint8_t> s_in_;
  SlaveInterfaceOut s_out_;

  // Master interface
  MasterInterfaceIn m_in_;
  MasterInterfaceOut<vluint8_t, 5> m_out_;

 public:
  explicit ConvTestDriver(const std::string& args)
      : tb::GenericSynchronousTest(args) {}

  virtual ~ConvTestDriver() = default;

  void init(tb::ProjectInstanceBase* base) override {
    ConvTestbenchInterface* intf = cast_interface(base);

    // Idle interfaces
    intf->m_idle();
    intf->s_idle();
  }

  void fini(tb::ProjectInstanceBase* base) override {
    // Finalization code here.
  }

  // Override to provide next frame to be processed.
  virtual Frame<vluint8_t> next_frame() = 0;

  void on_negedge(tb::ProjectInstanceBase* instance) override {
    ConvTestbenchInterface* intf = cast_interface(instance);

    // Pixel to be emitted in the current cycle.
    bool emit_pixel = true;

    bool apply_backpressure = tb::RANDOM.random_bool(0.3f);
    // Apply backpressure
    m_in_ = MasterInterfaceIn{!apply_backpressure};
    intf->m_in(m_in_);
    // Combinatorial path between Master to Slave interface
    // requires evaluation of UUT to propagate tready signal.
    intf->eval();

    // Sample outputs
    s_out_ = intf->s_out();
    m_out_ = intf->m_out();

    // Evaluate TB -> UUT interface
    on_negedge_internal_in(intf, emit_pixel, apply_backpressure);

    // Evaluate UUT -> TB interface
    on_negedge_internal_out(intf, apply_backpressure);

    // Drive new inputs
    intf->s_in(s_in_);
  }

 private:
  ConvTestbenchInterface* cast_interface(tb::ProjectInstanceBase* instance) {
    ConvTestbenchInterface* intf =
      dynamic_cast<ConvTestbenchInterface*>(instance);
    if (!intf) {
      throw std::runtime_error(
        "ProjectInstanceBase is not of type ConvTestbenchInterface");
    }
    return intf;
  }

  void on_negedge_internal_in(
    ConvTestbenchInterface* intf, bool emit_pixel, bool apply_backpressure) {
    if (!emit_pixel) {
      // Idle input interface
      s_in_ = SlaveInterfaceIn<vluint8_t>{};
      return;
    }

    if (frame_tx_.frame_exhausted()) {
      // Obtain next frame from child.
      frame_ = next_frame();
      frame_tx_.init(std::addressof(*frame_));

      // Compute expected convolutions.
      ConvolutionEngine<vluint8_t, 5> ceng{*frame_};
      ceng.generate(std::back_inserter(expected_));
    }

    // Provide next pixel to input interface
    s_in_ = frame_tx_.next();

    // Consume pixel if accepted
    if (s_out_.tready) {
      frame_tx_.advance();
    }
  }

  void on_negedge_internal_out(
    ConvTestbenchInterface* intf, bool apply_backpressure) {
    // Check Master (out) interface
    if (!m_out_.m_tvalid || !m_in_.m_tready) {
      return;
    }

    if (m_out_.m_tvalid && expected_.empty()) {
      std::cout << "Received unexpected output kernel:\n";
      m_out_.m_tdata.os(std::cout);
      return;
    }

    if (expected_.empty()) {
      return;
    }

    // Otherwise, consume and validate output kernel.
    if (!equal(m_out_.m_tdata, expected_.front())) {
      std::cout << "Mismatch detected " << std::dec << intf->cycle() << ":\n";
      std::cout << "Received:\n";
      m_out_.m_tdata.os(std::cout);
      std::cout << "Expected:\n";
      expected_.front().os(std::cout);
    } else {
      std::cout << "Kernel match " << std::dec << intf->cycle() << ":\n";
      std::cout << "Received:\n";
      m_out_.m_tdata.os(std::cout);
    }

    expected_.pop_front();
  }

  FrameTransactor frame_tx_;
  std::optional<Frame<vluint8_t>> frame_;
  std::deque<Kernel<vluint8_t, 5>> expected_;
};

template <VConvModule UUT>
class ConvTestbench final : public tb::GenericSynchronousProjectInstance<UUT>,
                            public ConvTestbenchInterface {
 public:
  using base_type = tb::GenericSynchronousProjectInstance<UUT>;

  SlaveInterfaceIn<vluint8_t> s_in() const noexcept override {
    SlaveInterfaceIn<vluint8_t> in{};
    in.tvalid = tb::vsupport::from_v<bool>(uut()->s_tvalid_i);
    in.tdata = uut()->s_tdata_i;
    in.tlast = tb::vsupport::from_v<bool>(uut()->s_tlast_i);
    in.tuser = tb::vsupport::from_v<bool>(uut()->s_tuser_i);
    return in;
  }

  void s_in(const SlaveInterfaceIn<vluint8_t>& in) noexcept override {
    uut()->s_tvalid_i = tb::vsupport::to_v(in.tvalid);
    uut()->s_tdata_i = in.tdata;
    uut()->s_tlast_i = tb::vsupport::to_v(in.tlast);
    uut()->s_tuser_i = tb::vsupport::to_v(in.tuser);
  }

  SlaveInterfaceOut s_out() const noexcept override {
    SlaveInterfaceOut out{};
    out.tready = tb::vsupport::from_v<bool>(uut()->s_tready_o);
    return out;
  }

  MasterInterfaceOut<vluint8_t, 5> m_out() const noexcept override {
    MasterInterfaceOut<vluint8_t, 5> out{};
    out.m_tvalid = tb::vsupport::from_v<bool>(uut()->m_tvalid_o);

    out.m_tdata.data[0][0] = uut()->m_tdata_0_0_o;
    out.m_tdata.data[0][1] = uut()->m_tdata_0_1_o;
    out.m_tdata.data[0][2] = uut()->m_tdata_0_2_o;
    out.m_tdata.data[0][3] = uut()->m_tdata_0_3_o;
    out.m_tdata.data[0][4] = uut()->m_tdata_0_4_o;
    out.m_tdata.data[1][0] = uut()->m_tdata_1_0_o;
    out.m_tdata.data[1][1] = uut()->m_tdata_1_1_o;
    out.m_tdata.data[1][2] = uut()->m_tdata_1_2_o;
    out.m_tdata.data[1][3] = uut()->m_tdata_1_3_o;
    out.m_tdata.data[1][4] = uut()->m_tdata_1_4_o;
    out.m_tdata.data[2][0] = uut()->m_tdata_2_0_o;
    out.m_tdata.data[2][1] = uut()->m_tdata_2_1_o;
    out.m_tdata.data[2][2] = uut()->m_tdata_2_2_o;
    out.m_tdata.data[2][3] = uut()->m_tdata_2_3_o;
    out.m_tdata.data[2][4] = uut()->m_tdata_2_4_o;
    out.m_tdata.data[3][0] = uut()->m_tdata_3_0_o;
    out.m_tdata.data[3][1] = uut()->m_tdata_3_1_o;
    out.m_tdata.data[3][2] = uut()->m_tdata_3_2_o;
    out.m_tdata.data[3][3] = uut()->m_tdata_3_3_o;
    out.m_tdata.data[3][4] = uut()->m_tdata_3_4_o;
    out.m_tdata.data[4][0] = uut()->m_tdata_4_0_o;
    out.m_tdata.data[4][1] = uut()->m_tdata_4_1_o;
    out.m_tdata.data[4][2] = uut()->m_tdata_4_2_o;
    out.m_tdata.data[4][3] = uut()->m_tdata_4_3_o;
    out.m_tdata.data[4][4] = uut()->m_tdata_4_4_o;

    return out;
  }

  MasterInterfaceIn m_in() const noexcept override {
    MasterInterfaceIn in{};
    in.m_tready = tb::vsupport::from_v<bool>(uut()->m_tready_i);
    return in;
  }

  void m_in(const MasterInterfaceIn& in) noexcept override {
    uut()->m_tready_i = tb::vsupport::to_v(in.m_tready);
  }

  void eval() override { tb::GenericSynchronousProjectInstance<UUT>::eval(); }

  std::size_t cycle() override {
    return tb::GenericSynchronousProjectInstance<UUT>::cycle();
  }

  explicit ConvTestbench();
  virtual ~ConvTestbench() = default;

  void elaborate() override;
  void initialize() override;
  void finalize() override;

  void set_clk(bool v) override { uut()->clk = tb::vsupport::to_v(v); }
  void set_rst(bool v) override { uut()->arst_n = tb::vsupport::to_v(v); }

 private:
  UUT* uut() const { return base_type::uut(); }
};

template <VConvModule UUT>
ConvTestbench<UUT>::ConvTestbench()
    : tb::GenericSynchronousProjectInstance<UUT>("ConvTestbench") {}

template <VConvModule UUT>
void ConvTestbench<UUT>::elaborate() {
  base_type::elaborate();
}

template <VConvModule UUT>
void ConvTestbench<UUT>::initialize() {
  base_type::initialize();
}

template <VConvModule UUT>
void ConvTestbench<UUT>::finalize() {
  base_type::finalize();
}

class BasicIncrementConvTest final : public ConvTestDriver {
 public:
  explicit BasicIncrementConvTest(const std::string& args)
      : ConvTestDriver(args) {
    frame_gen_ = std::make_unique<FrameGenerator<vluint8_t>>(
      16, 16, FrameGenerator<vluint8_t>::Pattern::ByRow);
  }

  Frame<vluint8_t> next_frame() override { return frame_gen_->generate(); }

 private:
  std::unique_ptr<FrameGenerator<vluint8_t>> frame_gen_;
};

}  // namespace

namespace projects::conv {

void register_project() {
  TB_PROJECT_CREATE(conv);

  TB_PROJECT_ADD_INSTANCE(
    conv, tb_asic_zeropad, ConvTestbench<Vtb_asic_zeropad>);

  TB_PROJECT_ADD_TEST(conv, basic_increment, BasicIncrementConvTest);

  TB_PROJECT_FINALIZE(conv);
}

}  // namespace projects::conv
