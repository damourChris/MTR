#!/usr/bin/env julia

"""
Main entry point for Cell Type Deconvolution Framework V5.

This script provides a command-line interface to demonstrate and test
the repository-based framework functionality with intelligent caching,
memory management, and GNN graph construction capabilities.

Usage:
    julia main.jl --demo                           # Run demonstration
    julia main.jl --test-framework                 # Test framework functionality
    julia main.jl --gnn-training                   # Run GNN training demo
    julia main.jl --memory-limit 4.0               # Set memory limit
    julia main.jl --cache-dir /custom/cache        # Set cache directory

For help:
    julia main.jl --help
"""

using Pkg
Pkg.activate(@__DIR__)

# Load the framework
include("src/CellTypeDeconvolutionFramework.jl")
using .CellTypeDeconvolutionFramework

using ArgParse
using Dates

include("examples/gnn_training_demo.jl")

"""
Parse command line arguments for framework operations.
"""
function parse_command_line_arguments()
    settings = ArgParseSettings(
        description = "Command line arguments for Cell Type Deconvolution Framework",
        commands_are_required = false,
        help_alignment_width = 30,
        epilog = "For more information, visit the documentation.",
    )

    add_arg_group!(settings, "preprocessing")

    @add_arg_table! settings begin
        "preprocess", "prep"
        help = "Run preprocessing steps on input data"
        action = :command
    end

    add_arg_group!(settings, "demonstration")

    @add_arg_table! settings begin
        "demonstration", "demo"
        help = "Run comprehensive framework demonstration"
        action = :command

        "gnn-training"
        help = "Run advanced GNN training demo with GSE22886 data"
        action = :command
    end

    add_arg_group!(settings, "testing")
    @add_arg_table! settings begin
        "test"
        help = "Run framework functionality tests"
        action = :command

        "benchmark", "bench"
        help = "Run performance benchmarks"
        action = :command
    end

    add_arg_group!(settings, "config")

    @add_arg_table! settings begin
        "configure", "config"
        help = "Configure framework settings"
        action = :command

        "show-config", "show"
        help = "Show current framework configuration"
        action = :command

        "--cache-dir"
        help = "Set custom cache directory path"
        arg_type = String
        default = ""

        "--max-items"
        help = "Maximum number of items in memory repository"
        arg_type = Int
        default = 10000

        "--memory-limit"
        help = "Set memory limit in GB for repositories"
        arg_type = Float64
        default = 2.0
    end

    add_arg_group!(settings, "cache")

    @add_arg_table! settings begin
        "clear-cache", "clear"
        help = "Clear all cached data"
        action = :command

        "--force"
        help = "Force clear cache without confirmation"
        action = :store_true
    end

    add_arg_group!(settings, "settings")

    @add_arg_table! settings begin
        "--log-level"
        help = "Sets log level (overrides preferences)"
        arg_type = String
        default = "INFO"
    end

    return parse_args(settings)
end

"""
Configure framework from command line arguments.
"""
function configure_framework_from_arguments(args::Dict{String, Any})
    # Set memory limit
    if args["memory-limit"] != 2.0
        try
            CellTypeDeconvolutionFramework.set_memory_limit_gb!(args["memory-limit"])
        catch
            CellTypeDeconvolutionFramework.set_repository_memory_limit_gigabytes!(
                args["memory-limit"],
            )
        end
        println("✓ Memory limit set to $(args["memory-limit"]) GB")
    end

    # Set cache directory
    if !isempty(args["cache-dir"])
        try
            CellTypeDeconvolutionFramework.set_cache_directory_path!(args["cache-dir"])
        catch
            CellTypeDeconvolutionFramework.set_repository_cache_directory_path!(
                args["cache-dir"],
            )
        end
        println("✓ Cache directory set to $(args["cache-dir"])")
    end
end

