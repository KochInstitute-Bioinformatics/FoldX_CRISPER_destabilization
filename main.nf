#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { FOLDX_ANALYSIS } from './workflows/foldx_analysis'

workflow {
    // Run the analysis
    FOLDX_ANALYSIS()

    // Display results
    if (FOLDX_ANALYSIS.out.individual_results) {
        FOLDX_ANALYSIS.out.individual_results.view { gene, mutation, replicate, fxout_files ->
            "Individual results for ${gene} ${mutation} replicate ${replicate}: ${fxout_files}"
        }
    }

    if (FOLDX_ANALYSIS.out.final_results) {
        FOLDX_ANALYSIS.out.final_results.view { result_file ->
            "Final ΔΔG results: ${result_file}"
        }
    }
}