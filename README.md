# FoldX CRISPR Destabilization Analysis Pipeline

A comprehensive Nextflow DSL2 pipeline for analyzing protein destabilization effects of CRISPR-induced mutations using FoldX.

## Overview

This pipeline automates the analysis of protein stability changes caused by mutations, particularly those introduced by CRISPR editing. It uses FoldX to calculate ΔΔG values by comparing mutant protein structures to their wild-type counterparts, providing insights into the destabilizing effects of specific amino acid changes.

## Pipeline Workflow

The pipeline consists of five main steps:

1. **Mutation File Generation**: Parses input CSV and creates individual mutation files for FoldX
2. **Structure Repair**: Repairs PDB structures using FoldX RepairPDB
3. **Wild-type Analysis**: Runs FoldX BuildModel on wild-type structures
4. **Mutant Analysis**: Runs FoldX BuildModel on mutant structures
5. **ΔΔG Calculation**: Calculates stability changes and generates final results

## Features

- **Modular Design**: Built with Nextflow DSL2 for maintainability and reusability
- **Containerized Execution**: Supports Docker, Singularity, and Apptainer
- **Flexible Configuration**: Multiple execution profiles for different environments
- **Batch Processing**: Handles multiple genes and mutations simultaneously
- **Automated Structure Repair**: Uses FoldX RepairPDB for structure optimization
- **Comprehensive Output**: Detailed results with intermediate files preserved

## Requirements

### Software Dependencies

- Nextflow (≥ 22.10.0)
- Container runtime (Docker, Singularity, or Apptainer) OR Conda/Mamba
- FoldX executable (version 5 recommended)

### Input Files

- CSV file containing mutation information
- PDB structure files for target proteins
- FoldX executable or access to FoldX container

## Installation

1. Clone the repository:

```bash
git clone https://github.com/KochInstitute-Bioinformatics/FoldX_CRISPER_destabilization.git
cd FoldX_CRISPER_destabilization
```

1. Ensure Nextflow is installed:

```bash
curl -s https://get.nextflow.io | bash
```

## Usage

### Basic Usage

```bash
nextflow run main.nf \
  --mutation_csv mutations.csv \
  --foldx_path /path/to/foldx_20251231 \
  --structure_dir ./structures \
  --outdir results
```

### Advanced Usage with Custom Parameters

```bash
nextflow run main.nf \
  --mutation_csv mutations.csv \
  --foldx_path /path/to/foldx_20251231 \
  --structure_dir ./structures \
  --chain A \
  --number_of_runs 3 \
  --outdir results \
  -profile docker
```

### Execution Profiles

The pipeline supports multiple execution profiles:

- **Default**: Uses containers with Docker
- **`singularity`**: Uses Singularity containers
- **`apptainer`**: Uses Apptainer containers  
- **`docker`**: Explicitly uses Docker containers
- **`conda_only`**: Uses only Conda environments (no containers)

Example with Singularity:

```bash
nextflow run main.nf \
  --mutation_csv mutations.csv \
  --foldx_path foldx_20251231 \
  -profile singularity
```

## Input Format

### Mutation CSV File

The input CSV file must contain the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| Gene | Gene/protein name (must match PDB filename without extension) | BRCA1 |
| Mutation | Amino acid change in single-letter format | E1932K |

**Example CSV content:**

```csv
Gene,Mutation
BRCA1,E1932K
BRCA1,R1699W
TP53,R273H
TP53,G245S
```

### Structure Files

- PDB files should be named to match the Gene column (e.g., `BRCA1.pdb`)
- Place all PDB files in the directory specified by `--structure_dir`
- Structures should be clean and properly formatted for FoldX analysis

## Parameters

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--mutation_csv` | Path to CSV file containing mutations | `mutations.csv` |
| `--foldx_path` | Path to FoldX executable | `foldx_20251231` |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--structure_dir` | `./structures` | Directory containing PDB files |
| `--outdir` | `results` | Output directory |
| `--chain` | `A` | Protein chain to analyze |
| `--number_of_runs` | `1` | Number of FoldX runs per mutation |

## Output Structure

```bash
results/
├── final_results/
│   └── final_ddG_results.csv          # Main results file
├── mutation_files/
│   ├── GENE1_MUTATION1.individual_list.txt
│   ├── GENE1_WT.individual_list.txt
│   └── ...
├── repaired_structures/
│   ├── GENE1_Repair.pdb
│   └── ...
├── foldx_results/
│   ├── GENE1_MUTATION1_BuildModel/
│   └── ...
└── pipeline_info/
    ├── execution_timeline.html
    ├── execution_report.html
    ├── execution_trace.txt
    └── pipeline_dag.svg
```

### Key Output Files

- **`final_ddG_results.csv`**: Contains calculated ΔΔG values for all mutations
- **`*_Repair.pdb`**: FoldX-repaired structure files
- **`*.individual_list.txt`**: FoldX mutation specification files
- **Pipeline info**: Execution reports and workflow visualization

## Troubleshooting

### Common Issues

1. **FoldX executable not found**
   - Ensure FoldX is in your PATH or provide full path with `--foldx_path`
   - Check FoldX executable permissions

2. **PDB file not found**
   - Verify PDB filenames match Gene column entries
   - Check `--structure_dir` path is correct

3. **Container issues**
   - Try different profile (`-profile singularity` or `-profile conda_only`)
   - Ensure container runtime is properly installed

4. **Memory issues**
   - Large proteins may require more memory
   - Consider running with fewer parallel processes

### Getting Help

```bash
nextflow run main.nf --help
```

## Development

### Module Structure

```bash
modules/
├── generate_mutation_files.nf    # Parse CSV and create mutation files
├── repair_structures.nf          # FoldX structure repair
├── run_buildmodel.nf             # FoldX BuildModel execution
├── calculate_ddg.nf              # ΔΔG calculation
└── parse_fxout.nf                # FoldX output parsing
```

### Adding New Features

1. Create new modules in `modules/` directory
2. Update workflow in `workflows/foldx_analysis.nf`
3. Add tests and documentation

## Citation

If you use this pipeline in your research, please cite:

- **Nextflow**: Di Tommaso, P., Chatzou, M., Floden, E. W., Barja, P. P., Palumbo, E., & Notredame, C. (2017). Nextflow enables reproducible computational workflows. Nature Biotechnology, 35(4), 316-319. <https://doi.org/10.1038/nbt.3820>

- **FoldX**: Schymkowitz, J., Borg, J., Stricher, F., Nys, R., Rousseau, F., & Serrano, L. (2005). The FoldX web server: an online force field. Nucleic acids research, 33(suppl_2), W382-W388. <https://doi.org/10.1093/nar/gki387>

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For questions or issues, please open an issue on the GitHub repository.
