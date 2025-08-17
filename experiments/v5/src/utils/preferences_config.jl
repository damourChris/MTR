"""
Preferences management system for repository-based framework.

Extended preference system with repository-specific settings for caching,
memory management, and graph construction. Provides type-safe preference
access with comprehensive validation.
"""

using Preferences
using UUIDs

# =============================================================================
# PACKAGE UUID AND CUSTOM PREFERENCE MACROS
# =============================================================================

# Package UUID 
const PACKAGE_UUID = UUID("397a954a-eee4-4c2c-bf5a-8e415b85b77e")

"""
Custom macro that works like @has_preference
"""
macro has_framework_preference(key)
    return quote
        Preferences.has_preference($PACKAGE_UUID, $(esc(key)))
    end
end

"""
Custom macro that works like @load_preference 
"""
macro load_framework_preference(key, default = nothing)
    if default === nothing
        return quote
            Preferences.load_preference($PACKAGE_UUID, $(esc(key)))
        end
    else
        return quote
            Preferences.load_preference($PACKAGE_UUID, $(esc(key)), $(esc(default)))
        end
    end
end

"""
Custom function that works like @set_preferences! 
"""
function set_framework_preference!(key::String, value; force::Bool = true)
    return Preferences.set_preferences!(PACKAGE_UUID, key => value; force = force)
end

"""
Custom function that works like @delete_preferences! 
"""
function delete_framework_preferences!(keys...)
    return Preferences.delete_preferences!(PACKAGE_UUID, keys...)
end

# =============================================================================
# PREFERENCE INITIALIZATION
# =============================================================================

"""
    initialize_framework_preferences!()

Initialize all framework preferences with sensible defaults.

Sets up repository configuration, memory management, caching, and graph
construction parameters. Called automatically when the module loads.
"""
function initialize_framework_preferences!()
    # Repository and caching configuration
    @has_framework_preference("repository_cache_directory") || set_framework_preference!(
        "repository_cache_directory",
        joinpath(homedir(), ".framework_cache"),
    )
    @has_framework_preference("repository_memory_limit_gb") || set_framework_preference!(
        "repository_memory_limit_gb",
        detect_system_memory_gb() * 0.5,
    )
    @has_framework_preference("cache_eviction_threshold") ||
        set_framework_preference!("cache_eviction_threshold", 0.8)
    @has_framework_preference("cache_compression_enabled") ||
        set_framework_preference!("cache_compression_enabled", true)
    @has_framework_preference("cache_integrity_checking") ||
        set_framework_preference!("cache_integrity_checking", true)

    # Data source preferences
    @has_framework_preference("enable_reference_data_caching") ||
        set_framework_preference!("enable_reference_data_caching", true)
    @has_framework_preference("enable_ontology_data_caching") ||
        set_framework_preference!("enable_ontology_data_caching", true)
    @has_framework_preference("enable_graph_construction_caching") ||
        set_framework_preference!("enable_graph_construction_caching", true)
    @has_framework_preference("enable_synthetic_data_caching") ||
        set_framework_preference!("enable_synthetic_data_caching", true)

    # Graph construction parameters
    @has_framework_preference("gene_correlation_threshold") ||
        set_framework_preference!("gene_correlation_threshold", 0.3)
    @has_framework_preference("maximum_edges_per_gene_node") ||
        set_framework_preference!("maximum_edges_per_gene_node", 15)
    @has_framework_preference("include_ontology_hierarchy_edges") ||
        set_framework_preference!("include_ontology_hierarchy_edges", true)
    @has_framework_preference("ontology_maximum_depth") ||
        set_framework_preference!("ontology_maximum_depth", 5)
    @has_framework_preference("string_database_confidence_threshold") ||
        set_framework_preference!("string_database_confidence_threshold", 0.4)

    # Memory monitoring and performance
    @has_framework_preference("memory_monitoring_interval_seconds") ||
        set_framework_preference!("memory_monitoring_interval_seconds", 30)
    @has_framework_preference("cache_cleanup_interval_minutes") ||
        set_framework_preference!("cache_cleanup_interval_minutes", 60)
    @has_framework_preference("lazy_loading_enabled") ||
        set_framework_preference!("lazy_loading_enabled", true)

    # Logging and debugging
    @has_framework_preference("repository_logging_level") ||
        set_framework_preference!("repository_logging_level", "info")
    @has_framework_preference("cache_operation_logging") ||
        set_framework_preference!("cache_operation_logging", true)
    return @has_framework_preference("memory_usage_logging") ||
           set_framework_preference!("memory_usage_logging", false)
