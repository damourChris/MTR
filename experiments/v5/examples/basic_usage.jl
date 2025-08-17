"""
Basic usage example for V5 repository-based framework.

Demonstrates the core functionality of the V5 system including:
- Repository creation and configuration
- Memory management
- Basic data storage and retrieval
- Preference management
"""

using CellTypeDeconvolutionFrameworkV5

println("=== Cell Type Deconvolution Framework V5 - Basic Usage Example ===\n")

# =============================================================================
# 1. REPOSITORY CREATION AND CONFIGURATION
# =============================================================================

println("1. Creating and configuring repository...")

# Create a memory repository with custom settings
repo = MemoryRepository(memory_limit_gb = 2.0, max_items = 1000, eviction_threshold = 0.8)

println("   ✓ Created memory repository")
println("   ✓ Memory limit: $(get_repository_memory_limit_gigabytes()) GB")
println("   ✓ Cache eviction threshold: $(get_cache_eviction_threshold_ratio())")

# =============================================================================
# 2. PREFERENCE MANAGEMENT
# =============================================================================

println("\n2. Managing preferences...")

# Display current preferences
preferences = get_all_v5_preferences()
println("   ✓ Total preferences configured: $(length(preferences))")

# Modify some preferences
original_threshold = get_gene_correlation_threshold_value()
set_gene_correlation_threshold_value!(0.4)
println(
    "   ✓ Changed gene correlation threshold: $(original_threshold) → $(get_gene_correlation_threshold_value())",
)

original_max_edges = get_maximum_edges_per_gene_node_count()
set_maximum_edges_per_gene_node_count!(20)
println(
    "   ✓ Changed max edges per gene: $(original_max_edges) → $(get_maximum_edges_per_gene_node_count())",
)

# =============================================================================
# 3. BASIC DATA STORAGE AND RETRIEVAL
# =============================================================================

println("\n3. Storing and retrieving data...")

# Store some sample data
sample_data = Dict(
    "gene_expression" => randn(1000, 10),  # 1000 genes × 10 samples
    "cell_types" => ["T_cell", "B_cell", "NK_cell", "Monocyte"],
    "metadata" => Dict("dataset" => "example", "version" => "1.0"),
)

for (key, data) in sample_data
    repo[key] = data
    println("   ✓ Stored data: $key (size: $(estimate_memory_usage(data) ÷ 1024) KB)")
end

# Retrieve data
retrieved_expression = repo["gene_expression"]
retrieved_cell_types = repo["cell_types"]

println("   ✓ Retrieved gene expression data: $(size(retrieved_expression))")
println("   ✓ Retrieved cell types: $(length(retrieved_cell_types)) types")

# Check repository status
stats = get_cache_statistics(repo)
println("   ✓ Repository contains $(stats["cached_items"]) items")
println("   ✓ Memory usage: $(round(stats["memory_usage_gb"], digits=3)) GB")

# =============================================================================
# 4. CACHE KEY MANAGEMENT
# =============================================================================

println("\n4. Cache key management...")

# Generate cache keys for different scenarios
parameters1 = Dict("correlation_threshold" => 0.3, "max_edges" => 15)
parameters2 = Dict("correlation_threshold" => 0.4, "max_edges" => 20)

key1 = generate_cache_key("gene_graph", parameters1)
key2 = generate_cache_key("gene_graph", parameters2)

println("   ✓ Generated cache key 1: $(key1[1:20])...")
println("   ✓ Generated cache key 2: $(key2[1:20])...")
println("   ✓ Keys are different: $(key1 != key2)")

# Validate cache keys
println("   ✓ Key 1 valid: $(validate_repository_key(key1))")
println("   ✓ Key 2 valid: $(validate_repository_key(key2))")

# =============================================================================
# 5. MEMORY MANAGEMENT DEMONSTRATION
# =============================================================================

println("\n5. Memory management...")

# Create some large data to test memory limits
large_data_items = []
for i in 1:5
    large_array = randn(500, 500)  # ~2MB each
    key = "large_data_$i"
    repo[key] = large_array
    push!(large_data_items, key)

    current_stats = get_cache_statistics(repo)
    println(
        "   ✓ Stored $key, memory usage: $(round(current_stats["memory_usage_gb"], digits=3)) GB",
    )
end

# Check final statistics
final_stats = get_cache_statistics(repo)
println("   ✓ Final repository statistics:")
println("     - Items: $(final_stats["cached_items"])")
println("     - Memory usage: $(round(final_stats["memory_usage_gb"], digits=3)) GB")
println("     - Memory ratio: $(round(final_stats["memory_usage_ratio"], digits=3))")
println("     - Hit rate: $(round(final_stats["hit_rate"], digits=3))")

# =============================================================================
# 6. ERROR HANDLING DEMONSTRATION
# =============================================================================

println("\n6. Error handling...")

# Try to access non-existent key
try
    repo["non_existent_key"]
catch e
    if isa(e, CacheKeyNotFoundError)
        println("   ✓ Caught expected CacheKeyNotFoundError")
    else
        println("   ✗ Unexpected error type: $(typeof(e))")
    end
end

# Try invalid key format
try
    validate_repository_key("invalid//key") || throw(ArgumentError("Invalid key format"))
catch e
    println("   ✓ Caught invalid key format error")
end

# =============================================================================
# 7. CLEANUP AND RESTORATION
# =============================================================================

println("\n7. Cleanup...")

# Clear the repository
clear_cache!(repo)
cleanup_stats = get_cache_statistics(repo)
println("   ✓ Cleared repository, items remaining: $(cleanup_stats["cached_items"])")

# Restore original preferences
set_gene_correlation_threshold_value!(original_threshold)
set_maximum_edges_per_gene_node_count!(original_max_edges)
println("   ✓ Restored original preferences")

# =============================================================================
# 8. SUMMARY
# =============================================================================

println("\n=== Summary ===")
println("✓ Repository creation and configuration")
println("✓ Preference management system")
println("✓ Data storage and retrieval")
println("✓ Cache key generation and validation")
println("✓ Memory management and monitoring")
println("✓ Error handling and validation")
println("✓ Cleanup and preference restoration")

println("\n🎉 V5 basic functionality demonstration completed successfully!")
println("\nNext steps:")
println("   - Explore graph construction with ontology data")
println("   - Try file-based repositories for persistent caching")
println("   - Integrate with real cell type deconvolution workflows")
