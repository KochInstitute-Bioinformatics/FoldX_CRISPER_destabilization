# FoldX Analysis Pipeline

A Nextflow pipeline for protein stability analysis using FoldX.

## Overview

This pipeline performs FoldX analysis to calculate ΔΔG values for protein mutations, comparing mutant structures to wild-type structures.

## Features

- Automated FoldX structure repair
- Batch processing of multiple mutations
- ΔΔG calculation for stability analysis
- Modular Nextflow DSL2 implementation
- Conda environment management with Wave

## Requirements

- Nextflow (≥ 22.10.0)
- FoldX executable
- Conda/Mamba
- PDB structure files

## Usage

Basic usage:
nextflow run main.nf \
    --mutation_csv mutations.csv \
    --foldx_path /path/to/FoldX \
    --structure_dir ./structures \
    --outdir results

With custom parameters:
nextflow run main.nf \
    --mutation_csv mutations.csv \
    --foldx_path /path/to/FoldX \
    --structure_dir ./structures \
    --chain A \
    --number_of_runs 3 \
    --outdir results

## Input Format

The mutation CSV file should contain columns:

- Gene: Gene name (matching PDB filename)
- Mutation: Mutation in format like "E1932K"

## Output

- final_results/final_ddG_results.csv: Final results with ΔΔG values
- mutation_files/: Individual mutation list files
- repaired_structures/: FoldX-repaired PDB files
- foldx_results/: Raw FoldX output files

## Citation

If you use this pipeline, please cite:

- Nextflow: <https://doi.org/10.1038/nbt.3820>
- FoldX: <https://doi.org/10.1093/nar/gki387>
