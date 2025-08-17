"""
In-memory repository implementation for caching system.

Provides fast data access with automatic memory management and LRU eviction.
Suitable for temporary data and small to medium-sized datasets that fit in memory.
"""

using LRUCache

"""
    MemoryRepository <: AbstractRepository

In-memory repository with LRU eviction and memory monitoring.

Stores data directly in memory for fast access. Automatically evicts
least recently used items when memory limits are approached.

# Features
- O(1) access time for cached data
- LRU eviction policy
- Memory usage monitoring
- Access time tracking
- Thread-safe operations (future enhancement)

# Example
```julia
repo = MemoryRepository(memory_limit_gb=2.0)
repo["key1"] = data1
data = repo["key1"]  # Fast memory access
```
"""
mutable struct MemoryRepository <: AbstractRepository
    # Core data storage
    data_cache::Dict{String, Any}

    # LRU tracking
    access_order::LRU{String, Nothing}

    # Memory management
    memory_limit_bytes::Int64
    current_memory_bytes::Int64
    memory_estimates::Dict{String, Int64}

    # Statistics
    hit_count::Int64
    miss_count::Int64
    eviction_count::Int64

    # Configuration
    enable_memory_monitoring::Bool
    eviction_threshold_ratio::Float64

    function MemoryRepository(;
        memory_limit_gb::Float64 = 2.0,
        max_items::Int = 10000,
        eviction_threshold::Float64 = 0.8,
        enable_monitoring::Bool = true,
    )
        memory_limit_gb > 0 || throw(ArgumentError("Memory limit must be positive"))
        max_items > 0 || throw(ArgumentError("Max items must be positive"))
        (0.0 < eviction_threshold < 1.0) ||
            throw(ArgumentError("Eviction threshold must be between 0 and 1"))

        memory_limit_bytes = Int64(memory_limit_gb * 1024 * 1024 * 1024)

        return new(
            Dict{String, Any}(),                    # data_cache
            LRU{String, Nothing}(maxsize = max_items), # access_order
            memory_limit_bytes,                    # memory_limit_bytes
            0,                                     # current_memory_bytes
            Dict{String, Int64}(),                  # memory_estimates
            0,                                     # hit_count
            0,                                     # miss_count
            0,                                     # eviction_count
            enable_monitoring,                     # enable_memory_monitoring
            eviction_threshold,                     # eviction_threshold_ratio
        )
    end
end

# =============================================================================
# CORE REPOSITORY INTERFACE IMPLEMENTATION
# =============================================================================

function Base.getindex(repo::MemoryRepository, key::String)
    validate_repository_key(key) || throw(
        CacheKeyNotFoundError(
            "Invalid repository key format",
            key,
            String[],
            "Keys must contain only letters, numbers, underscore, hyphen, and slash",
        ),
    )

    # Check if data is already cached
    if haskey(repo.data_cache, key)
        # Update access order (LRU)
        repo.access_order[key] = nothing
        repo.hit_count += 1

        @debug "Memory cache hit" key = key
        return repo.data_cache[key]
    end

    # Data not in cache - this is a miss for memory repository
    repo.miss_count += 1

    # Memory repository cannot load data from external sources
    # It only stores what has been explicitly put into it
    available_keys = collect(keys(repo.data_cache))
    suggestions = suggest_similar_keys_simple(key, available_keys)

    throw(
        CacheKeyNotFoundError(
            "Key not found in memory repository",
            key,
            suggestions,
            "Memory repositories only contain explicitly stored data",
        ),
    )
end

function Base.haskey(repo::MemoryRepository, key::String)::Bool
    return haskey(repo.data_cache, key)
end

function Base.delete!(repo::MemoryRepository, key::String)
    if haskey(repo.data_cache, key)
        # Remove from data cache
        delete!(repo.data_cache, key)

        # Remove from LRU tracking
        delete!(repo.access_order, key)

        # Update memory tracking
        if haskey(repo.memory_estimates, key)
            repo.current_memory_bytes -= repo.memory_estimates[key]
            delete!(repo.memory_estimates, key)
        end

        @debug "Removed item from memory cache" key = key
    end

    return repo
end

