include { PARSE_FXOUT } from '../modules/parse_fxout'
include { GENERATE_MUTATION_FILES } from '../modules/generate_mutation_files'
include { REPAIR_STRUCTURES } from '../modules/repair_structures'
include { RUN_BUILDMODEL } from '../modules/run_buildmodel'
include { CALCULATE_DDG } from '../modules/calculate_ddg'

workflow FOLDX_ANALYSIS {

    main:
        // Input validation
        if (!params.mutation_csv) {
            error "Please provide a mutation CSV file with --mutation_csv"
        }
        if (!params.foldx_path) {
            error "Please provide the FoldX executable path with --foldx_path"
        }

        // Create input channels
        mutation_csv_ch = Channel.fromPath(params.mutation_csv, checkIfExists: true)
        foldx_path_ch = Channel.value(params.foldx_path)
        structure_dir_ch = Channel.value(params.structure_dir)

        // Step 1: Generate individual mutation files
        GENERATE_MUTATION_FILES(
            mutation_csv_ch,
            params.chain
        )

        // Step 2: Repair PDB structures
        REPAIR_STRUCTURES(
            GENERATE_MUTATION_FILES.out.genes,
            foldx_path_ch,
            structure_dir_ch
        )

        // Step 3: Run FoldX BuildModel for WT and mutants
        RUN_BUILDMODEL(
            GENERATE_MUTATION_FILES.out.mutation_files,
            REPAIR_STRUCTURES.out.repaired_pdbs,
            foldx_path_ch,
            structure_dir_ch
        )

        // Step 4: Calculate ΔΔG values
        CALCULATE_DDG(
            RUN_BUILDMODEL.out.foldx_results,
            mutation_csv_ch
        )

    emit:
        results = CALCULATE_DDG.out.final_results
}