end

"""
    detect_system_memory_gb()::Float64

Detect total system memory in GB for automatic memory limit configuration.
"""
function detect_system_memory_gb()::Float64
    try
        # Try to read from /proc/meminfo (Linux)
        if isfile("/proc/meminfo")
            content = read("/proc/meminfo", String)
            mem_match = match(r"MemTotal:\s+(\d+)\s+kB", content)
            if mem_match !== nothing
                mem_kb = parse(Int, mem_match.captures[1])
                return mem_kb / 1024 / 1024  # Convert KB to GB
            end
        end

        # Fallback: assume 8GB if detection fails
        @warn "Could not detect system memory, defaulting to 8GB"
        return 8.0
    catch e
        @warn "Error detecting system memory: $e, defaulting to 8GB"
        return 8.0
    end
end

# =============================================================================
# REPOSITORY CONFIGURATION ACCESSORS
# =============================================================================

"""
    get_repository_cache_directory_path()::String

Get the directory path where cached data files are stored.
"""
function get_repository_cache_directory_path()::String
    path = @load_framework_preference(
        "repository_cache_directory",
        joinpath(homedir(), ".framework_cache")
    )
    path isa String || throw(ArgumentError("repository_cache_directory must be a string"))
    return path
end

"""
    set_repository_cache_directory_path!(path::String)

Set the directory path for cached data files.

# Arguments
- `path::String`: Absolute path to cache directory
"""
function set_repository_cache_directory_path!(path::String)
    isabs(path) || throw(ArgumentError("Cache directory path must be absolute"))
    set_framework_preference!("repository_cache_directory", path)
    @info "Repository cache directory set to: $path"
end

"""
    get_repository_memory_limit_gigabytes()::Float64

Get the memory limit for repository operations in gigabytes.
"""
function get_repository_memory_limit_gigabytes()::Float64
    limit = @load_framework_preference("repository_memory_limit_gb", 8.0)
    limit isa Real || throw(ArgumentError("repository_memory_limit_gb must be a number"))
    limit_gb = Float64(limit)
    limit_gb > 0 || throw(ArgumentError("repository_memory_limit_gb must be positive"))
    return limit_gb
end

"""
    set_repository_memory_limit_gigabytes!(limit_gb::Real)

Set the memory limit for repository operations.

# Arguments
- `limit_gb::Real`: Memory limit in gigabytes, must be positive
"""
function set_repository_memory_limit_gigabytes!(limit_gb::Real)
    limit_gb > 0 || throw(ArgumentError("Memory limit must be positive"))
    limit_gb <= 1000 || throw(ArgumentError("Memory limit seems unreasonably large (>1TB)"))
    set_framework_preference!("repository_memory_limit_gb", Float64(limit_gb))
    @info "Repository memory limit set to $(Float64(limit_gb)) GB"
end

"""
    get_cache_eviction_threshold_ratio()::Float64

Get the memory usage ratio that triggers cache eviction (0.0 to 1.0).
"""
function get_cache_eviction_threshold_ratio()::Float64
    threshold = @load_framework_preference("cache_eviction_threshold", 0.8)
    threshold isa Real || throw(ArgumentError("cache_eviction_threshold must be a number"))
    threshold_val = Float64(threshold)
    (0.0 <= threshold_val <= 1.0) ||
        throw(ArgumentError("cache_eviction_threshold must be between 0 and 1"))
    return threshold_val
end

"""
    set_cache_eviction_threshold_ratio!(threshold::Real)

Set the memory usage ratio that triggers cache eviction.

# Arguments
- `threshold::Real`: Threshold ratio (0.0 to 1.0), e.g., 0.8 means evict at 80% memory usage
"""
function set_cache_eviction_threshold_ratio!(threshold::Real)
    (0.0 <= threshold <= 1.0) ||
        throw(ArgumentError("Cache eviction threshold must be between 0 and 1"))
    set_framework_preference!("cache_eviction_threshold", Float64(threshold))
    @info "Cache eviction threshold set to $(Float64(threshold))"
