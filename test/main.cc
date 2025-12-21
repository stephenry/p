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

#include <algorithm>
#include <iostream>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <tuple>
#include <vector>

#include "tb/tb.h"

#define P_TEST_ASSERT(__cond, __msg)

namespace {

struct Job {
  // Project to be run.
  std::string project_name;

  // Specific instance of project to be run.
  std::string instance_name;

  // Specific instance of project to be run.
  std::string test_name;

  // Test to be run on project.
  std::string test_args;
};

class Driver {
  explicit Driver(const std::vector<Job>& jobs);

 public:
  static std::unique_ptr<Driver> from_args(int argc, char** argv);

  int run();

 private:
  void run_job(const Job& job);

  std::vector<Job> jobs_;
};

Driver::Driver(const std::vector<Job>& jobs) : jobs_(jobs) {}

std::unique_ptr<Driver> Driver::from_args(int argc, char** argv) {
  // Parse command line arguments to populate options.
  std::vector<Job> jobs;
  const std::vector<std::string_view> args(argv, argv + argc);

  std::size_t project_name_i, test_name_i, test_arg_i;
  for (std::size_t i = 1; i < args.size(); ++i) {
    if (args[i] == "-p" || args[i] == "--project") {
      // Project name.
      jobs.push_back(Job{});
      Job& current_job{jobs.back()};
      current_job.project_name = args[++i];
    } else if (args[i] == "-i" || args[i] == "--instance") {
      // Test name
      P_TEST_ASSERT(!jobs.empty(), "No prior test defined!");
      P_TEST_ASSERT((i + 1) < args.size(),
                    "Missing argument after -i/--instance");

      Job& current_job{jobs.back()};
      current_job.instance_name = args[++i];
    } else if (args[i] == "-t" || args[i] == "--test") {
      // Test name
      P_TEST_ASSERT(!jobs.empty(), "No prior test defined!");
      P_TEST_ASSERT((i + 1) < args.size(), "Missing argument after -t/--test");

      Job& current_job{jobs.back()};
      current_job.test_name = args[++i];
    } else if (args[i] == "-a" || args[i] == "--args") {
      // Test arguments
      P_TEST_ASSERT(!jobs.empty(), "No prior test defined!");
      P_TEST_ASSERT((i + 1) < args.size(), "Missing argument after -a/--args");

      Job& current_job{jobs.back()};
      current_job.test_args = args[++i];
    } else if (args[i] == "--help" || args[i] == "-h") {
      std::cout << "Usage: testbench [options]\n"
                   "Options:\n"
                   "  -p/--project     \n"
                   "  -t/--test        \n"
                   "  -a/--args        \n"
                   "  --help, -h       Show this help message\n";
      std::exit(EXIT_SUCCESS);
    }
  }

  return std::unique_ptr<Driver>(new Driver(jobs));
}

int Driver::run() {
  for (const Job& job : jobs_) {
    std::cout << "Running project: " << job.project_name << "\n";
    run_job(job);
  }

  // Main testbench run loop
  return 0;
}

void Driver::run_job(const Job& job) {
  // Construct project
  tb::ProjectBuilderBase* project_builder{
      tb::PROJECT_REGISTRY.lookup(job.project_name)};

  // Construct instance (of project)
  std::unique_ptr<tb::ProjectInstanceBuilderBase> instance_builder =
      project_builder->construct_instance(job.instance_name);

  // Construct project instance.
  std::unique_ptr<tb::ProjectInstanceBase> instance{
      instance_builder->construct()};

  // Construct test (with arguments, if present)
  std::unique_ptr<tb::ProjectTestBuilderBase> test_builder =
      project_builder->construct_test(job.test_name);

  // Construct project instance test.
  std::unique_ptr<tb::ProjectTestBase> test{
      test_builder->construct(job.test_args)};

  // Run test on instance.
  std::unique_ptr<tb::ProjectInstanceRunner> runner =
      tb::ProjectInstanceRunner::Build(tb::ProjectInstanceRunner::Type::Default,
                                       instance.get(), test.get());
  runner->run();
}

}  // namespace

int main(int argc, char** argv) {
  try {
    std::unique_ptr<Driver> driver = Driver::from_args(argc, argv);
    return driver->run();
  } catch (const std::exception& e) {
    std::cerr << "Error: " << e.what() << std::endl;
    return EXIT_FAILURE;
  }
}
