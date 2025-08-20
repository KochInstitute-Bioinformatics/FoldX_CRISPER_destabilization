#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { FOLDX_ANALYSIS } from './workflows/foldx_analysis'

workflow {
    FOLDX_ANALYSIS()
}