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

#ifndef TB_TB_H
#define TB_TB_H 

#include <limits>
#include <random>

inline class Random {
 public:
  using seed_type = std::mt19937::result_type;

  explicit Random(seed_type s = seed_type{}) { seed(s); }

  // Set seed of randomization engine.
  void seed(seed_type s) { mt_.seed(s); }

  // Generate a random integral type in range [lo, hi]
  template <typename T>
  T uniform(T hi = std::numeric_limits<T>::max(),
            T lo = std::numeric_limits<T>::min()) {
    static_assert(std::is_integral_v<T> || std::is_floating_point_v<T>);
    if constexpr (std::is_integral_v<T>) {
      // Integral type
      std::uniform_int_distribution<T> d(lo, hi);
      return d(mt_);
    } else {
      // Floating-point type
      std::uniform_real_distribution<T> d(lo, hi);
      return d(mt_);
    }
  }

  bool random_bool(float t_prob = 0.5f) {
    std::bernoulli_distribution b(t_prob);
    return b(mt_);
  }

 private:
  std::mt19937 mt_;
} RANDOM;

#endif // TB_TB_H