##========================================================================== //
## Copyright (c) 2025, Stephen Henry
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
## * Redistributions of source code must retain the above copyright notice, this
##   list of conditions and the following disclaimer.
##
## * Redistributions in binary form must reproduce the above copyright notice,
##   this list of conditions and the following disclaimer in the documentation
##   and/or other materials provided with the distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
## LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##========================================================================== //

import argparse
import os
import stat
import typing


class Verilator:
    def __init__(self, project: dict, filelist: list[str], out_dir: str):
        self._project = project
        self._filelist = filelist
        self._out_dir = out_dir

        self._vout_dir = os.path.join(self._out_dir, 'verilated')
        if os.path.exists(self._vout_dir):
            import shutil
            shutil.rmtree(self._vout_dir)

    def execute(self, force=False) -> None:
        vc_f = os.path.join(self._out_dir, 'vc.f')
        vc_f_timestamp = os.path.join(self._out_dir, 'vc.f.timestamp')

        do_compile = True
        if not os.path.exists(vc_f) or not os.path.exists(vc_f_timestamp):
            do_compile = True
        elif os.path.getmtime(vc_f) > os.path.getmtime(vc_f_timestamp):
            do_compile = True

        if not do_compile:
            print("No VC_F changes detected; skipping Verilation.")
            return 

        with open(vc_f, 'w') as f:
            self._render_command_file(f)

        self._invoke_verilation(of=vc_f)
        self._touch_timestamp(vc_f_timestamp)

    def _render_command_file(self, f) -> None:
        print(f"Rendering Verilator command file to {f.name}...")

        top_module = os.path.basename(
            os.path.splitext(self._project['top'])[0])

        cmds = [
            f"--top-module {top_module}",
            f"--Mdir {self._vout_dir}",
            f"--cc",
            f"--build",
            f"--unused-regexp UNUSED_*",
        ]

        if True:
            cmds.append(f"--trace")

        for fl in self._filelist:
            cmds.append(f"{fl}")

        for incf in self._project['includes']:
            cmds.append(f"-I{incf}")

        f.write('\n'.join(cmds))
        f.write('\n')

    def _invoke_verilation(self, of: str) -> None:
        import subprocess

        from cfg import VERILATOR_EXE

        print("Invoking Verilator...")
        subprocess.run([VERILATOR_EXE, "-f", of])

    def _touch_timestamp(self, f: str) -> None:
        with open(f, 'w') as tf:
            tf.write("COMPILED")


class RTLRenderer:
    def __init__(self, project_file: str, out_dir: str):
        self._project = self._load_project(project_file)
        self._fls = list()

        self._out_dir = out_dir
        if not os.path.exists(self._out_dir):
            os.makedirs(self._out_dir)

    def _load_project(self, project_file: str) -> None:
        if not os.path.exists(project_file):
            raise FileNotFoundError(f"Project file not found: {project_file}")

        import yaml
        with open(project_file, 'r') as f:
            project = yaml.safe_load(f)

        if 'sources' not in project:
            # Project has no sources defined!
            raise ValueError("Project file missing 'sources' section.")

        return project

    def render_rtl(self) -> typing.Tuple[bool, list[str]]:
        fls = list()

        rtl_dir = os.path.join(self._out_dir, 'rtl')
        if not os.path.exists(rtl_dir):
            os.makedirs(rtl_dir)

        modified = False
        for fin in self._project['sources']:
            fout = os.path.join(rtl_dir, os.path.basename(fin))

            if not os.path.exists(fout) or \
               (os.path.getmtime(fin) > os.path.getmtime(fout)):
                self._render_file(fin, fout)
                modified = True

            fls.append(fout)

        if not modified:
            print("No RTL changes detected; skipping rendering.")
            return (False, fls)

        print(f'Rendering RTL to {rtl_dir}...')
        return (True, fls)

    def compile_rtl(self) -> None:
        modified, fls = self.render_rtl()
        v = Verilator(project=self._project, filelist=fls, out_dir=self._out_dir)
        v.execute(force=modified)    

    def _render_file(self, fin: str, fout: str) -> None:
        print(f"Rendering RTL: {fin} -> {fout}")
        with (open(fout, 'w') as o, open(fin, 'r') as i):
            o.write(i.read())

        if False:
            os.chmod(fout, stat.S_IREAD)
