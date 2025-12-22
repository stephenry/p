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
};

template <typename T>
struct SlaveInterfaceIn {
  bool tvalid;
  T tdata;
  bool tlast;  // End-Of-Line (EOL)
  bool tuser;  // Start-Of-Frame (SOF)
};

struct SlaveInterfaceOut {
  bool tvalid;
  bool tready;
};

template <typename T, std::size_t N>
struct MasterInterfaceOut {
  bool m_tvalid;
  Kernel<T, N> m_tdata;
};

struct MasterInterfaceIn {
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
    Random,
  };

  explicit FrameGenerator(
    std::size_t width, std::size_t height, Pattern pattern)
      : width_(width), height_(height), pattern_(pattern) {}

  Frame<T> generate() {
    // Populate frame based on pattern
    switch (pattern_) {
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
  // Generate frame with incremental pixel values.
  Frame<T> generate_incremental() {
    T pixel{};
    Frame<T> frame(width_, height_);
    for (std::size_t y = 0; y < height_; ++y) {
      for (std::size_t x = 0; x < width_; ++x) {
        frame.set_pixel(x, y, pixel++);
      }
    }
    return frame;
  }

  // Generate frame with random pixel values.
  Frame<T> generate_random() {
    Frame<T> frame(width_, height_);
    for (std::size_t y = 0; y < height_; ++y) {
      for (std::size_t x = 0; x < width_; ++x) {
        frame.set_pixel(x, y, tb::RANDOM.uniform<T>());
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
    for (std::ptrdiff_t y = 0;
      y <= static_cast<std::ptrdiff_t>(frame_.height());
      ++y) {
      for (std::ptrdiff_t x = 0;
        x <= static_cast<std::ptrdiff_t>(frame_.width());
        ++x) {
        *++it = compute_kernel(y, x);
      }
    }
  }

 private:
  Kernel<T, N> compute_kernel(std::ptrdiff_t y, std::ptrdiff_t x) const {
    Kernel<T, N> kernel{};
    for (std::ptrdiff_t j = 0; j < N; ++j) {
      for (std::ptrdiff_t i = 0; i < N; ++i) {
        kernel.data[j][i] =
          compute_pixel((y + j - kernel.offset()), (x + i - kernel.offset()));
      }
    }
    return kernel;
  }

  T compute_pixel(std::ptrdiff_t y, std::ptrdiff_t x) const {
    // Handle boundary conditions based on extend strategy
    if (y < 0 || y >= static_cast<std::ptrdiff_t>(frame_.height()) || x < 0 ||
        x >= static_cast<std::ptrdiff_t>(frame_.width())) {
      switch (extend_strategy_) {
        case ExtendStrategy::ZeroPad:
          return T{0};
        case ExtendStrategy::Replicate:
          // TODO
          break;
      }
    }
    return frame_.get_pixel(x, y);
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

  virtual void s_in(const SlaveInterfaceIn<vluint8_t>& in) noexcept = 0;
  virtual SlaveInterfaceOut s_out() const noexcept = 0;

  virtual MasterInterfaceOut<vluint8_t, 5> m_out() const noexcept = 0;
  virtual void m_in(const MasterInterfaceIn& in) noexcept = 0;
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
 public:
  explicit ConvTestDriver(const std::string& args)
      : tb::GenericSynchronousTest(args) {}

  virtual ~ConvTestDriver() = default;

  void init() override {
    frame_ = next_frame();
    frame_tx_.init(std::addressof(*frame_));
  }

  void fini() override {
    // Finalization code here.
  }

  // Override to provide next frame to be processed.
  virtual Frame<vluint8_t> next_frame() = 0;

  void on_negedge(tb::ProjectInstanceBase* instance) override {
    ConvTestbenchInterface* intf =
      dynamic_cast<ConvTestbenchInterface*>(instance);
    if (!intf) {
      throw std::runtime_error(
        "ProjectInstanceBase is not of type ConvTestbenchInterface");
    }
    on_negedge_internal(intf);
  }

 private:
  void on_negedge_internal(ConvTestbenchInterface* intf) {
    // Evaluate TB -> UUT interface
    on_negedge_internal_in(intf);

    // Evaluate UUT -> TB interface
    on_negedge_internal_out(intf);
  }

  void on_negedge_internal_in(ConvTestbenchInterface* intf) {
    // Consume pixel if accepted
    const SlaveInterfaceOut s_in{intf->s_out()};
    if (s_in.tvalid && s_in.tready) {
      frame_tx_.advance();
    }

    if (frame_tx_.frame_exhausted()) {
      // Obtain next frame from child.
      frame_ = next_frame();
      frame_tx_.init(std::addressof(*frame_));

      // Compute expected convolutions.
      ConvolutionEngine<vluint8_t, 5> ceng{*frame_};
      ceng.generate(std::back_inserter(expected_));
    }

    intf->s_in(frame_tx_.next());
  }

  void on_negedge_internal_out(ConvTestbenchInterface* intf) {
    // Check Master (out) interface
    const bool apply_backpressure = false;
    intf->m_in(MasterInterfaceIn{!apply_backpressure});

    const MasterInterfaceOut<vluint8_t, 5> m_out{intf->m_out()};
    if (m_out.m_tvalid && apply_backpressure) {
      return;
    }

    // Otherwise, consume and validate output kernel.
    // const Kernel<vluint8_t, 5> expected_kernel{expected_.front()};
    // expected_.pop_front();

    // TODO: comparison code.
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

  void s_in(const SlaveInterfaceIn<vluint8_t>& in) noexcept override {
    uut()->s_tvalid_i = tb::vsupport::to_v(in.tvalid);
    uut()->s_tdata_i = in.tdata;
    uut()->s_tlast_i = tb::vsupport::to_v(in.tlast);
    uut()->s_tuser_i = tb::vsupport::to_v(in.tuser);
  }

  SlaveInterfaceOut s_out() const noexcept override {
    SlaveInterfaceOut out{};
    out.tvalid = tb::vsupport::from_v<bool>(uut()->s_tvalid_i);
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

  void m_in(const MasterInterfaceIn& in) noexcept override {
    uut()->m_tready_i = tb::vsupport::to_v(in.m_tready);
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
      16, 16, FrameGenerator<vluint8_t>::Pattern::Incremental);
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
