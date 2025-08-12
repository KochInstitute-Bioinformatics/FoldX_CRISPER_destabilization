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
        
        // Create channel for PDB files - stage them for container access
        pdb_files_ch = Channel.fromPath("${params.structure_dir}/*.pdb", checkIfExists: true)

        // Step 1: Generate individual mutation files
        GENERATE_MUTATION_FILES(
            mutation_csv_ch,
            params.chain
        )

        // Step 2: Repair PDB structures - now with staged PDB files
        REPAIR_STRUCTURES(
            GENERATE_MUTATION_FILES.out.genes,
            foldx_path_ch,
            pdb_files_ch.collect()  // Collect all PDB files for staging
        )

        // Step 3: Run FoldX BuildModel for WT and mutants
        RUN_BUILDMODEL(
            GENERATE_MUTATION_FILES.out.mutation_files,
            REPAIR_STRUCTURES.out.repaired_pdbs,
            foldx_path_ch,
            pdb_files_ch.collect()  // Add the 4th input
        )

        // Step 4: Collect all FoldX results into a single directory
        foldx_results_collected = RUN_BUILDMODEL.out.foldx_results.collect()

        // Step 5: Calculate ΔΔG values
        CALCULATE_DDG(
            foldx_results_collected,
            mutation_csv_ch
        )
        
    emit:
        results = CALCULATE_DDG.out.final_results
}