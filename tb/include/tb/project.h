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

#include "verilated.h"

namespace tb {

class GenericSynchronousProjectInstance : public ProjectInstanceBase {
protected:

    struct {

        bool reset_async = true;

        bool reset_active_high = false;

    } opts;

public:


    explicit GenericSynchronousProjectInstance(const std::string& name)
        : ProjectInstanceBase(name) {}

    virtual ~GenericSynchronousProjectInstance() = default;

    // Initialize the project instance.
    virtual void initialize() {}

    // Finalize the project instance.
    virtual void finalize() {}

protected:

    // Port pointers to be set by derived classes before start of simulation.
    struct {
        vluint8_t* clk_;

        vluint8_t* rst_;
    } ports;
};


} // namespace tb

#endif // TB_TB_PROJECT_H
