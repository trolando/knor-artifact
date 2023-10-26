#!/usr/bin/env python3
import os
import gzip
import shutil
from zipfile import ZipFile
from subprocess import call, Popen

def ensure_dir(file_path):
    directory = os.path.dirname(file_path)
    if not os.path.exists(directory):
        os.makedirs(directory)

if __name__ == "__main__":
    ensure_dir("inputs/pgame")
    print("Unzipping SYNTCOMP 2023 files")
    with ZipFile("sources/Parity_2023.zip", 'r') as zfile:
        zfile.extractall(path="./inputs/pgame")
    for filename in os.listdir("sources"):
        if filename.endswith(".ehoa"):
            shutil.copy2(os.path.join("sources", filename), os.path.join("inputs/pgame/selection2023",filename))
    
# TODO download things knor
