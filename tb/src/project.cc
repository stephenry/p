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

namespace tb {

ProjectBuilderBase* ProjectRegistry::lookup(const std::string& name) {
  if (auto it = designs_.find(name); it != designs_.end()) {
    return it->second.get();
  }

  // Otherwise, project was not found.
  return nullptr;
}

void ProjectRegistry::create(const std::string& name) {
  designs_.emplace(name, std::make_unique<ProjectBuilderBase>(name));
}

ProjectInstanceBuilderBase* ProjectBuilderBase::lookup_instance_builder(
    const std::string& instance_name) {
  // Lookup instance builder for instance_name.
  if (auto it = instances_.find(instance_name); it != instances_.end()) {
    return it->second.get();
  }
  // Otherwise, instance was not found.
  return nullptr;
}

ProjectTestBuilderBase* ProjectBuilderBase::lookup_test_builder(
    const std::string& test_name) {
  // Lookup test builder for test_name.
  if (auto it = tests_.find(test_name); it != tests_.end()) {
    return it->second.get();
  }
  // Otherwise, test was not found.
  return nullptr;
}

}  // namespace tb