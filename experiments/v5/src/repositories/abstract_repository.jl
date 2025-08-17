"""
Abstract repository interface for caching system.

Defines the contract that all repository implementations must follow,
providing a dictionary-like API for data access with automatic caching,
loading, and memory management.
"""

"""
    AbstractRepository

Base type for all repository implementations in the framework.

All repositories provide a dictionary-like interface for data access:
- `repo[key]` - Get data, loading and caching as needed
- `haskey(repo, key)` - Check if data exists or can be loaded
- `delete!(repo, key)` - Remove data from cache
- `keys(repo)` - Iterate over available keys

Implementations must handle:
- Automatic data loading from sources
- Intelligent caching with memory management
- Cache invalidation based on dependencies
- Error handling with descriptive exceptions
"""
abstract type AbstractRepository end

# =============================================================================
# REQUIRED INTERFACE METHODS
# =============================================================================

"""
    Base.getindex(repo::AbstractRepository, key::String)

Get data from the repository by key, loading and caching as needed.

# Arguments
- `repo::AbstractRepository`: Repository instance
- `key::String`: Cache key identifying the data

# Returns
- `Any`: The requested data object

# Throws
- `CacheKeyNotFoundError`: If key is invalid or data cannot be loaded
- `RepositoryAccessError`: If data loading fails
- `MemoryLimitExceededError`: If loading would exceed memory limits
"""
function Base.getindex(repo::AbstractRepository, key::String)
    throw(
        ErrorException("getindex method must be implemented by concrete repository types"),
    )
end

"""
    Base.getindex(repo::AbstractRepository, key::String, ::Type{T}) where T

Get data from the repository with type assertion.

# Arguments
- `repo::AbstractRepository`: Repository instance  
- `key::String`: Cache key identifying the data
- `::Type{T}`: Expected type of the data

# Returns
- `T`: The requested data object, guaranteed to be of type T

# Throws
- `CacheKeyNotFoundError`: If key is invalid or data cannot be loaded
- `RepositoryAccessError`: If data loading fails
- `DataValidationError`: If data is not of expected type
"""
function Base.getindex(repo::AbstractRepository, key::String, ::Type{T}) where {T}
    data = repo[key]
    if !isa(data, T)
        throw(
            DataValidationError(
                "Data type mismatch for key '$key'",
                "data_type",
                string(T),
                string(typeof(data)),
            ),
        )
    end
    return data
end

"""
    Base.haskey(repo::AbstractRepository, key::String)::Bool

Check if a key exists in the repository or can be loaded.

# Arguments
- `repo::AbstractRepository`: Repository instance
- `key::String`: Cache key to check

# Returns
- `Bool`: true if key exists or can be loaded, false otherwise
"""
function Base.haskey(repo::AbstractRepository, key::String)::Bool
    throw(ErrorException("haskey method must be implemented by concrete repository types"))
end

"""
    Base.delete!(repo::AbstractRepository, key::String)

Remove data from the repository cache.

# Arguments
- `repo::AbstractRepository`: Repository instance
- `key::String`: Cache key to remove

# Returns
- `AbstractRepository`: The repository instance (for chaining)

# Note
This removes data from cache but does not affect the original data source.
The data can be reloaded on next access.
"""
function Base.delete!(repo::AbstractRepository, key::String)
    throw(ErrorException("delete! method must be implemented by concrete repository types"))
end

"""
    Base.keys(repo::AbstractRepository)

Get an iterator over all available keys in the repository.

# Arguments
- `repo::AbstractRepository`: Repository instance

# Returns
- `AbstractVector{String}`: Collection of available cache keys

# Note
This may include both cached keys and keys that can be generated on demand.
"""
function Base.keys(repo::AbstractRepository)
    throw(ErrorException("keys method must be implemented by concrete repository types"))
end

# =============================================================================
# OPTIONAL INTERFACE METHODS (WITH DEFAULT IMPLEMENTATIONS)
# =============================================================================

