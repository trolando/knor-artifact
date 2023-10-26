#!/usr/bin/env python3
import os
import sys
import random
from subprocess import Popen, TimeoutExpired


def ensure_dir(file_path):
    """
    Creates the directory for the given file path if it does not exist.
    :param file_path:
    :return:
    """
    directory = os.path.normpath(os.path.dirname(file_path))
    if not os.path.exists(directory):
        os.makedirs(directory)


def call(*popenargs, timeout=None, **kwargs):
    """
    Calls the given command with the given arguments and waits for it to finish.
    :param popenargs:
    :param timeout:
    :param kwargs:
    :return:
    """
    # print(f"Calling {popenargs}")
    with Popen(*popenargs, **kwargs) as p:
        try:
            return p.wait(timeout=timeout)
        except TimeoutExpired:
            p.kill()
            p.wait()
            raise


# Change directory to the root of the project
os.chdir(os.path.dirname(os.path.realpath(__file__)))
# print("Current directory: " + os.curdir)

ensure_dir("outputs/")

# For all files in the inputs/pgame directory
files = os.listdir("inputs")
# Shuffle files
random.shuffle(files)
files.sort()
for filename in files:
    # If the file is a .pgn file
    if filename.endswith(".ehoa"):
        # Reset sizes
        size_explicit = 0
        size_sym = 0
        size_naive = 0
        # Create the path to the file
        path = os.path.join("inputs", filename)
        # Open the file
        filesize = os.path.getsize(path)
        if filesize < 150:
            print(f"Skipping {filename}")
            continue
        if filename.startswith("aut"):
            print(f"Skipping {filename}")
            continue  # Expected parity automaton, found Buchi as automaton type
        if "jgame" in filename:
            continue
        if filename.startswith("test"):
            print(f"Skipping {filename}")
            continue  # Expected parity automaton, found generalized-Buchi as automaton type
        # if os.path.exists(f"outputs/{filename}-naive.pg") and os.path.exists(f"outputs/{filename}-expl.pg") and os.path.exists(f"outputs/{filename}.pg"):
        #    continue

        print(f"{filename:<100}: ", end="")
        # Open output file
        try:
            if not os.path.exists(f"outputs/{filename}-naive.pg"):
                with open(f"outputs/{filename}-naive.pg", "w") as out:
                    # Call Knor on the file
                    call(["bin/knor", "--naive", "--print-game", path], stdout=out, stderr=sys.stdout, timeout=240)
            with open(f"outputs/{filename}-naive.pg", "r") as out:
                # read the first line
                first_line = out.readline()
                size_naive = int(first_line.split()[1][:-1])
        except TimeoutExpired:
            print("Timeout ", end="")
        except IndexError:
            os.remove(f"outputs/{filename}-naive.pg")
            print("Error ", end="")
        try:
            if not os.path.exists(f"outputs/{filename}-expl.pg"):
                with open(f"outputs/{filename}-expl.pg", "w") as out:
                    # Call Knor on the file
                    call(["bin/knor", "--explicit", "--print-game", path], stdout=out, stderr=sys.stdout, timeout=240)
            with open(f"outputs/{filename}-expl.pg", "r") as out:
                # read the first line
                first_line = out.readline()
                size_explicit = int(first_line.split()[1][:-1])
        except TimeoutExpired:
            print("Timeout ", end="")
        except IndexError:
            os.remove(f"outputs/{filename}-expl.pg")
            print("Error ", end="")
        try:
            if not os.path.exists(f"outputs/{filename}.pg"):
                with open(f"outputs/{filename}.pg", "w") as out:
                    # Call Knor on the file
                    call(["bin/knor", "--print-game", path], stdout=out, stderr=sys.stdout, timeout=240)
            with open(f"outputs/{filename}.pg", "r") as out:
                # read the first line
                first_line = out.readline()
                size_sym = int(first_line.split()[1][:-1])
        except TimeoutExpired:
            print("Timeout ", end="")
        except IndexError:
            os.remove(f"outputs/{filename}.pg")
            print("Error ", end="")
        print(f"Naive: {size_naive:<10} Explicit: {size_explicit:<10} Sym: {size_sym:<10}")
