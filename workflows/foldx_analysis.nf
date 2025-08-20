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

        // Step 2: Repair PDB structures (with caching support)
        REPAIR_STRUCTURES(
            GENERATE_MUTATION_FILES.out.genes,
            foldx_path_ch,
            pdb_files_ch.collect()
        )

        // Step 3: Prepare mutation-repair file pairs
        mutation_files_with_info = GENERATE_MUTATION_FILES.out.mutation_files
            .flatten()
            .map { file ->
                def filename = file.name
                def basename = filename.replaceAll('\\.individual_list\\.txt$', '')
                def parts = basename.split('_')
                def gene = parts[0]
                def mutation = parts.size() > 1 ? parts[1..-1].join('_') : 'WT'
                [gene, mutation, file]
            }

        repair_files_with_gene = REPAIR_STRUCTURES.out.repaired_pdbs
            .flatten()
            .map { file ->
                def gene = file.name.replaceAll('_Repair\\.pdb$', '')
                [gene, file]
            }

        mutation_repair_pairs = mutation_files_with_info
            .combine(repair_files_with_gene, by: 0)
            .map { _gene, mutation, mut_file, repair_file ->
                [_gene, mutation, mut_file, repair_file]
            }

        // Step 4: Create replicates
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

        // Step 6: Collect all foldx results directly for ΔΔG calculation
        foldx_results_files = RUN_BUILDMODEL.out.foldx_results
            .map { _gene, _mutation, _replicate, fxout_files -> fxout_files }
            .flatten()
            .collect()

        // Step 7: Create channels for bin scripts
        parse_energies_script = Channel.fromPath("${projectDir}/bin/parse_energies.py", checkIfExists: true)
        parse_fxout_script = Channel.fromPath("${projectDir}/bin/parse_fxout.py", checkIfExists: true)

        // Step 8: Calculate ΔΔG values using individual results
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