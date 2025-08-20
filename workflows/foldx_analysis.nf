include { GENERATE_MUTATION_FILES } from '../modules/generate_mutation_files'
include { REPAIR_STRUCTURES } from '../modules/repair_structures'
include { RUN_BUILDMODEL } from '../modules/run_buildmodel'
include { COMBINE_REPLICATES } from '../modules/combine_replicates'
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
    
    // Step 4: Create replicates - THIS IS THE KEY CHANGE!
    mutation_repair_replicates = mutation_repair_pairs
        .flatMap { gene, mutation, mut_file, repair_file ->
            (1..params.number_of_runs).collect { replicate ->
                [gene, mutation, mut_file, repair_file, replicate]
            }
        }
    
    // Step 5: Run FoldX BuildModel for each replicate
    RUN_BUILDMODEL(
        mutation_repair_replicates,
        foldx_path_ch
    )
    
    // Step 6: Group results by gene and mutation, then combine replicates
    foldx_results_grouped = RUN_BUILDMODEL.out.foldx_results
        .map { gene, mutation, _replicate, fxout_files ->
            [gene, mutation, fxout_files]
        }
        .groupTuple(by: [0, 1]) // Group by gene and mutation
        .map { gene, mutation, fxout_files_list ->
            [gene, mutation, fxout_files_list.flatten()]
        }
    
    // Step 7: Combine replicates into summary files
    COMBINE_REPLICATES(foldx_results_grouped)
    
    // Step 8: Calculate ΔΔG values using combined results
    // Collect the combined .fxout files from COMBINE_REPLICATES output
    combined_foldx_files = COMBINE_REPLICATES.out.combined_results
        .map { _gene, _mutation, combined_file -> combined_file }
        .collect()
    
    CALCULATE_DDG(
        combined_foldx_files,
        mutation_csv_ch
    )
    
    emit:
    individual_results = RUN_BUILDMODEL.out.foldx_results
    combined_results = COMBINE_REPLICATES.out.combined_results
    summary_stats = COMBINE_REPLICATES.out.summary_stats
    final_results = CALCULATE_DDG.out.final_results
}