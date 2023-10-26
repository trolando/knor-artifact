Knor artefact
=============
This be the artefact for the TACAS24 paper on Knor.

To use the artefact, mount the files in the TACAS23 VM, https://zenodo.org/doi/10.5281/zenodo.7113222.

You can contact the main author of this work at <t.vandijk@utwente.nl>

Experiments
-----------
See `knor-experiments` folder.

Recompiling
-----------
Recompiling is not necessary, as the `knor` executable is present in the `knor-experiments/bin` folder.
The instructions here are in case you want to recompile the program.

First install all packages in the `packages` folder using the command `sudo dpkg -i *deb`.

Then install Lace:
- `cd lace`
- `cmake -B build -DCMAKE_BUILD_TYPE=Release`
- `cmake --build build -j`
- `sudo cmake --install build`

Then install Sylvan:
- `cd sylvan`
- `cmake -B build -DCMAKE_BUILD_TYPE=Release`
- `cmake --build build -j`
- `sudo cmake --install build`

Then install Oink:
- `cd oink`
- `cmake -B build -DCMAKE_BUILD_TYPE=Release`
- `cmake --build build -j`
- `sudo cmake --install build`

Then build Knor:
- `cd knor`
- `cmake -B build -DCMAKE_BUILD_TYPE=Release`
- `cmake --build build -j`

This last step can take some time as ABC is compiled as well.

Afterwards, you can find the knor executable in the `build` folder.

You can test it on some example:
- `build/knor examples/full_arbiter_8.tlsf.ehoa -v`

You can copy it to the experiments site:
- `cp build/knor ../knor-experiments/bin`

Re-obtaining benchmark input files
----------------------------------
- Input files are stored in the `knor-experiments/inputs` folder
- Files were downloaded from https://github.com/SYNTCOMP/benchmarks/tree/v2023.4/parity/tlsf_based
- These input files are also found in the `knor/examples` folder

Re-running the experiments
--------------------------
- The `run.py` file runs the experiments. Just run it without a parameter and it gives usage info.
- Use `run.py run` to run the experiments one by one and store the log files in the logs directory.
- Use `run.py clean` to delete the cache and delete erroneous runs (caused by aborting the run).
- Use `run.py cache` to populate cache.json. Not strictly required but can improve repeated parsing.
- Use `run.py csv` to generate the CSV file with results

To rerun the experiments:
- Delete the `logs` folder
- Run `run.py clean`
- Then run `run.py run` to run all experiments. You may want to wait some time.
- Use `run.py csv > results.csv` to regenerate results.csv

All log files are stored in the `logs` directory.
The results of experiments are stored in `results.csv`.

Analysing the results
---------------------
First install all packages in the `rpackages` folder using the command `sudo dpkg -i *deb`.

Then copy the `R` directory to the homedir using `cp -r ./R ~`

Now you can analyse the results as follows:
- `cd knor-experiments`
- `./analyse.r`

This generates all tables and figures of the paper.
