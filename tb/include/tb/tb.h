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
#include <memory>
#include <random>
#include <string>
#include <string_view>
#include <tuple>
#include <unordered_map>
#include <vector>

namespace tb {

// Global testbench options
inline struct Options {
  bool enable_waveform_dumping{false};

} tb_options;

#define P_MACRO_BEGIN do {
#define P_MACRO_END \
  }                 \
  while (0)

// clang-format off
#define TB_PROJECT_CREATE(__project_class)                                   \
  class tb_project_create_helper_##__project_class {                         \
   public:                                                                   \
    explicit tb_project_create_helper_##__project_class() {                  \
      tb::PROJECT_REGISTRY.create(#__project_class);                         \
    }                                                                        \
  } __tb_project_create_instance_##__project_class {}
// clang-format on

// clang-format off
#define TB_PROJECT_ADD_INSTANCE(__project_class, __name,                     \
                                __project_instance_class)                    \
  class tb_project_add_instance_helper_##__project_class {                   \
    struct InstanceBuilder : public tb::ProjectInstanceBuilderBase {         \
      std::unique_ptr<tb::ProjectInstanceBase> construct() const override {  \
        return std::unique_ptr<tb::ProjectInstanceBase>(                     \
            new __project_instance_class());                                 \
      }                                                                      \
    };                                                                       \
   public:                                                                   \
    explicit tb_project_add_instance_helper_##__project_class() {            \
      auto p = tb::PROJECT_REGISTRY.lookup(#__project_class);                \
      p->add_instance_builder(#__name, std::make_unique<InstanceBuilder>()); \
    }                                                                        \
  } __tb_project_add_instance_##__project_class {}
// clang-format on

// clang-format off
#define TB_PROJECT_ADD_TEST(__project_class, __name,                         \
     __project_instance_test)                                                \
  class tb_project_add_test_helper_##__project_class {                       \
    struct InstanceBuilder : public tb::ProjectTestBuilderBase {             \
      std::unique_ptr<tb::ProjectTestBase> construct(                        \
          const std::string& args) const override {                          \
        return std::unique_ptr<tb::ProjectTestBase>(                         \
            new __project_instance_test(args));                              \
      }                                                                      \
    };                                                                       \
   public:                                                                   \
    explicit tb_project_add_test_helper_##__project_class() {                \
      auto p = tb::PROJECT_REGISTRY.lookup(#__project_class);                \
      p->add_test_builder(#__name,                                           \
                          std::make_unique<InstanceBuilder>());              \
    }                                                                        \
  } __tb_project_add_test_##__project_class {}
// clang-format on

// clang-format off
#define TB_PROJECT_FINALIZE(__project_class)                                 \
  class tb_project_finalize_helper_##__project_class {                       \
   public:                                                                   \
    explicit tb_project_finalize_helper_##__project_class() {                \
      auto p = tb::PROJECT_REGISTRY.lookup(#__project_class);                \
      p->finalize();                                                         \
    }                                                                        \
  } __tb_project_finalize_helper_##__project_class {}
// clang-format on

// Forwards:
class ProjectTestBase;

class ProjectInstanceBase {
 public:
  enum class Type {
    Default,
    GenericSynchronous,
  };

  explicit ProjectInstanceBase(Type t, const std::string& name) : name_(name) {}
  virtual ~ProjectInstanceBase() = default;

  // Design name
  virtual const std::string& name() const noexcept { return name_; }
  Type type() const noexcept { return t_; }

  virtual void elaborate() {}
  virtual void initialize() {}
  virtual void run(ProjectTestBase* test) {}
  virtual void finalize() {}

 private:
  // Design name.
  std::string name_;
  Type t_;
};

class ProjectInstanceBuilderBase {
 public:
  explicit ProjectInstanceBuilderBase() = default;
  virtual ~ProjectInstanceBuilderBase() = default;

  virtual std::unique_ptr<ProjectInstanceBase> construct() const = 0;
};

class ProjectTestBase {
 public:
  explicit ProjectTestBase(const std::string& args) : args_(args) {}

  virtual ~ProjectTestBase() = default;

  // Design name
  virtual const std::string& args() const noexcept { return args_; }

  virtual void init() {}
  virtual void fini() {}

 private:
  // Test arguments.
  std::string args_;
};

class ProjectTestBuilderBase {
 public:
  explicit ProjectTestBuilderBase() = default;
  virtual ~ProjectTestBuilderBase() = default;

  virtual std::unique_ptr<ProjectTestBase> construct(
      const std::string& args) const = 0;
};

class ProjectBuilderBase {
 public:
  explicit ProjectBuilderBase(const std::string& name) : name_(name) {}

  virtual ~ProjectBuilderBase() = default;

  // Design name
  virtual const std::string& name() const noexcept { return name_; }

  void add_instance_builder(
      const std::string& name,
      std::unique_ptr<ProjectInstanceBuilderBase> builder) {
    instances_.emplace(name, std::move(builder));
  }

  void add_test_builder(const std::string& name,
                        std::unique_ptr<ProjectTestBuilderBase> builder) {
    tests_.emplace(name, std::move(builder));
  }

  void finalize() {}

  ProjectInstanceBuilderBase* lookup_instance_builder(
      const std::string& instance_name);

  ProjectTestBuilderBase* lookup_test_builder(const std::string& test_name);

 private:
  // Design name.
  std::string name_;

  // Associated project instances.
  std::unordered_map<std::string, std::unique_ptr<ProjectInstanceBuilderBase>>
      instances_;

  // Associated project tests.
  std::unordered_map<std::string, std::unique_ptr<ProjectTestBuilderBase>>
      tests_;
};

inline class ProjectRegistry {
 public:
  explicit ProjectRegistry() = default;

  ProjectBuilderBase* lookup(const std::string& name);

  void create(const std::string& name);

 private:
  std::unordered_map<std::string, std::unique_ptr<ProjectBuilderBase>> designs_;

} PROJECT_REGISTRY;

class ProjectInstanceRunner {
 protected:
  explicit ProjectInstanceRunner(ProjectInstanceBase* instance,
                                 ProjectTestBase* test)
      : instance_(instance), test_(test) {};

 public:
  enum class Type {
    Default,
  };

  static std::unique_ptr<ProjectInstanceRunner> Build(
      Type t, ProjectInstanceBase* instance, ProjectTestBase* test);

  virtual ~ProjectInstanceRunner() = default;

  virtual void run() = 0;

 protected:
  ProjectInstanceBase* instance_;
  ProjectTestBase* test_;
};

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

}  // namespace tb

#endif  // TB_TB_H