"""
Display current framework configuration.
"""
function display_framework_configuration()
    println("📊 Current Framework Configuration")
    println("="^40)

    println("Memory Management:")
    try
        println(
            "   • Memory limit: $(CellTypeDeconvolutionFramework.get_memory_limit_gb()) GB",
        )
    catch
        println(
            "   • Memory limit: $(CellTypeDeconvolutionFramework.get_repository_memory_limit_gigabytes()) GB",
        )
    end

    try
        println(
            "   • Cache directory: $(CellTypeDeconvolutionFramework.get_cache_directory_path())",
        )
    catch
        println(
            "   • Cache directory: $(CellTypeDeconvolutionFramework.get_repository_cache_directory_path())",
        )
    end

    println("\nRepository Settings:")
    # Use try-catch for functions that might not be exported
    try
        println(
            "   • Cache eviction threshold: $(CellTypeDeconvolutionFramework.get_cache_eviction_threshold_ratio())",
        )
    catch
        println("   • Cache eviction threshold: [Not available]")
    end

    try
        println(
            "   • Compression enabled: $(CellTypeDeconvolutionFramework.get_cache_compression_enabled_flag())",
        )
    catch
        println("   • Compression enabled: [Not available]")
    end

    try
        println(
            "   • Integrity checking: $(CellTypeDeconvolutionFramework.get_cache_integrity_checking_enabled_flag())",
        )
    catch
        println("   • Integrity checking: [Not available]")
    end

    println("\nGraph Construction:")
    try
        println(
            "   • Gene correlation threshold: $(CellTypeDeconvolutionFramework.get_gene_correlation_threshold_value())",
        )
    catch
        println("   • Gene correlation threshold: [Not available]")
    end

    try
        println(
            "   • Max edges per gene: $(CellTypeDeconvolutionFramework.get_maximum_edges_per_gene_node_count())",
        )
    catch
        println("   • Max edges per gene: [Not available]")
    end

    try
        println(
            "   • Include ontology edges: $(CellTypeDeconvolutionFramework.get_include_ontology_hierarchy_edges_flag())",
        )
    catch
        println("   • Include ontology edges: [Not available]")
    end

    # Memory usage statistics
    try
        memory_stats = CellTypeDeconvolutionFramework.get_memory_usage_statistics()
        println("\nSystem Memory:")
        println("   • Available: $(round(memory_stats["available_gb"], digits=2)) GB")
        println("   • Used: $(round(memory_stats["used_gb"], digits=2)) GB")
        println("   • Usage ratio: $(round(memory_stats["usage_ratio"], digits=3))")
    catch
        println("\nSystem Memory: [Not available]")
    end
end

"""
Run comprehensive framework demonstration.
"""
function run_framework_demonstration()
    println("🚀 Cell Type Deconvolution Framework V5 - Demonstration")
    println("="^55)

    # 1. Create repository
    println("\n1. Creating Memory Repository...")
    local memory_limit
    try
        memory_limit = CellTypeDeconvolutionFramework.get_memory_limit_gb()
    catch
        memory_limit =
            CellTypeDeconvolutionFramework.get_repository_memory_limit_gigabytes()
    end
    repo = create_memory_repository(memory_limit_gb = memory_limit, max_items = 1000)
    println("   ✓ Repository created successfully")

    # 2. Store sample data
    println("\n2. Storing Sample Data...")

    # Generate synthetic gene expression data
    n_genes, n_samples = 500, 20
    gene_expression = randn(n_genes, n_samples)
    repo["gene_expression"] = gene_expression
    println("   ✓ Stored gene expression data ($(n_genes) genes × $(n_samples) samples)")

    # Store cell type labels
    cell_types = ["T_cell", "B_cell", "NK_cell", "Monocyte", "Dendritic_cell"]
    repo["cell_types"] = cell_types
    println("   ✓ Stored cell type labels ($(length(cell_types)) types)")

    # Store metadata
    metadata = Dict(
        "dataset" => "demonstration_data",
        "created" => string(now()),
        "version" => "5.0",
        "n_genes" => n_genes,
        "n_samples" => n_samples,
    )
    repo["metadata"] = metadata
    println("   ✓ Stored metadata")

    # 3. Demonstrate retrieval
    println("\n3. Retrieving Data...")
    retrieved_expression = repo["gene_expression"]
    retrieved_metadata = repo["metadata"]

    println("   ✓ Retrieved gene expression: $(size(retrieved_expression))")
    println("   ✓ Retrieved metadata: $(retrieved_metadata["dataset"])")

    # 4. Cache key demonstration
    println("\n4. Cache Key Management...")

    # Generate cache keys for different parameters
    params1 = Dict("threshold" => 0.3, "method" => "correlation")
    params2 = Dict("threshold" => 0.4, "method" => "mutual_info")

    key1 = generate_cache_key("gene_network", params1)
    key2 = generate_cache_key("gene_network", params2)

    println("   ✓ Generated cache keys for different parameters")
    println("   • Key 1: $(key1[1:16])...")
    println("   • Key 2: $(key2[1:16])...")
    println("   • Keys different: $(key1 != key2)")

    # 5. Memory management
    println("\n5. Memory Management...")

    # Store progressively larger data to test memory limits
    for i in 1:3
        large_data = randn(200, 200)  # ~320KB each
        repo["large_data_$i"] = large_data
    end

    println("   ✓ Stored multiple large datasets")

    # 6. Repository statistics
    println("\n6. Repository Statistics...")
    println("   • Total items: $(length(keys(repo)))")
    println("   • Available keys: $(join(sort(collect(keys(repo))), ", "))")

    # 7. Cleanup
    println("\n7. Cleanup...")
    delete!(repo, "large_data_1")
    delete!(repo, "large_data_2")
    delete!(repo, "large_data_3")
    println("   ✓ Cleaned up large datasets")

    return println("\n✅ Framework demonstration completed successfully!")
