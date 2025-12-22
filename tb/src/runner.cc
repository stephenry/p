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

#include "tb/project.h"
#include "tb/tb.h"

namespace tb {

class DefaultProjectRunner final : public ProjectInstanceRunner {
 public:
  explicit DefaultProjectRunner(ProjectInstanceBase* instance,
                                ProjectTestBase* test)
      : ProjectInstanceRunner(instance, test) {}

  void run() override;
};

void DefaultProjectRunner::run() {
  // Elaborate model.
  instance_->elaborate();

  // Initialize instance
  instance_->initialize();

  // Invoke simulation.
  switch (instance_->type()) {
    case tb::ProjectInstanceBase::Type::GenericSynchronous: {
      // Generic synchronous project instance
      GenericSynchronousTest* test =
          dynamic_cast<GenericSynchronousTest*>(test_);
      if (!test) {
        // Malformed test case, not of expected type.
        throw std::runtime_error("Test is not of type GenericSynchronousTest");
      }
      instance_->run(test_);
    } break;
    case tb::ProjectInstanceBase::Type::Default:
    default: {
      // Default project instance
      instance_->run(test_);
    } break;
  }

  // Finalize instance
  instance_->finalize();
}

std::unique_ptr<ProjectInstanceRunner> ProjectInstanceRunner::Build(
    Type t, ProjectInstanceBase* instance, ProjectTestBase* test) {
  std::unique_ptr<ProjectInstanceRunner> runner;
  switch (t) {
    case Type::Default:
      runner = std::make_unique<DefaultProjectRunner>(instance, test);
      break;
    default:
      throw std::runtime_error("Unknown ProjectInstanceRunner type");
  }
  return runner;
}

}  // namespace tb