"""
    cache_size(repo::AbstractRepository)::Int

Get the number of items currently cached in the repository.

# Arguments
- `repo::AbstractRepository`: Repository instance

# Returns
- `Int`: Number of cached items
"""
function cache_size(repo::AbstractRepository)::Int
    return length(keys(repo))
end

"""
    memory_usage(repo::AbstractRepository)::Float64

Get the estimated memory usage of the repository in GB.

# Arguments
- `repo::AbstractRepository`: Repository instance

# Returns
- `Float64`: Estimated memory usage in gigabytes

# Note
Default implementation returns 0.0. Concrete implementations should override
this method to provide accurate memory usage tracking.
"""
function memory_usage(repo::AbstractRepository)::Float64
    return 0.0
end

"""
    clear_cache!(repo::AbstractRepository)

Remove all cached data from the repository.

# Arguments
- `repo::AbstractRepository`: Repository instance

# Returns
- `AbstractRepository`: The repository instance (for chaining)

# Note
This removes all cached data but does not affect original data sources.
Data can be reloaded on next access.
"""
function clear_cache!(repo::AbstractRepository)
    for key in collect(keys(repo))
        delete!(repo, key)
    end
    return repo
end

"""
    preload!(repo::AbstractRepository, keys::Vector{String})

Preload data for multiple keys to warm the cache.

# Arguments
- `repo::AbstractRepository`: Repository instance
- `keys::Vector{String}`: Cache keys to preload

# Returns
- `Dict{String,Bool}`: Dictionary mapping keys to success status

# Example
```julia
keys_to_preload = ["reference/GSE22886", "ontology/immune_cells"]
results = preload!(repo, keys_to_preload)
```
"""
function preload!(repo::AbstractRepository, keys::Vector{String})::Dict{String, Bool}
    results = Dict{String, Bool}()

    for key in keys
        try
            repo[key]  # Access to trigger loading
            results[key] = true
        catch e
            @warn "Failed to preload key: $key" error = e
            results[key] = false
        end
    end

    return results
end

"""
    refresh!(repo::AbstractRepository, key::String)

Force refresh of cached data by removing and reloading.

# Arguments
- `repo::AbstractRepository`: Repository instance
- `key::String`: Cache key to refresh

# Returns
- `Any`: The refreshed data object

# Throws
- `CacheKeyNotFoundError`: If key cannot be reloaded
"""
function refresh!(repo::AbstractRepository, key::String)
    delete!(repo, key)
    return repo[key]
end

"""
    get_cache_statistics(repo::AbstractRepository)::Dict{String,Any}

Get comprehensive statistics about the repository cache.

# Arguments
- `repo::AbstractRepository`: Repository instance

# Returns
- `Dict{String,Any}`: Statistics dictionary with cache metrics

# Default implementation provides basic statistics. Concrete implementations
# should override to provide more detailed metrics.
"""
function get_cache_statistics(repo::AbstractRepository)::Dict{String, Any}
    return Dict{String, Any}(
        "cached_items" => cache_size(repo),
        "memory_usage_gb" => memory_usage(repo),
        "available_keys" => length(keys(repo)),
    )
end

# =============================================================================
# VALIDATION AND UTILITY METHODS
# =============================================================================

"""
    validate_repository_key(key::String)::Bool

Validate that a repository key has the correct format.

# Arguments
- `key::String`: Cache key to validate

# Returns
- `Bool`: true if key format is valid

# Valid key formats:
- "source_type/identifier" (e.g., "reference/GSE22886")
- "prefix/hash" (e.g., "gene_correlation/abc123...")
- "operation/parameters/hash" (e.g., "preprocessing/log2_norm/def456...")
"""
function validate_repository_key(key::String)::Bool
    # Key must be non-empty
    if isempty(key)
        return false
    end

    # Key should contain only letters, numbers, underscore, hyphen, slash
    valid_chars = Set(vcat('a':'z', 'A':'Z', '0':'9', ['_', '-', '/']))
    if !all(c -> c in valid_chars, key)
        return false
    end

    # Key should not start or end with slash
    if startswith(key, "/") || endswith(key, "/")
        return false
    end

    # Key should not contain consecutive slashes
    if occursin("//", key)
        return false
    end

    return true
