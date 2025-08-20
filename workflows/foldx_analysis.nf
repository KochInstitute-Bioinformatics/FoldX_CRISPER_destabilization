include { GENERATE_MUTATION_FILES } from '../modules/generate_mutation_files'
include { REPAIR_STRUCTURES_CONDITIONAL } from '../modules/repair_structures_conditional'
include { RUN_BUILDMODEL } from '../modules/run_buildmodel'
include { CALCULATE_DDG } from '../modules/calculate_ddg'

workflow FOLDX_ANALYSIS {
    main:
    // Input validation
    if (!params.mutation_csv) error "Please provide --mutation_csv"
    if (!params.foldx_path) error "Please provide --foldx_path"
    
    // Create input channels
    mutation_csv_ch = Channel.fromPath(params.mutation_csv, checkIfExists: true)
    pdb_files_ch = Channel.fromPath("${params.structure_dir}/*.pdb", checkIfExists: true)
    parse_script_ch = Channel.fromPath("${projectDir}/bin/parse_mutations.py", checkIfExists: true)
    
    // Step 1: Generate mutation files
    GENERATE_MUTATION_FILES(
        mutation_csv_ch,
        params.chain,
        parse_script_ch
    )
    
    // Step 2: Repair structures
    REPAIR_STRUCTURES_CONDITIONAL(
        GENERATE_MUTATION_FILES.out.genes,
        params.foldx_path,
        pdb_files_ch.collect(),
        params.repaired_structures_dir ?: ""
    )
    
    // Step 3: Prepare mutation-structure pairs (no replicates)
    mutation_files = GENERATE_MUTATION_FILES.out.mutation_files
        .flatten()
        .map { file ->
            // Parse filename: individual_list_GENE_MUTATION.txt
            def basename = file.name.replaceAll('^individual_list_', '').replaceAll('\\.txt$', '')
            def parts = basename.split('_')
            def gene = parts[0]
            def mutation = parts[1..-1].join('_')
            [gene, mutation, file]
        }
    
    repaired_files = REPAIR_STRUCTURES_CONDITIONAL.out.repaired_pdbs
        .flatten()
        .map { file ->
            def gene = file.name.replaceAll('_Repair\\.pdb$', '')
            [gene, file]
        }
    
    // Combine mutation files with repaired structures
    mutation_repair_pairs = mutation_files
        .combine(repaired_files, by: 0)
        .map { gene, mutation, mut_file, repair_file ->
            [gene, mutation, mut_file, repair_file]
        }
    
    // Step 4: Run BuildModel (FoldX handles multiple runs internally)
    RUN_BUILDMODEL(
        mutation_repair_pairs,
        params.foldx_path,
        params.number_of_runs
    )
    
    // Step 5: Calculate ΔΔG
    foldx_results = RUN_BUILDMODEL.out.foldx_results
        .map { _gene, _mutation, files -> files }
        .flatten()
        .collect()
    
    parse_fxout_script = Channel.fromPath("${projectDir}/bin/parse_fxout.py", checkIfExists: true)
    
    CALCULATE_DDG(
        foldx_results,
        parse_fxout_script
    )
    
    emit:
    final_results = CALCULATE_DDG.out.final_results
}