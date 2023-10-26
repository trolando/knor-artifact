#!/usr/bin/env python3
import os
import re

# import framework
from framework import Experiment


KNOR = "bin/knor"


###
# We have some classes implementing Experiment:
# - <parse_log> to parse a log file into a result dictionary (or None)
# - <get_text> to obtain a textual description from a result dictionary
###


class ExpKnor(Experiment):
    def __init__(self, name, model):
        super().__init__(name=name, call=[], group=name)
        self.group = name
        self.solver = "std"
        self.name = "{}".format(name)
        self.call = [KNOR, "-v", model]
        self.model = model

    def parse_log(self, contents):
        s = re.search(r'total time', contents)
        if not s:
            return None
        res = {}
        s = re.search(r'finished parsing automaton in ([\d.,]+)', contents)
        res['parsing'] = float(s.group(1)) if s else float(0)
        s = re.search(r'finished constructing game in ([\d.,]+)', contents)
        res['constructing'] = float(s.group(1)) if s else float(0)
        s = re.search(r'finished solving game in ([\d.,]+)', contents)
        res['solving'] = float(s.group(1)) if s else float(0)
        s = re.search(r'finished post processing in ([\d.,]+)', contents)
        res['postprocessing'] = float(s.group(1)) if s else float(0)
        s = re.search(r'finished bisimulation minimisation in ([\d.,]+)', contents)
        res['minimising'] = float(s.group(1)) if s else float(0)
        s = re.search(r'finished encoding in ([\d.,]+)', contents)
        res['encoding'] = float(s.group(1)) if s else float(0)
        s = re.search(r'finished compression in ([\d.,]+)', contents)
        res['compressing'] = float(s.group(1)) if s else float(0)
        s = re.search(r'finished drw.drf in ([\d.,]+)', contents)
        res['drewriting'] = float(s.group(1)) if s else float(0)
        s = re.search(r'automaton has (\d+) states', contents)
        res['automaton_states'] = int(s.group(1)) if s else int(0)
        s = re.search(r'constructed game has (\d+) vertices and (\d+) edges', contents)
        res['game_vertices'] = int(s.group(1)) if s else int(0)
        res['game_edges'] = int(s.group(2)) if s else int(0)
        s = re.search(r'total time was ([\d.,]+)', contents)
        res['time'] = float(s.group(1)) if s else float(0)
        s = re.search(r'final size of AIG: (\d+) gates', contents)
        res['aigsize'] = int(s.group(1)) if s else int(0)
        return res

    def get_text(self, res):
        if 'error' in res:
            return res['error']
        return "{:0.6f} sec; {:d} gates".format(res['time'], res['aigsize'])

    def naive(self):
        self.name = "{}-naive".format(self.name)
        self.solver = "{}-naive".format(self.solver)
        self.call += ["--naive", "--real"]
        return self

    def explicit(self):
        self.name = "{}-explicit".format(self.name)
        self.solver = "{}-explicit".format(self.solver)
        self.call += ["--explicit", "--real"]
        return self

    def sym(self):
        self.name = "{}-sym".format(self.name)
        self.solver = "sym"
        self.call += ["--sym"]
        return self

    def bisim(self):
        self.name = "{}-bisim".format(self.name)
        self.solver = "{}-bisim".format(self.solver)
        self.call += ["--bisim"]
        return self

    def isop(self):
        self.name = "{}-isop".format(self.name)
        self.solver = "{}-isop".format(self.solver)
        self.call += ["--isop"]
        return self

    def onehot(self):
        self.name = "{}-onehot".format(self.name)
        self.solver = "{}-onehot".format(self.solver)
        self.call += ["--onehot"]
        return self

    def zlk(self):
        self.name = "{}-zlk".format(self.name)
        self.solver = "zlk"
        self.call += ["--zlk"]
        return self

    def fpi(self):
        self.name = "{}-fpi".format(self.name)
        self.solver = "fpi"
        self.call += ["--fpi"]
        return self

    def fpj(self):
        self.name = "{}-fpj".format(self.name)
        self.solver = "fpj"
        self.call += ["--fpj"]
        return self

    def psi(self):
        self.name = "{}-psi".format(self.name)
        self.solver = "psi"
        self.call += ["--psi"]
        return self

    def tl(self):
        self.name = "{}-tl".format(self.name)
        self.solver = "tl"
        self.call += ["--tl"]
        return self

    def pp(self):
        self.name = "{}-pp".format(self.name)
        self.solver = "pp"
        self.call += ["--npp"]
        return self

    def compress(self):
        self.name = "{}-compress".format(self.name)
        self.solver = "{}-compress".format(self.solver)
        self.call += ["--compress"]
        return self

    def drewrite(self):
        self.name = "{}-drewrite".format(self.name)
        self.solver = "{}-drewrite".format(self.solver)
        self.call += ["--drewrite"]
        return self