function Base.keys(repo::MemoryRepository)
    return collect(keys(repo.data_cache))
end

# =============================================================================
# MEMORY REPOSITORY SPECIFIC METHODS
# =============================================================================

"""
    Base.setindex!(repo::MemoryRepository, data::Any, key::String)

Store data in the memory repository.

# Arguments
- `repo::MemoryRepository`: Repository instance
- `data::Any`: Data to store
- `key::String`: Cache key for the data

# Throws
- `MemoryLimitExceededError`: If storing data would exceed memory limits
"""
function Base.setindex!(repo::MemoryRepository, data::Any, key::String)
    validate_repository_key(key) ||
        throw(ArgumentError("Invalid repository key format: $key"))

    # Estimate memory usage of new data
    data_size = estimate_memory_usage(data)

    # Check if we need to evict items before adding new data
    if should_evict_before_adding(repo, data_size)
        evict_lru_items!(repo, data_size)
    end

    # Validate that we can still fit the data after eviction
    available_memory = repo.memory_limit_bytes - repo.current_memory_bytes
    if data_size > available_memory
        throw(
            MemoryLimitExceededError(
                "Cannot store data: would exceed memory limit even after eviction",
                repo.current_memory_bytes / (1024^3),
                repo.memory_limit_bytes / (1024^3),
                "store data for key '$key'",
                data_size / (1024^3),
                [
                    "Increase memory limit with memory_limit_gb parameter",
                    "Store smaller data objects",
                    "Use file-based repository for large data",
                ],
            ),
        )
    end

    # Store the data
    repo.data_cache[key] = data
    repo.access_order[key] = nothing  # Mark as most recently used
    repo.memory_estimates[key] = data_size
    repo.current_memory_bytes += data_size

    @debug "Stored data in memory cache" key = key size_mb = (data_size / 1024 / 1024)

    return data
end

"""
    evict_lru_items!(repo::MemoryRepository, bytes_needed::Int64)

Evict least recently used items to free up memory.

# Arguments
- `repo::MemoryRepository`: Repository instance
- `bytes_needed::Int64`: Minimum bytes to free up
"""
function evict_lru_items!(repo::MemoryRepository, bytes_needed::Int64)
    bytes_freed = 0
    evicted_keys = String[]

    # Evict items until we have enough space
    while bytes_freed < bytes_needed && !isempty(repo.access_order)
        # Get least recently used key
        lru_key = first(repo.access_order).first

        # Remove from all tracking structures
        delete!(repo.data_cache, lru_key)
        delete!(repo.access_order, lru_key)

        # Update memory tracking
        if haskey(repo.memory_estimates, lru_key)
            freed_bytes = repo.memory_estimates[lru_key]
            bytes_freed += freed_bytes
            repo.current_memory_bytes -= freed_bytes
            delete!(repo.memory_estimates, lru_key)
        end

        push!(evicted_keys, lru_key)
        repo.eviction_count += 1
    end

    if !isempty(evicted_keys)
        @debug "Evicted LRU items from memory cache" evicted_keys = evicted_keys bytes_freed =
            bytes_freed
    end
end

"""
    should_evict_before_adding(repo::MemoryRepository, data_size::Int64)::Bool

Determine if eviction is needed before adding new data.

# Arguments
- `repo::MemoryRepository`: Repository instance
- `data_size::Int64`: Size of data to be added

# Returns
- `Bool`: true if eviction is needed
"""
function should_evict_before_adding(repo::MemoryRepository, data_size::Int64)::Bool
    # Calculate memory usage after adding new data
    projected_memory = repo.current_memory_bytes + data_size
    threshold_memory = repo.memory_limit_bytes * repo.eviction_threshold_ratio

    return projected_memory > threshold_memory
end