end

"""
Run performance benchmarks.
"""
function run_performance_benchmarks()
    println("⚡ Running Performance Benchmarks...")
    println("="^40)

    repo = create_memory_repository(memory_limit_gb = 1.0)

    # Benchmark data storage
    println("\n• Storage Performance:")
    data_sizes = [100, 500, 1000, 2000]

    for size in data_sizes
        data = randn(size, size)

        start_time = time()
        repo["benchmark_$(size)"] = data
        storage_time = time() - start_time

        println("   $(size)×$(size) matrix: $(round(storage_time * 1000, digits=2)) ms")
    end

    # Benchmark data retrieval
    println("\n• Retrieval Performance:")

    for size in data_sizes
        start_time = time()
        retrieved = repo["benchmark_$(size)"]
        retrieval_time = time() - start_time

        println("   $(size)×$(size) matrix: $(round(retrieval_time * 1000, digits=2)) ms")
    end

    # Benchmark cache key generation
    println("\n• Cache Key Generation:")

    start_time = time()
    for i in 1:1000
        key = generate_cache_key("benchmark", Dict("iteration" => i, "data" => randn(10)))
    end
    key_time = time() - start_time

    println("   1000 keys: $(round(key_time * 1000, digits=2)) ms total")
    println("   Average: $(round(key_time, digits=6)) ms per key")

    return println("\n✅ Performance benchmarks completed!")
end

"""
Clear all cached data.
"""
function clear_framework_cache()
    println("🧹 Clearing Framework Cache...")

    cache_dir = get_cache_directory_path()

    if isdir(cache_dir)
        try
            # Remove cache directory contents
            for item in readdir(cache_dir)
                item_path = joinpath(cache_dir, item)
                if isfile(item_path)
                    rm(item_path)
                elseif isdir(item_path)
                    rm(item_path, recursive = true)
                end
            end
            println("   ✓ Cache directory cleared: $cache_dir")
        catch e
            println("   ❌ Error clearing cache: $e")
        end
    else
        println("   ℹ Cache directory does not exist: $cache_dir")
    end
end

"""
Run advanced GNN training demonstration.
"""
function run_gnn_training_demonstration()
    println("🧬 Loading Advanced GNN Training Demo...")

    # Use Base.invokelatest to handle world age issues

    return run_gnn_training_demo()
end

"""
Main execution function.
"""
function main()
    println("🔬 Cell Type Deconvolution Framework V5")
    println("="^40)
    println("Repository-based scientific computing framework")
    println("with intelligent caching and memory management")
    println()

    # Parse command line arguments
    args = parse_command_line_arguments()

    # Configure framework
    configure_framework_from_arguments(args)

    COMMANDS = Dict(
        "demonstration" => run_framework_demonstration,
        "gnn-training" => run_gnn_training_demonstration,
        "test" => run_performance_benchmarks,
        "clear" => clear_framework_cache,
        "config" => display_framework_configuration,
    )

    if !isnothing(args["%COMMAND%"])
        cmd = args["%COMMAND%"]

        COMMANDS[cmd]()
        # try
        # catch
        # end
        # @error "Something went wrong while running $cmd. Check logs for more details."
    end

    # Run commands based on arguments   
    return println("\n🎉 Framework ready for development!")
end

# Execute main function when script is run directly
main()
if abspath(PROGRAM_FILE) == @__FILE__
end
