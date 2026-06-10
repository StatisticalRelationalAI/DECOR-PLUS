# Detection of Commutative Factors Revised (DECOR+)

This directory contains the source code of the Detection of Commutative Factors
Revised (DECOR+) algorithm, the Apriori-Style Detection of Commutative Factors
(A-DECOR) algorithm, and the Connected-Component Detection of Commutative
Factors (CC-DECOR) algorithm, which have been presented in the paper "On the
Detection of Commutative Factors in Factor Graphs: Necessary and Sufficient
Conditions".

Our implementation uses the [Julia programming language](https://julialang.org).

## Computing Infrastructure and Required Software Packages

All experiments were conducted using Julia version 1.11.2 together with the
following packages:

- BenchmarkTools v1.6.0
- CSV v0.10.15
- Clustering v0.15.8
- Combinatorics v1.0.2
- DataFrames v1.7.0
- DataStructures v0.18.22
- Distributions v0.25.116
- Multisets v0.4.5
- OrderedCollections v1.8.0
- StatsBase v0.33.21

## Instance Generation

Run `julia generate.jl` in the `src/` directory to generate the input instances
for the experiments.
The input instances are then written into the `data/` directory (which is
automatically created).

## Running the Experiments

After the instances have been generated, the experiments can be started by
running `julia run_eval.jl` in the `src/` directory.
All results are written into the `results/` directory.

To create the plots, run `julia prepare_plot.jl` in the `results/` directory
and afterwards execute the R script `plot.r` (also in the `results/` directory).
The R script will then create a bunch of `.tex` files in the `results/` directory
containing the plots of the experiments.
To generate the plots as `.pdf` files instead, set `use_tikz = FALSE` in
line 5 of `plot.r` before executing the R script `plot.r`.