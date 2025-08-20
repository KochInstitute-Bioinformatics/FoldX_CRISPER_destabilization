include { GENERATE_MUTATION_FILES } from '../modules/generate_mutation_files'
include { CHECK_REPAIRED_FILES } from '../modules/check_repaired_files'
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
    
    // Create channel for the parse script
    parse_mutations_script = Channel.fromPath("${projectDir}/bin/parse_mutations.py", checkIfExists: true)
    
    // Step 1: Generate individual mutation files (only for actual mutations, not WT)
    GENERATE_MUTATION_FILES(
        mutation_csv_ch,
        params.chain,
        parse_mutations_script
    )
    
    // Step 2: Check for existing repaired files
    CHECK_REPAIRED_FILES(
        GENERATE_MUTATION_FILES.out.genes,
        params.repaired_structures_dir ?: ""
    )
    
    // Step 3: Repair only structures that need it
    REPAIR_STRUCTURES(
        CHECK_REPAIRED_FILES.out.genes_to_repair,
        foldx_path_ch,
        pdb_files_ch.collect()
    )
    
    // Step 4: Combine existing and newly repaired structures
    existing_repaired_ch = CHECK_REPAIRED_FILES.out.existing_files
        .splitText() { it.trim() }
        .filter { it != "" }
        .map { file_path -> file(file_path) }
    
    all_repaired_pdbs = existing_repaired_ch
        .mix(REPAIR_STRUCTURES.out.repaired_pdbs.flatten())
    
    // Step 5: Prepare mutation files with their corresponding repaired structures
    mutation_files_with_info = GENERATE_MUTATION_FILES.out.mutation_files
        .flatten()
        .map { file ->
            def filename = file.name
            def basename = filename.replaceAll('\\.individual_list\\.txt$', '')
            def parts = basename.split('_')
            def gene = parts[0]
            def mutation = parts[1..-1].join('_') // Only actual mutations, no WT
            [gene, mutation, file]
        }
    
    repair_files_with_gene = all_repaired_pdbs
        .map { file ->
            def gene = file.name.replaceAll('_Repair\\.pdb$', '')
            [gene, file]
        }
    
    // Combine mutation files with their corresponding repaired structures
    mutation_repair_pairs = mutation_files_with_info
        .combine(repair_files_with_gene, by: 0)
        .map { gene, mutation, mut_file, repair_file ->
            [gene, mutation, mut_file, repair_file]
        }
    
    // Step 6: Create replicates for each mutation
    mutation_repair_replicates = mutation_repair_pairs
        .flatMap { gene, mutation, mut_file, repair_file ->
            (1..params.number_of_runs).collect { replicate ->
                [gene, mutation, mut_file, repair_file, replicate]
            }
        }
    
    // Step 7: Run FoldX BuildModel for each mutation replicate
    RUN_BUILDMODEL(
        mutation_repair_replicates,
        foldx_path_ch
    )
    
    // Step 8: Collect all FoldX results for ΔΔG calculation
    foldx_results_files = RUN_BUILDMODEL.out.foldx_results
        .map { _gene, _mutation, _replicate, fxout_files -> fxout_files }
        .flatten()
        .collect()
    
    // Step 9: Create channels for analysis scripts
    parse_energies_script = Channel.fromPath("${projectDir}/bin/parse_energies.py", checkIfExists: true)
    parse_fxout_script = Channel.fromPath("${projectDir}/bin/parse_fxout.py", checkIfExists: true)
    
    // Step 10: Calculate ΔΔG values
    CALCULATE_DDG(
        foldx_results_files,
        mutation_csv_ch,
        parse_energies_script,
        parse_fxout_script
    )
    
    emit:
    individual_results = RUN_BUILDMODEL.out.foldx_results
    final_results = CALCULATE_DDG.out.final_results
}