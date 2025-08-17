"""
Hashing utilities for repository system.

Provides consistent hash generation for cache keys based on input parameters,
data dependencies, and configuration state. Uses SHA256 for cryptographic
strength and collision resistance.
"""

using SHA
using Serialization

"""
    generate_cache_key(parameters::Dict{String,Any})::String

Generate a consistent cache key from input parameters.

# Arguments
- `parameters::Dict{String,Any}`: Parameters that affect the cached result

# Returns
- `String`: Hexadecimal SHA256 hash of the parameters

# Example
```julia
params = Dict("correlation_threshold" => 0.3, "max_edges" => 15)
key = generate_cache_key(params)
# Returns: "a1b2c3d4e5f6..."
```
"""
function generate_cache_key(parameters::Dict{String, Any})::String
    # Convert all values to strings for consistent sorting
    string_params = Dict{String, String}()
    for (k, v) in parameters
        string_params[k] = string(v)
    end

    # Sort parameters for consistent hashing regardless of insertion order
    sorted_params = sort(collect(string_params))

    # Serialize parameters to bytes
    io = IOBuffer()
    serialize(io, sorted_params)
    param_bytes = take!(io)

    # Generate SHA256 hash
    hash_bytes = sha256(param_bytes)
    return bytes2hex(hash_bytes)
end

"""
    generate_cache_key(prefix::String, parameters::Dict{String,Any})::String

Generate a cache key with a human-readable prefix.

# Arguments
- `prefix::String`: Human-readable prefix for the cache key
- `parameters::Dict{String,Any}`: Parameters that affect the cached result

# Returns
- `String`: Cache key in format "prefix/hash"

# Example
```julia
params = Dict("threshold" => 0.3)
key = generate_cache_key("gene_correlation", params)
# Returns: "gene_correlation/a1b2c3d4e5f6..."
```
"""
function generate_cache_key(prefix::String, parameters::Dict{String, Any})::String
    hash_part = generate_cache_key(parameters)
    return "$prefix/$hash_part"
end

"""
    generate_cache_key_with_dependencies(parameters::Dict{String,Any}, dependencies::Vector{String})::String

Generate a cache key that includes data dependencies for invalidation.

# Arguments
- `parameters::Dict{String,Any}`: Parameters that affect the cached result
- `dependencies::Vector{String}`: List of data sources this result depends on

# Returns
- `String`: SHA256 hash of parameters and dependency checksums

# Example
```julia
params = Dict("threshold" => 0.3)
deps = ["reference_data/GSE22886", "ontology/immune_cells"]
key = generate_cache_key_with_dependencies(params, deps)
```
"""
function generate_cache_key_with_dependencies(
    parameters::Dict{String, Any},
    dependencies::Vector{String},
)::String
    # Combine parameters with sorted dependencies
    combined_data = Dict{String, Any}(
        "parameters" => parameters,
        "dependencies" => sort(dependencies),
        "timestamp" => time(),  # Include timestamp for freshness
    )

    return generate_cache_key(combined_data)
end

"""
    generate_file_checksum(file_path::String)::String

Generate SHA256 checksum of a file for integrity verification.

# Arguments
- `file_path::String`: Path to the file

# Returns
- `String`: Hexadecimal SHA256 checksum of the file contents

# Throws
- `SystemError`: If file cannot be read
"""
function generate_file_checksum(file_path::String)::String
    isfile(file_path) || throw(SystemError("File not found: $file_path"))

    return open(file_path, "r") do file
        return bytes2hex(sha256(read(file)))
    end
end

"""
    generate_data_checksum(data::Any)::String

Generate SHA256 checksum of arbitrary data for cache validation.

# Arguments
- `data::Any`: Data object to checksum

# Returns
- `String`: Hexadecimal SHA256 checksum of the serialized data

# Example
```julia
data = DataFrame(gene=["A", "B"], expression=[1.0, 2.0])
checksum = generate_data_checksum(data)
```
"""
function generate_data_checksum(data::Any)::String
    io = IOBuffer()
    serialize(io, data)
    data_bytes = take!(io)
    hash_bytes = sha256(data_bytes)
    return bytes2hex(hash_bytes)
end

"""
    validate_cache_key_format(key::String)::Bool

Validate that a cache key has the expected format.

# Arguments
- `key::String`: Cache key to validate

# Returns
- `Bool`: true if key format is valid

# Valid formats:
- "hexadecimal_hash" (64 characters)
- "prefix/hexadecimal_hash"
"""
function validate_cache_key_format(key::String)::Bool
    # Check for prefix/hash format
    if occursin("/", key)
        parts = split(key, "/")
        if length(parts) != 2
            return false
        end
        prefix, hash_part = parts

        # Prefix should be non-empty and contain only letters, numbers, underscore
        if isempty(prefix) || !all(c -> isletter(c) || isdigit(c) || c == '_', prefix)
            return false
        end

        # Hash part should be 64 hex characters
        return length(hash_part) == 64 && all(c -> isdigit(c) || c in 'a':'f', hash_part)
    else
        # Direct hash format - should be 64 hex characters
        return length(key) == 64 && all(c -> isdigit(c) || c in 'a':'f', key)
    end
