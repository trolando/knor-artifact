#!/usr/bin/env python3
import os.path

from framework import ExperimentEngine, Experiment
from experiments import KnorExperiments
import sys

ITERATIONS = 5
TIMEOUT = 120
LOGDIR = "logs"
CACHEFILE = "cache.json"


# Load the engine
engine = ExperimentEngine(logdir=LOGDIR, cachefile=CACHEFILE, timeout=TIMEOUT)
# Create all experiments for the directory inputs
engine += KnorExperiments("inputs")


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def usage():
    cmd = os.path.realpath(__file__)
    eprint(f"Valid calls:")
    eprint(f"{cmd} todo           List all groups to do")
    eprint(f"{cmd} report         Report all experiments")
    eprint(f"{cmd} report <GROUP> Report all experiments in a group")
    eprint(f"{cmd} run <GROUP>    Run a group")
    eprint(f"{cmd} cache          Update the cache")
    eprint(f"{cmd} csv            Write the CSV of the results to stdout")
    eprint(f"{cmd} clean          Delete cache and delete error experiments")


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == 'todo':
            todo()
        elif sys.argv[1] == 'report':
            report()
        elif sys.argv[1] == 'run' and len(sys.argv) == 2:
            run()
        elif sys.argv[1] == 'run' and len(sys.argv) > 2:
            run_group(sys.argv[2])
        elif sys.argv[1] == 'cache':
            cache()
        elif sys.argv[1] == 'csv':
            csv()
        elif sys.argv[1] == 'clean':
            clean()
        else:
            usage()
    else:
        usage()


def clean():
    engine.initialize(ITERATIONS, False)
    engine.clean(iterations=ITERATIONS)


def csv():
    engine.initialize(ITERATIONS, False)
    expmap = {e.name: e for e in engine}
    for i, it in enumerate(engine.results):
        if i > ITERATIONS:
            break
        for ename, res in it.items():
            e = expmap[ename]
            csv_print_experiment(e, res)


def csv_print_experiment(e, res):
    status, value = res
    if status == Experiment.TIMEOUT:
        print("{}; {}; {:.6f}; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0".format(
            e.group, e.solver, TIMEOUT))
        return
    if status != Experiment.DONE:
        return
    parsing = value.get("parsing", 0)
    constructing = value.get("constructing", 0)
    solving = value.get("solving", 0)
    postprocessing = value.get("postprocessing", 0)
    minimising = value.get("minimising", 0)
    encoding = value.get("encoding", 0)
    compressing = value.get("compressing", 0)
    drewriting = value.get("drewriting", 0)
    automaton_states = value.get("automaton_states", 0)
    game_vertices = value.get("game_vertices", 0)
    game_edges = value.get("game_edges", 0)
    time = value['time']
    aigsize = value.get("aigsize", 0)

    print("{}; {}; {:.6f}; 1; {}; {:.6f}; {:.6f}; {:.6f}; {:.6f}; {:.6f}; {:.6f}; {:.6f}; {:.6f}; {}; {}; {}"
          .format(e.group, e.solver, time, aigsize,
                  parsing, constructing, solving, postprocessing, minimising, encoding, compressing, drewriting,
                  automaton_states, game_vertices, game_edges))


def run_group(group_to_run):
    # run the given group with given number of iterations
    engine.initialize(ITERATIONS, False)
    engine.run(group=group_to_run, iterations=ITERATIONS)


def run():
    # run the given group with given number of iterations
    engine.initialize(ITERATIONS, False)
    engine.run(iterations=ITERATIONS)


def cache():
    engine.initialize(ITERATIONS, True)
    engine.save_cache(True)
    count_done = sum([len(x) for i, x in enumerate(engine.results) if i < ITERATIONS])
    count_to = sum([1 for i, x in enumerate(engine.results)
                    for a, b in x.items() if b[0] == Experiment.TIMEOUT and b[1] < TIMEOUT])
    print("Remaining: {} experiments not done + {} experiments rerun for higher timeout."
          .format(ITERATIONS * len(engine) - count_done, count_to))


def report():
    engine.initialize(ITERATIONS, False)
    if len(sys.argv) > 2:
        engine.report(group=sys.argv[2], iterations=ITERATIONS)
    else:
        engine.report(iterations=ITERATIONS)


def todo():
    engine.initialize(ITERATIONS, False)
    for x in engine.todo(iterations=ITERATIONS):
        print(x)


if __name__ == "__main__":
    main()
