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
#include "tb/project.h"

#include <algorithm>
#include <memory>

namespace {

// Forwards:
template<typename T> class FrameGenerator;

template<typename T>
class Frame {
  friend class FrameGenerator<T>;

  explicit Frame(std::size_t width, std::size_t height)
      : width_(width), height_(height) {
    data_.resize(width * height);
    std::fill(data_.begin(), data_.end(), T{});
  }

  void set_pixel(std::size_t x, std::size_t y, uint8_t value) noexcept {
    data_[y * width() + x] = value;
  }

public:

  std::size_t width() const noexcept { return width_; }
  std::size_t height() const noexcept { return height_; }

  uint8_t get_pixel(std::size_t x, std::size_t y) const noexcept {
    return data_[y * width() + x];
  }

private:
  std::size_t width_;
  std::size_t height_;
  
  std::vector<T> data_;
};

template<typename T>
class FrameGenerator {
public:
  
  enum class Pattern {
    Incremental,
    Random,
  };

  explicit FrameGenerator(std::size_t width, std::size_t height, Pattern pattern)
      : width_(width), height_(height), pattern_(pattern)
  {}

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
    return {};
  }

private:
  // Generate frame with incremental pixel values.
  Frame<T> generate_incremental() {
    Frame<T> frame(width_, height_);
    for (std::size_t y = 0; y < height_; ++y) {
      for (std::size_t x = 0; x < width_; ++x) {
        frame.set_pixel(x, y, static_cast<T>(y * width_ + x));
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

template<typename T, std::size_t N>
class ConvolutionEngine {
public:
  enum class ExtendStrategy {
    ZeroPad,
    Replicate,
  };

  struct ConvKernel {
    constexpr static std::size_t size() noexcept { return N; }
    constexpr static std::ptrdiff_t offset() noexcept { return  (N / 2); }


    T data[N][N];
  };

  explicit ConvolutionEngine(const Frame<T>& frame, ExtendStrategy extend_strategy)
      : frame_(frame), extend_strategy_(extend_strategy)
  {}

  std::vector<ConvKernel> generate() const {
    std::vector<ConvKernel> k;
    for (std::ptrdiff_t y = 0; y <= static_cast<std::ptrdiff_t>(frame_.height()); ++y) {
      for (std::ptrdiff_t x = 0; x <= static_cast<std::ptrdiff_t>(frame_.width()); ++x) {
        k.push_back(ConvKernel{});
        compute_kernel(k.back(), y, x);
      }
    }
    return k;
  }

private:
  void compute_kernel(ConvKernel &kernel, std::ptrdiff_t y, std::ptrdiff_t x) const {
    for (std::ptrdiff_t j = 0; j < N; ++j) {
      for (std::ptrdiff_t i = 0; i < N; ++i) {
        kernel.data[j][i] = compute_pixel(
          (y + j - kernel.offset()), (x + i - kernel.offset()));
      }
    }
  }

  T compute_pixel(std::ptrdiff_t y, std::ptrdiff_t x) const {
    // Handle boundary conditions based on extend strategy
    if (y < 0 || y >= static_cast<std::ptrdiff_t>(frame_.height()) ||
        x < 0 || x >= static_cast<std::ptrdiff_t>(frame_.width())) {
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

template<VConvModule UUT>
class ConvTestbench : public tb::GenericSynchronousProjectInstance {
public:

  template<typename T, std::size_t N>
  struct Kernel;

  template<>
  struct Kernel<vluint8_t, 5> {
    uint8_t data[5][5];

    static Kernel<vluint8_t, 5> from_uut(UUT* uut) {
      Kernel<vluint8_t, 5> k{};
      k.data[0][0] = uut->m_tdata_0_0_o;
      k.data[0][1] = uut->m_tdata_0_1_o;
      k.data[0][2] = uut->m_tdata_0_2_o;
      k.data[0][3] = uut->m_tdata_0_3_o;
      k.data[0][4] = uut->m_tdata_0_4_o;
      k.data[1][0] = uut->m_tdata_1_0_o;
      k.data[1][1] = uut->m_tdata_1_1_o;
      k.data[1][2] = uut->m_tdata_1_2_o;
      k.data[1][3] = uut->m_tdata_1_3_o;
      k.data[1][4] = uut->m_tdata_1_4_o;
      k.data[2][0] = uut->m_tdata_2_0_o;
      k.data[2][1] = uut->m_tdata_2_1_o;
      k.data[2][2] = uut->m_tdata_2_2_o;
      k.data[2][3] = uut->m_tdata_2_3_o;
      k.data[2][4] = uut->m_tdata_2_4_o;
      k.data[3][0] = uut->m_tdata_3_0_o;
      k.data[3][1] = uut->m_tdata_3_1_o;
      k.data[3][2] = uut->m_tdata_3_2_o;
      k.data[3][3] = uut->m_tdata_3_3_o;
      k.data[3][4] = uut->m_tdata_3_4_o;
      k.data[4][0] = uut->m_tdata_4_0_o;
      k.data[4][1] = uut->m_tdata_4_1_o;
      k.data[4][2] = uut->m_tdata_4_2_o;
      k.data[4][3] = uut->m_tdata_4_3_o;
      k.data[4][4] = uut->m_tdata_4_4_o;
      return k;
    };
  };

  template<typename T>
  struct SlaveInterface {
    bool tvalid;
    T tdata;
    bool tlast;
    bool tuser;
    bool tready;

    static SlaveInterface from_uut(UUT* uut) {
      SlaveInterface si{};
      si.tvalid = uut->s_tvalid_i;
      si.tdata  = uut->s_tdata_i;
      si.tlast  = uut->s_tlast_i;
      si.tuser  = uut->s_tuser_i;
      si.tready = uut->s_tready_o;
      return si;
    }

  };

  explicit ConvTestbench()
      : tb::GenericSynchronousProjectInstance("ConvTestbench") {

    // Construct UUT
    uut_ = std::make_unique<UUT>();

    // Connect clock and reset ports
    ports.clk_ = &uut_->clk;
    ports.rst_ = &uut_->arst_n;
  }

  virtual ~ConvTestbench() = default;

  void initialize() override {}
  void finalize() override {}


private:
  std::unique_ptr<UUT> uut_;
};

class BasicIncrementConvTest : public tb::ProjectTestBase {
public:
  explicit BasicIncrementConvTest()
      : ProjectTestBase("BasicIncrementConvTest") {}
};

} // namespace


TB_PROJECT_CREATE(conv);

#include "v/Vtb_asic_zeropad.h"
TB_PROJECT_ADD_INSTANCE(conv, "tb_asic_zeropad", ConvTestbench<Vtb_asic_zeropad>);

TB_PROJECT_ADD_TEST(conv, BasicIncrementConvTest);

TB_PROJECT_FINALIZE(conv);


int foo() {
  return 42;
}
