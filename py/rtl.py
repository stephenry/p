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
    def __init__(self, project: dict, filelist: list[str], vout_dir: str):
        self._project = project
        self._filelist = filelist
        self._vout_dir = vout_dir

    def execute(self, force=False) -> None:
        vc_f = os.path.join(self._vout_dir, 'vc.f')
        vc_f_timestamp = os.path.join(self._vout_dir, 'vc.f.timestamp')

        do_compile = force
        if not os.path.exists(vc_f) or not os.path.exists(vc_f_timestamp):
            do_compile = True
        elif os.path.getmtime(vc_f) > os.path.getmtime(vc_f_timestamp):
            do_compile = True

        if not do_compile:
            print("No VC_F changes detected; skipping Verilation.")
            return 

        # Destroy all pre-verilated
        if os.path.exists(self._vout_dir):
            import shutil
            shutil.rmtree(self._vout_dir)
            os.makedirs(self._vout_dir)

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

        if 'defines' in self._project:
            for k, v in self._project['defines'].items():
                cmds.append(f'-D{k}={v}')

        if True:
            cmds.append(f"--trace")

        with open(self._filelist, 'r') as flist:
            for file in flist:
                file_nl = file.rstrip('\n')
                cmds.append(f"{file_nl}")

        rtl_path = os.path.dirname(self._filelist)

        includes = [f'{rtl_path}']
        if 'directories' in self._project:
            includes.extend(self._project['directories'])

        for include in includes:
            cmds.append(f"-I{include}")

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
    def __init__(self, project_file: str, rtl_dir: str, vout_dir: str):
        self._project = self._load_project(project_file)

        self._rtl_dir = rtl_dir
        if not os.path.exists(self._rtl_dir):
            os.makedirs(self._rtl_dir)

        self._vout_dir = vout_dir
        if not os.path.exists(self._vout_dir):
            os.makedirs(self._vout_dir)

    def _load_project(self, project_file: str) -> None:
        if not os.path.exists(project_file):
            raise FileNotFoundError(f"Project file not found: {project_file}")

        import yaml
        with open(project_file, 'r') as f:
            project = yaml.safe_load(f)

        # Fix-up includes
        if 'include' in project:
            for include in project['include']:
                self._load_project_include(project, include)

        if 'sources' not in project:
            # Project has no sources defined!
            raise ValueError("Project file missing 'sources' section.")

        return project

    def _load_project_include(self, project: dict, include: str) -> None:
        if not os.path.exists(include):
            raise FileNotFoundError(f"Included project file not found: {include}")

        import yaml
        with open(include, 'r') as f:
            inc_project = yaml.safe_load(f)

        if 'sources' in inc_project:
            if 'sources' not in project:
                project['sources'] = list()
            project['sources'].extend(inc_project['sources'])

        if 'directories' in inc_project:
            if 'directories' not in project:
                project['directories'] = list()
            project['directories'].extend(inc_project['directories'])

        if 'include' in inc_project:
            for inc in inc_project['include']:
                self._load_project_include(project, inc)

    def render_rtl(self) -> typing.Tuple[bool, list[str]]:
        files = list()

        modified = False
        for fin in self._project['sources']:
            fout = os.path.join(self._rtl_dir, os.path.basename(fin))

            if not os.path.exists(fout) or \
               (os.path.getmtime(fin) > os.path.getmtime(fout)):
                self._render_file(fin, fout)
                modified = True

            files.append(fout)

        filelist = os.path.join(self._rtl_dir, 'filelist')
        print(f'Rendering RTL filelist to {filelist}')
        with open(filelist, 'w') as f:
            for file in files:
                f.write(f"{file}\n")  
 
        if not modified:
            print("No RTL changes detected; skipping rendering.")
       
        return (modified, filelist)

    def compile_rtl(self) -> None:
        modified, filelist = self.render_rtl()
        v = Verilator(project=self._project, filelist=filelist, vout_dir=self._vout_dir)
        v.execute(force=modified)    

    def _render_file(self, fin: str, fout: str) -> None:
        print(f"Rendering RTL: {fin} to {fout}")
        with (open(fout, 'w') as o, open(fin, 'r') as i):
            o.write(i.read())

        if False:
            os.chmod(fout, stat.S_IREAD)