end

"""
    extract_prefix_from_cache_key(key::String)::Union{String,Nothing}

Extract the prefix from a cache key if it has one.

# Arguments
- `key::String`: Cache key to extract prefix from

# Returns
- `Union{String,Nothing}`: Prefix if present, nothing if key has no prefix

# Example
```julia
extract_prefix_from_cache_key("gene_correlation/abc123...") # Returns "gene_correlation"
extract_prefix_from_cache_key("abc123...") # Returns nothing
```
"""
function extract_prefix_from_cache_key(key::String)::Union{String, Nothing}
    if occursin("/", key)
        return split(key, "/")[1]
    else
        return nothing
    end
end

"""
    generate_configuration_hash()::String

Generate a hash of the current framework configuration that affects caching.

This hash is used to invalidate caches when configuration changes that
would affect the results.

# Returns
- `String`: SHA256 hash of relevant configuration parameters
"""
function generate_configuration_hash()::String
    # Get configuration parameters that affect cached results
    config_params = Dict(
        "gene_correlation_threshold" => get_gene_correlation_threshold_value(),
        "maximum_edges_per_gene_node" => get_maximum_edges_per_gene_node_count(),
        "include_ontology_hierarchy_edges" =>
            get_include_ontology_hierarchy_edges_flag(),
        "ontology_maximum_depth" => get_ontology_maximum_depth_limit(),
        "string_database_confidence_threshold" =>
            get_string_database_confidence_threshold(),
        "cache_compression_enabled" => get_cache_compression_enabled_flag(),
    )

    return generate_cache_key(config_params)
end

"""
    generate_versioned_cache_key(base_key::String, version::String="1.0")::String

Generate a cache key that includes version information for compatibility.

# Arguments
- `base_key::String`: Base cache key
- `version::String`: Version identifier (default: "1.0")

# Returns
- `String`: Versioned cache key

# Example
```julia
key = generate_versioned_cache_key("gene_correlation/abc123", "1.1")
# Returns: "1.1/gene_correlation/abc123"
```
"""
function generate_versioned_cache_key(base_key::String, version::String = "1.0")::String
    return "$version/$base_key"
end

"""
    batch_generate_cache_keys(parameter_sets::Vector{Dict{String,Any}}, prefix::String="")::Vector{String}

Generate cache keys for multiple parameter sets efficiently.

# Arguments
- `parameter_sets::Vector{Dict{String,Any}}`: Multiple parameter dictionaries
- `prefix::String`: Optional prefix for all keys

# Returns
- `Vector{String}`: Cache keys for each parameter set

# Example
```julia
param_sets = [
    Dict("threshold" => 0.3, "max_edges" => 15),
    Dict("threshold" => 0.4, "max_edges" => 20)
]
keys = batch_generate_cache_keys(param_sets, "gene_correlation")
```
"""
function batch_generate_cache_keys(
    parameter_sets::Vector{Dict{String, Any}},
    prefix::String = "",
)::Vector{String}
    keys = Vector{String}(undef, length(parameter_sets))

    for (i, params) in enumerate(parameter_sets)
        if isempty(prefix)
            keys[i] = generate_cache_key(params)
        else
            keys[i] = generate_cache_key(prefix, params)
        end
    end

    return keys
end

"""
    cache_key_statistics(keys::Vector{String})::Dict{String,Any}

Analyze a collection of cache keys for statistics and patterns.

# Arguments
- `keys::Vector{String}`: Collection of cache keys

# Returns
- `Dict{String,Any}`: Statistics about the cache keys

# Example
```julia
keys = ["gene/abc123", "ontology/def456", "gene/ghi789"]
stats = cache_key_statistics(keys)
# Returns: Dict with prefix counts, total keys, etc.
```
"""
function cache_key_statistics(keys::Vector{String})::Dict{String, Any}
    prefixes = [extract_prefix_from_cache_key(key) for key in keys]
    prefix_counts = Dict{String, Int}()

    for prefix in prefixes
        if prefix !== nothing
            prefix_counts[prefix] = get(prefix_counts, prefix, 0) + 1
        else
            prefix_counts["no_prefix"] = get(prefix_counts, "no_prefix", 0) + 1
        end
    end

    return Dict{String, Any}(
        "total_keys" => length(keys),
        "prefix_counts" => prefix_counts,
        "unique_prefixes" => length(filter(p -> p !== nothing, unique(prefixes))),
        "keys_without_prefix" => count(p -> p === nothing, prefixes),
    )
end