###
# Now that we have defined our experiments, we define the collections
###


class FileFinder(object):
    def __init__(self, directory, extensions):
        self.directory = directory
        self.extensions = extensions

    def __iter__(self):
        if not hasattr(self, 'files'):
            self.files = []
            for ext in self.extensions:
                dotext = "." + ext
                # get all files in directory ending with the extension
                files = [f[:-len(dotext)] for f in filter(lambda f: f.endswith(dotext) and os.path.isfile(self.directory+"/"+f), os.listdir(self.directory))]
                self.files.extend([(x, "{}/{}{}".format(self.directory, x, dotext)) for x in files])
        return self.files.__iter__()


class KnorExperiments(object):
    def __init__(self, directory, solvers=None):
        if solvers is None:
            solvers = []
        self.files = FileFinder(directory, ["ehoa"])
        self.solvers = solvers if len(solvers) > 0 else list(self.get_solvers().keys())

    @staticmethod
    def get_solvers():
        return {
            'standard': lambda name, filename: ExpKnor(name, filename),
            'naive': lambda name, filename: ExpKnor(name, filename).naive(),
            'explicit': lambda name, filename: ExpKnor(name, filename).explicit(),
            'sym': lambda name, filename: ExpKnor(name, filename).sym(),
            'zlk': lambda name, filename: ExpKnor(name, filename).zlk(),
            'fpi': lambda name, filename: ExpKnor(name, filename).fpi(),
            'fpj': lambda name, filename: ExpKnor(name, filename).fpj(),
            'pp': lambda name, filename: ExpKnor(name, filename).pp(),
            'psi': lambda name, filename: ExpKnor(name, filename).psi(),
            'onehot': lambda name, filename: ExpKnor(name, filename).onehot(),
            'sym-onehot': lambda name, filename: ExpKnor(name, filename).sym().onehot(),
            'zlk-onehot': lambda name, filename: ExpKnor(name, filename).zlk().onehot(),
            'fpi-onehot': lambda name, filename: ExpKnor(name, filename).fpi().onehot(),
            'fpj-onehot': lambda name, filename: ExpKnor(name, filename).fpj().onehot(),
            'pp-onehot': lambda name, filename: ExpKnor(name, filename).pp().onehot(),
            'psi-onehot': lambda name, filename: ExpKnor(name, filename).psi().onehot(),
            'bisim': lambda name, filename: ExpKnor(name, filename).bisim(),
            'isop': lambda name, filename: ExpKnor(name, filename).isop(),
            'isop-onehot': lambda name, filename: ExpKnor(name, filename).isop().onehot(),
            'bisim-isop': lambda name, filename: ExpKnor(name, filename).bisim().isop(),
            'bisim-onehot': lambda name, filename: ExpKnor(name, filename).bisim().onehot(),
            'bisim-isop-onehot': lambda name, filename: ExpKnor(name, filename).bisim().isop().onehot(),
            'bisim-isop-compress': lambda name, filename: ExpKnor(name, filename).bisim().isop().compress(),
            'bisim-onehot-compress': lambda name, filename: ExpKnor(name, filename).bisim().onehot().compress(),
            'bisim-isop-onehot-compress': lambda name, filename: ExpKnor(name, filename).bisim().isop().onehot().compress(),
            'bisim-isop-drewrite': lambda name, filename: ExpKnor(name, filename).bisim().isop().drewrite(),
            'bisim-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).bisim().onehot().drewrite(),
            'bisim-isop-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).bisim().isop().onehot().drewrite(),
            'pp-bisim': lambda name, filename: ExpKnor(name, filename).pp().bisim(),
            'fpj-bisim': lambda name, filename: ExpKnor(name, filename).fpj().bisim(),
            'fpj-bisim-isop': lambda name, filename: ExpKnor(name, filename).fpj().bisim().isop(),
            'fpj-bisim-onehot': lambda name, filename: ExpKnor(name, filename).fpj().bisim().onehot(),
            'fpj-bisim-isop-onehot': lambda name, filename: ExpKnor(name, filename).fpj().bisim().isop().onehot(),
            'fpj-bisim-isop-drewrite': lambda name, filename: ExpKnor(name, filename).fpj().bisim().isop().drewrite(),
            'fpj-bisim-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).fpj().bisim().onehot().drewrite(),
            'fpj-bisim-isop-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).fpj().bisim().isop().onehot().drewrite(),
            'fpj-bisim-isop-compress': lambda name, filename: ExpKnor(name, filename).fpj().bisim().isop().compress(),
            'fpj-bisim-onehot-compress': lambda name, filename: ExpKnor(name, filename).fpj().bisim().onehot().compress(),
            'fpj-bisim-isop-onehot-compress': lambda name, filename: ExpKnor(name, filename).fpj().bisim().isop().onehot().compress(),
            'sym-bisim': lambda name, filename: ExpKnor(name, filename).sym().bisim(),
            'sym-bisim-isop': lambda name, filename: ExpKnor(name, filename).sym().bisim().isop(),
            'sym-bisim-onehot': lambda name, filename: ExpKnor(name, filename).sym().bisim().onehot(),
            'sym-bisim-isop-onehot': lambda name, filename: ExpKnor(name, filename).sym().bisim().isop().onehot(),
            'sym-bisim-isop-drewrite': lambda name, filename: ExpKnor(name, filename).sym().bisim().isop().drewrite(),
            'sym-bisim-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).sym().bisim().onehot().drewrite(),
            'sym-bisim-isop-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).sym().bisim().isop().onehot().drewrite(),
            'sym-bisim-isop-compress': lambda name, filename: ExpKnor(name, filename).sym().bisim().isop().compress(),
            'sym-bisim-onehot-compress': lambda name, filename: ExpKnor(name, filename).sym().bisim().onehot().compress(),
            'sym-bisim-isop-onehot-compress': lambda name, filename: ExpKnor(name, filename).sym().bisim().isop().onehot().compress(),
            'psi-bisim': lambda name, filename: ExpKnor(name, filename).psi().bisim(),
            'psi-bisim-isop': lambda name, filename: ExpKnor(name, filename).psi().bisim().isop(),
            'psi-bisim-onehot': lambda name, filename: ExpKnor(name, filename).psi().bisim().onehot(),
            'psi-bisim-isop-onehot': lambda name, filename: ExpKnor(name, filename).psi().bisim().isop().onehot(),
            'psi-bisim-isop-drewrite': lambda name, filename: ExpKnor(name, filename).psi().bisim().isop().drewrite(),
            'psi-bisim-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).psi().bisim().onehot().drewrite(),
            'psi-bisim-isop-onehot-drewrite': lambda name, filename: ExpKnor(name, filename).psi().bisim().isop().onehot().drewrite(),
            'psi-bisim-isop-compress': lambda name, filename: ExpKnor(name, filename).psi().bisim().isop().compress(),
            'psi-bisim-onehot-compress': lambda name, filename: ExpKnor(name, filename).psi().bisim().onehot().compress(),
            'psi-bisim-isop-onehot-compress': lambda name, filename: ExpKnor(name, filename).psi().bisim().isop().onehot().compress(),
        }

    def __iter__(self):
        if not hasattr(self, 'grouped'):
            # define
            slvrs = self.get_solvers()
            if len(self.solvers) != 0:
                slvrs = {k: v for k, v in slvrs.items() if k in self.solvers}
            for slvr in slvrs:
                setattr(self, slvr, {})
            self.grouped = {}
            for name, filename in self.files:
                self.grouped[name] = []
                for slvr, fn in slvrs.items():
                    exp = fn(name, filename)
                    getattr(self, slvr)[name] = exp
                    self.grouped[name].append(exp)
        return self.grouped.values().__iter__()
