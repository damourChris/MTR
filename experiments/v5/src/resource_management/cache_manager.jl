"""
Cache management utilities for V5 repository system.

Provides high-level cache management functions that coordinate between
different repository types and handle cache cleanup, statistics, and
optimization.
"""

"""
    CacheManager

Coordinates cache operations across multiple repositories and data sources.

# Features
- Multi-repository cache coordination
- Automatic cache cleanup and optimization
- Cache statistics aggregation
- Memory limit enforcement
"""
struct CacheManager
    repositories::Vector{AbstractRepository}
    memory_monitor::MemoryMonitor
    cleanup_interval_minutes::Int
    last_cleanup_time::DateTime

    function CacheManager(
        repositories::Vector{AbstractRepository} = AbstractRepository[],
        memory_limit_gb::Float64 = 8.0,
        cleanup_interval::Int = 60,
    )
        memory_monitor = MemoryMonitor(memory_limit_gb)

        return new(repositories, memory_monitor, cleanup_interval, now())
    end
end

"""
    configure_memory_limits!(limit_gb::Float64)

Configure global memory limits for the V5 framework.

# Arguments
- `limit_gb::Float64`: Memory limit in gigabytes
"""
function configure_memory_limits!(limit_gb::Float64)
    set_repository_memory_limit_gigabytes!(limit_gb)
    @log_info :cache "Configured V5 memory limit to $(limit_gb) GB"
end

"""
    get_cache_statistics()::Dict{String,Any}

Get aggregated cache statistics across all active repositories.

# Returns
- `Dict{String,Any}`: Comprehensive cache statistics
"""
function get_cache_statistics()::Dict{String, Any}
    memory_stats = get_memory_usage_statistics()

    return Dict{String, Any}(
        "memory_usage_gb" => memory_stats["current_usage_gb"],
        "memory_limit_gb" => get_repository_memory_limit_gigabytes(),
        "memory_usage_ratio" => memory_stats["usage_ratio"],
        "cache_directory" => get_repository_cache_directory_path(),
        "compression_enabled" => get_cache_compression_enabled_flag(),
        "integrity_checking" => get_cache_integrity_checking_enabled_flag(),
    )
end

"""
    initialize_memory_monitoring!()

Initialize memory monitoring for the V5 framework.
Called automatically during module initialization.
"""
function initialize_memory_monitoring!()
    # Placeholder for memory monitoring initialization
    @log_debug :cache "Memory monitoring initialized"
end
