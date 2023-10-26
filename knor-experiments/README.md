Knor experiments
================

This repository hosts the experimental scripts for Knor.

You can contact the main author of this work at <t.vandijk@utwente.nl>

Information on the experiments is found in the submitted paper.

Files
-----
| Filename               | Description |
| ---------------------- | ----------- |
| `framework.py`         | Framework for running experiments |
| `experiments.py`       | Definitions of Knor experiments |
| `run.py`               | Main entry point for running experiments |
| `make_parity_games.py` | Creates parity games using the three different methods |
| `cache.json`           | Cache of log files (after parsing) |
| `results.csv`          | CSV of results of experiments |
| `analyse.r`            | Script in R to run analysis for the paper |
| `LICENSE`              | GPL-3 license (copyleft because of hoa-tools code present in Knor) |
| `README.md`            | This file |

Compiling the sources
-----
- Compile Knor from https://www.github.com/trolando/knor using CMake

Obtaining benchmark input files
-----
- Files were downloaded from https://github.com/SYNTCOMP/benchmarks/tree/v2023.4/parity/tlsf_based
- These inputs files are also found in Knor's `examples` folder

Running the experiments
-----
- The `run.py` file runs the experiments. Just run it without a parameter and it gives usage info.
- Use `run.py run` to run the experiments one by one and store the log files in the logs directory.
- Use `run.py cache` to populate cache.json. Not strictly required but can improve repeated parsing.
- Use `run.py csv` to generate the CSV file with results

Experimental results
-----
- All log files are stored in the `logs` directory.
- The results of experiments are stored in `results.csv`.

Analysing the results
-----
- Use `analyse.r`; the file `results.csv` must be present.
- This file generates all tables and figures of the paper.