end

# =============================================================================
# CACHING BEHAVIOR CONFIGURATION
# =============================================================================

"""
    get_cache_compression_enabled_flag()::Bool

Check if cache compression is enabled for storage efficiency.
"""
function get_cache_compression_enabled_flag()::Bool
    enabled = @load_framework_preference("cache_compression_enabled", true)
    enabled isa Bool || throw(ArgumentError("cache_compression_enabled must be a boolean"))
    return enabled
end

"""
    set_cache_compression_enabled_flag!(enabled::Bool)

Enable or disable cache compression.

# Arguments
- `enabled::Bool`: true to enable compression, false to disable
"""
function set_cache_compression_enabled_flag!(enabled::Bool)
    set_framework_preference!("cache_compression_enabled", enabled)
    @info "Cache compression $(enabled ? "enabled" : "disabled")"
end

"""
    get_cache_integrity_checking_enabled_flag()::Bool

Check if cache integrity checking is enabled.
"""
function get_cache_integrity_checking_enabled_flag()::Bool
    enabled = @load_framework_preference("cache_integrity_checking", true)
    enabled isa Bool || throw(ArgumentError("cache_integrity_checking must be a boolean"))
    return enabled
end

"""
    set_cache_integrity_checking_enabled_flag!(enabled::Bool)

Enable or disable cache integrity checking with checksums.

# Arguments
- `enabled::Bool`: true to enable integrity checking, false to disable
"""
function set_cache_integrity_checking_enabled_flag!(enabled::Bool)
    set_framework_preference!("cache_integrity_checking", enabled)
    @info "Cache integrity checking $(enabled ? "enabled" : "disabled")"
end

# =============================================================================
# DATA SOURCE CACHING CONFIGURATION
# =============================================================================

"""
    get_data_source_caching_configuration()::Dict{String,Bool}

Get the caching configuration for all data source types.
"""
function get_data_source_caching_configuration()::Dict{String, Bool}
    return Dict(
        "reference_data" =>
            @load_framework_preference("enable_reference_data_caching", true),
        "ontology_data" => @load_framework_preference("enable_ontology_data_caching", true),
        "graph_construction" =>
            @load_framework_preference("enable_graph_construction_caching", true),
        "synthetic_data" =>
            @load_framework_preference("enable_synthetic_data_caching", true)
    )
end

"""
    set_data_source_caching_enabled!(data_source::String, enabled::Bool)

Enable or disable caching for a specific data source type.

# Arguments
- `data_source::String`: Data source type ("reference_data", "ontology_data", "graph_construction", "synthetic_data")
- `enabled::Bool`: true to enable caching, false to disable
"""
function set_data_source_caching_enabled!(data_source::String, enabled::Bool)
    valid_sources =
        ["reference_data", "ontology_data", "graph_construction", "synthetic_data"]
    data_source in valid_sources || throw(
        ArgumentError("Invalid data source. Must be one of: $(join(valid_sources, ", "))"),
    )

    preference_key = "enable_$(data_source)_caching"
    set_framework_preference!(preference_key, enabled)
    @info "Caching for $data_source $(enabled ? "enabled" : "disabled")"
end

# =============================================================================
# GRAPH CONSTRUCTION PARAMETERS
# =============================================================================

"""
    get_gene_correlation_threshold_value()::Float64

Get the correlation threshold for creating edges between gene nodes.
"""
function get_gene_correlation_threshold_value()::Float64
    threshold = @load_framework_preference("gene_correlation_threshold", 0.3)
    threshold isa Real ||
        throw(ArgumentError("gene_correlation_threshold must be a number"))
    threshold_val = Float64(threshold)
    (-1.0 <= threshold_val <= 1.0) ||
        throw(ArgumentError("gene_correlation_threshold must be between -1 and 1"))
    return threshold_val
end

"""
    set_gene_correlation_threshold_value!(threshold::Real)

Set the correlation threshold for gene-gene edges in the graph.

# Arguments
- `threshold::Real`: Correlation threshold (-1.0 to 1.0), typically 0.3 to 0.7
"""
function set_gene_correlation_threshold_value!(threshold::Real)
    (-1.0 <= threshold <= 1.0) ||
        throw(ArgumentError("Gene correlation threshold must be between -1 and 1"))
    set_framework_preference!("gene_correlation_threshold", Float64(threshold))
    @info "Gene correlation threshold set to $(Float64(threshold))"
