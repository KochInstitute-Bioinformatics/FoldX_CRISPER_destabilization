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
    pdb_files_ch = Channel.fromPath("${params.structure_dir}/*.pdb", checkIfExists: true)

    // Step 1: Generate individual mutation files
    GENERATE_MUTATION_FILES(
        mutation_csv_ch,
        params.chain
    )

    // Step 2: Repair PDB structures
    REPAIR_STRUCTURES(
        GENERATE_MUTATION_FILES.out.genes,
        foldx_path_ch,
        pdb_files_ch.collect()
    )

    // Step 3: Prepare mutation-repair file pairs
    // Create a channel that pairs each mutation file with its corresponding repaired PDB
    mutation_files_with_info = GENERATE_MUTATION_FILES.out.mutation_files
        .flatten()
        .map { file ->
            // Extract gene and mutation from filename
            def filename = file.name
            def basename = filename.replaceAll('\\.individual_list\\.txt$', '')
            def parts = basename.split('_')
            def gene = parts[0]
            def mutation = parts.size() > 1 ? parts[1..-1].join('_') : 'WT'
            [gene, mutation, file]
        }

    // Create repair files channel with gene info
    repair_files_with_gene = REPAIR_STRUCTURES.out.repaired_pdbs
        .flatten()
        .map { file ->
            def gene = file.name.replaceAll('_Repair\\.pdb$', '')
            [gene, file]
        }

    // Combine mutation files with their corresponding repair files
    mutation_repair_pairs = mutation_files_with_info
        .combine(repair_files_with_gene, by: 0)
        .map { _gene, mutation, mut_file, repair_file ->
            [_gene, mutation, mut_file, repair_file]
        }

    // Step 4: Run FoldX BuildModel
    RUN_BUILDMODEL(
        mutation_repair_pairs,
        foldx_path_ch
    )

    // Step 5: Calculate ΔΔG values
    // Collect only the .fxout files from RUN_BUILDMODEL output
    foldx_results_files = RUN_BUILDMODEL.out.foldx_results
        .map { _gene, _mutation, fxout_files -> fxout_files }
        .flatten()
        .collect()

    CALCULATE_DDG(
        foldx_results_files,
        mutation_csv_ch
    )

    emit:
    results = CALCULATE_DDG.out.final_results
}