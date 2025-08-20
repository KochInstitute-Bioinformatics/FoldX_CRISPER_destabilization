#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { FOLDX_ANALYSIS } from './workflows/foldx_analysis'

workflow {
    // Run the analysis (no parameters needed - it reads from params directly)
    FOLDX_ANALYSIS()
    
    // Display results only if the outputs exist
    if (FOLDX_ANALYSIS.out.combined_results) {
        FOLDX_ANALYSIS.out.combined_results.view { gene, mutation, combined_file ->
            "Combined results for ${gene} ${mutation}: ${combined_file}"
        }
    }
    
    if (FOLDX_ANALYSIS.out.summary_stats) {
        FOLDX_ANALYSIS.out.summary_stats.view { gene, mutation, stats_file ->
            "Summary statistics for ${gene} ${mutation}: ${stats_file}"
        }
    }
    
    // Also display the final results from your existing CALCULATE_DDG process
    if (FOLDX_ANALYSIS.out.final_results) {
        FOLDX_ANALYSIS.out.final_results.view { result_file ->
            "Final ΔΔG results: ${result_file}"
        }
    }
}