end

"""
    get_maximum_edges_per_gene_node_count()::Int

Get the maximum number of edges allowed per gene node to control graph density.
"""
function get_maximum_edges_per_gene_node_count()::Int
    max_edges = @load_framework_preference("maximum_edges_per_gene_node", 15)
    max_edges isa Integer ||
        throw(ArgumentError("maximum_edges_per_gene_node must be an integer"))
    max_edges_val = Int(max_edges)
    max_edges_val > 0 ||
        throw(ArgumentError("maximum_edges_per_gene_node must be positive"))
    return max_edges_val
end

"""
    set_maximum_edges_per_gene_node_count!(max_edges::Integer)

Set the maximum number of edges per gene node.

# Arguments
- `max_edges::Integer`: Maximum edges per gene node, must be positive
"""
function set_maximum_edges_per_gene_node_count!(max_edges::Integer)
    max_edges > 0 || throw(ArgumentError("Maximum edges per gene node must be positive"))
    max_edges <= 1000 ||
        throw(ArgumentError("Maximum edges per gene node seems unreasonably large"))
    set_framework_preference!("maximum_edges_per_gene_node", Int(max_edges))
    @info "Maximum edges per gene node set to $(Int(max_edges))"
end

"""
    get_include_ontology_hierarchy_edges_flag()::Bool

Check if ontology hierarchy edges should be included in the graph.
"""
function get_include_ontology_hierarchy_edges_flag()::Bool
    include_edges = @load_framework_preference("include_ontology_hierarchy_edges", true)
    include_edges isa Bool ||
        throw(ArgumentError("include_ontology_hierarchy_edges must be a boolean"))
    return include_edges
end

"""
    set_include_ontology_hierarchy_edges_flag!(include_edges::Bool)

Configure whether to include ontology hierarchy edges in the graph.

# Arguments
- `include_edges::Bool`: true to include hierarchy edges, false to exclude
"""
function set_include_ontology_hierarchy_edges_flag!(include_edges::Bool)
    set_framework_preference!("include_ontology_hierarchy_edges", include_edges)
    @info "Ontology hierarchy edges $(include_edges ? "included" : "excluded") in graph construction"
end

"""
    get_ontology_maximum_depth_limit()::Int

Get the maximum depth to traverse in the ontology hierarchy.
"""
function get_ontology_maximum_depth_limit()::Int
    max_depth = @load_framework_preference("ontology_maximum_depth", 5)
    max_depth isa Integer ||
        throw(ArgumentError("ontology_maximum_depth must be an integer"))
    max_depth_val = Int(max_depth)
    max_depth_val > 0 || throw(ArgumentError("ontology_maximum_depth must be positive"))
    return max_depth_val
end

"""
    set_ontology_maximum_depth_limit!(max_depth::Integer)

Set the maximum depth for ontology hierarchy traversal.

# Arguments
- `max_depth::Integer`: Maximum depth, must be positive
"""
function set_ontology_maximum_depth_limit!(max_depth::Integer)
    max_depth > 0 || throw(ArgumentError("Ontology maximum depth must be positive"))
    max_depth <= 20 ||
        throw(ArgumentError("Ontology maximum depth seems unreasonably large"))
    set_framework_preference!("ontology_maximum_depth", Int(max_depth))
    @info "Ontology maximum depth set to $(Int(max_depth))"
end

"""
    get_string_database_confidence_threshold()::Float64

Get the confidence threshold for STRING database interactions.
"""
function get_string_database_confidence_threshold()::Float64
    threshold = @load_framework_preference("string_database_confidence_threshold", 0.4)
    threshold isa Real ||
        throw(ArgumentError("string_database_confidence_threshold must be a number"))
    threshold_val = Float64(threshold)
    (0.0 <= threshold_val <= 1.0) ||
        throw(ArgumentError("string_database_confidence_threshold must be between 0 and 1"))
    return threshold_val
end