end

"""
    normalize_repository_key(key::String)::String

Normalize a repository key to standard format.

# Arguments
- `key::String`: Raw cache key

# Returns
- `String`: Normalized cache key

# Normalization rules:
- Convert to lowercase
- Replace spaces with underscores
- Remove invalid characters
- Ensure valid format
"""
function normalize_repository_key(key::String)::String
    # Convert to lowercase and replace spaces
    normalized = lowercase(replace(key, " " => "_"))

    # Remove invalid characters
    valid_chars = Set(vcat('a':'z', '0':'9', ['_', '-', '/']))
    normalized = String([c for c in normalized if c in valid_chars])

    # Remove leading/trailing slashes
    normalized = strip(normalized, '/')

    # Replace consecutive slashes
    while occursin("//", normalized)
        normalized = replace(normalized, "//" => "/")
    end

    return normalized
end

"""
    suggest_similar_keys(repo::AbstractRepository, target_key::String, max_suggestions::Int=5)::Vector{String}

Suggest similar keys when a requested key is not found.

# Arguments
- `repo::AbstractRepository`: Repository instance
- `target_key::String`: The requested key that was not found
- `max_suggestions::Int`: Maximum number of suggestions to return

# Returns
- `Vector{String}`: List of similar available keys

# Uses simple string distance to find similar keys for user assistance.
"""
function suggest_similar_keys(
    repo::AbstractRepository,
    target_key::String,
    max_suggestions::Int = 5,
)::Vector{String}
    available_keys = keys(repo)

    if isempty(available_keys)
        return String[]
    end

    # Calculate simple edit distance for suggestions
    distances = [(key, edit_distance(target_key, key)) for key in available_keys]

    # Sort by distance and take top suggestions
    sort!(distances, by = x -> x[2])
    suggestions = [pair[1] for pair in distances[1:min(max_suggestions, length(distances))]]

    return suggestions
end

"""
    edit_distance(s1::String, s2::String)::Int

Calculate edit distance between two strings for key suggestions.
Simple implementation for finding similar cache keys.
"""
function edit_distance(s1::String, s2::String)::Int
    m, n = length(s1), length(s2)
    dp = zeros(Int, m + 1, n + 1)

    for i in 1:(m + 1)
        dp[i, 1] = i - 1
    end

    for j in 1:(n + 1)
        dp[1, j] = j - 1
    end

    for i in 2:(m + 1)
        for j in 2:(n + 1)
            if s1[i - 1] == s2[j - 1]
                dp[i, j] = dp[i - 1, j - 1]
            else
                dp[i, j] = 1 + min(dp[i - 1, j], dp[i, j - 1], dp[i - 1, j - 1])
            end
        end
    end

    return dp[m + 1, n + 1]
end

# =============================================================================
# REPOSITORY TYPE CHECKING
# =============================================================================

"""
    is_memory_repository(repo::AbstractRepository)::Bool

Check if repository is a memory-only repository.
"""
function is_memory_repository(repo::AbstractRepository)::Bool
    return false  # Default implementation - override in concrete types
end

"""
    is_file_repository(repo::AbstractRepository)::Bool

Check if repository is a file-based repository.
"""
function is_file_repository(repo::AbstractRepository)::Bool
    return false  # Default implementation - override in concrete types
end

"""
    is_composite_repository(repo::AbstractRepository)::Bool

Check if repository is a composite repository combining multiple backends.
"""
function is_composite_repository(repo::AbstractRepository)::Bool
    return false  # Default implementation - override in concrete types
end