"""
    estimate_memory_usage(data::Any)::Int64

Estimate memory usage of data object in bytes.

# Arguments
- `data::Any`: Data object to estimate

# Returns
- `Int64`: Estimated memory usage in bytes
"""
function estimate_memory_usage(data::Any)::Int64
    try
        # Try to get accurate size for common types
        if isa(data, AbstractArray)
            return sizeof(data)
        elseif isa(data, AbstractString)
            return sizeof(data)
        elseif isa(data, Dict)
            # Rough estimate for dictionaries
            return sum(sizeof(k) + estimate_memory_usage(v) for (k, v) in data)
        else
            # Fallback: use serialization size as approximation
            return estimate_serialized_size(data)
        end
    catch e
        # Conservative fallback estimate
        @debug "Could not estimate memory usage, using default" error = e
        return 1024  # 1KB default
    end
end

# =============================================================================
# MEMORY REPOSITORY STATISTICS AND MONITORING
# =============================================================================

function memory_usage(repo::MemoryRepository)::Float64
    return repo.current_memory_bytes / (1024^3)  # Convert to GB
end

function cache_size(repo::MemoryRepository)::Int
    return length(repo.data_cache)
end

function get_cache_statistics(repo::MemoryRepository)::Dict{String, Any}
    total_accesses = repo.hit_count + repo.miss_count
    hit_rate = total_accesses > 0 ? repo.hit_count / total_accesses : 0.0

    return Dict{String, Any}(
        "cached_items" => cache_size(repo),
        "memory_usage_gb" => memory_usage(repo),
        "memory_limit_gb" => repo.memory_limit_bytes / (1024^3),
        "memory_usage_ratio" => repo.current_memory_bytes / repo.memory_limit_bytes,
        "hit_count" => repo.hit_count,
        "miss_count" => repo.miss_count,
        "hit_rate" => hit_rate,
        "eviction_count" => repo.eviction_count,
        "max_capacity" => repo.access_order.maxsize,
        "eviction_threshold" => repo.eviction_threshold_ratio,
    )
end

"""
    resize_memory_limit!(repo::MemoryRepository, new_limit_gb::Float64)

Change the memory limit of the repository, evicting items if necessary.

# Arguments
- `repo::MemoryRepository`: Repository instance
- `new_limit_gb::Float64`: New memory limit in GB
"""
function resize_memory_limit!(repo::MemoryRepository, new_limit_gb::Float64)
    new_limit_gb > 0 || throw(ArgumentError("Memory limit must be positive"))

    new_limit_bytes = Int64(new_limit_gb * 1024 * 1024 * 1024)
    old_limit_gb = repo.memory_limit_bytes / (1024^3)

    repo.memory_limit_bytes = new_limit_bytes

    # If new limit is smaller, evict items if necessary
    if repo.current_memory_bytes > new_limit_bytes
        excess_bytes = repo.current_memory_bytes - new_limit_bytes
        evict_lru_items!(repo, excess_bytes)
    end

    # @log_info :configuration "Memory limit changed" old_limit_gb = old_limit_gb new_limit_gb =
    #     new_limit_gb
    @info "Memory limit changed" old_limit_gb = old_limit_gb new_limit_gb = new_limit_gb
end

"""
    force_compact!(repo::MemoryRepository)

Force garbage collection and memory compaction.

# Arguments
- `repo::MemoryRepository`: Repository instance
"""
function force_compact!(repo::MemoryRepository)
    # Force Julia garbage collection
    GC.gc()

    # Recalculate memory estimates for existing data
    total_estimated = 0
    for (key, data) in repo.data_cache
        size_estimate = estimate_memory_usage(data)
        repo.memory_estimates[key] = size_estimate
        total_estimated += size_estimate
    end

    repo.current_memory_bytes = total_estimated

    @debug "Memory repository compacted" estimated_memory_gb = (total_estimated / 1024^3)
end

# =============================================================================
# TYPE IDENTIFICATION
# =============================================================================

function is_memory_repository(repo::MemoryRepository)::Bool
    return true
end

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

"""
    suggest_similar_keys_simple(target::String, available::Vector{String})::Vector{String}

Simple key suggestion for memory repository (internal use).
"""
function suggest_similar_keys_simple(
    target::String,
    available::Vector{String},
)::Vector{String}
    if isempty(available)
        return String[]
    end

    # Simple substring matching
    matches = filter(
        k ->
            occursin(lowercase(target), lowercase(k)) ||
                occursin(lowercase(k), lowercase(target)),
        available,
    )

    return matches[1:min(5, length(matches))]
end