"""
    set_string_database_confidence_threshold!(threshold::Real)

Set the confidence threshold for STRING database protein interactions.

# Arguments
- `threshold::Real`: Confidence threshold (0.0 to 1.0), typically 0.4 to 0.9
"""
function set_string_database_confidence_threshold!(threshold::Real)
    (0.0 <= threshold <= 1.0) ||
        throw(ArgumentError("STRING database confidence threshold must be between 0 and 1"))
    set_framework_preference!("string_database_confidence_threshold", Float64(threshold))
    @info "STRING database confidence threshold set to $(Float64(threshold))"
end

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

"""
    get_all_framework_preferences()::Dict{String,Any}

Get all current framework preference values for debugging and configuration export.
"""
function get_all_framework_preferences()::Dict{String, Any}
    preferences = Dict{String, Any}()

    # Repository configuration
    preferences["repository_cache_directory"] = get_repository_cache_directory_path()
    preferences["repository_memory_limit_gb"] = get_repository_memory_limit_gigabytes()
    preferences["cache_eviction_threshold"] = get_cache_eviction_threshold_ratio()

    # Caching behavior
    preferences["cache_compression_enabled"] = get_cache_compression_enabled_flag()
    preferences["cache_integrity_checking"] = get_cache_integrity_checking_enabled_flag()

    # Data source caching
    merge!(preferences, get_data_source_caching_configuration())

    # Graph construction
    preferences["gene_correlation_threshold"] = get_gene_correlation_threshold_value()
    preferences["maximum_edges_per_gene_node"] = get_maximum_edges_per_gene_node_count()
    preferences["include_ontology_hierarchy_edges"] =
        get_include_ontology_hierarchy_edges_flag()
    preferences["ontology_maximum_depth"] = get_ontology_maximum_depth_limit()
    preferences["string_database_confidence_threshold"] =
        get_string_database_confidence_threshold()

    return preferences
end

"""
    reset_framework_preferences_to_defaults!()

Reset all framework preferences to their default values.

⚠️  Warning: This will delete all current preference settings.
"""
function reset_framework_preferences_to_defaults!()
    @warn "Resetting all framework preferences to defaults. This cannot be undone."

    # Get all preference keys (this is a simplified version - in practice you'd track all keys)
    preference_keys = [
        "repository_cache_directory",
        "repository_memory_limit_gb",
        "cache_eviction_threshold",
        "cache_compression_enabled",
        "cache_integrity_checking",
        "enable_reference_data_caching",
        "enable_ontology_data_caching",
        "enable_graph_construction_caching",
        "enable_synthetic_data_caching",
        "gene_correlation_threshold",
        "maximum_edges_per_gene_node",
        "include_ontology_hierarchy_edges",
        "ontology_maximum_depth",
        "string_database_confidence_threshold",
    ]

    delete_framework_preferences!(preference_keys...)
    initialize_framework_preferences!()

    @info "All framework preferences reset to defaults"
end

"""
    configure_framework_for_low_memory!(memory_limit_gb::Real=2.0)

Configure framework for low-memory environments with aggressive caching and limits.

# Arguments
- `memory_limit_gb::Real`: Memory limit in GB (default: 2.0)
"""
function configure_framework_for_low_memory!(memory_limit_gb::Real = 2.0)
    set_repository_memory_limit_gigabytes!(memory_limit_gb)
    set_cache_eviction_threshold_ratio!(0.6)  # More aggressive eviction
    set_cache_compression_enabled_flag!(true)
    set_maximum_edges_per_gene_node_count!(10)  # Smaller graphs

    @info "Framework configured for low-memory environment ($(memory_limit_gb) GB limit)"
end

"""
    configure_framework_for_high_performance!(memory_limit_gb::Real=32.0)

Configure framework for high-performance environments with generous memory limits.

# Arguments
- `memory_limit_gb::Real`: Memory limit in GB (default: 32.0)
"""
function configure_framework_for_high_performance!(memory_limit_gb::Real = 32.0)
    set_repository_memory_limit_gigabytes!(memory_limit_gb)
    set_cache_eviction_threshold_ratio!(0.9)  # Less aggressive eviction
    set_cache_compression_enabled_flag!(false)  # Faster access over storage efficiency
    set_maximum_edges_per_gene_node_count!(25)  # Larger, more detailed graphs

    @info "Framework configured for high-performance environment ($(memory_limit_gb) GB limit)"
end
