"""
Serialization utilities for repository system.

Provides consistent serialization and deserialization for caching with support
for compression, integrity checking, and multiple formats. Uses JLD2 as the
primary format for Julia objects.
"""

using JLD2
using Serialization
using Dates

"""
    serialize_for_caching(data::Any, file_path::String; compress::Bool=true)

Serialize data to a cache file using JLD2 format with optional compression.

# Arguments
- `data::Any`: Data object to serialize
- `file_path::String`: Path where the serialized data will be stored
- `compress::Bool`: Whether to enable compression (default: true)

# Returns
- `String`: Checksum of the serialized data for integrity verification

# Throws
- `SerializationError`: If serialization fails
"""
function serialize_for_caching(data::Any, file_path::String; compress::Bool = true)::String
    try
        # Ensure directory exists
        cache_dir = dirname(file_path)
        if !isdir(cache_dir)
            mkpath(cache_dir)
        end

        # Create metadata for the cached object
        metadata = Dict{String, Any}(
            "created_at" => now(),
            "data_type" => string(typeof(data)),
            "serialization_format" => "JLD2",
            "compression_enabled" => compress,
            "framework_version" => "1.0.0",
        )

        # Serialize with JLD2
        jldopen(file_path, "w"; compress = compress) do file
            file["data"] = data
            return file["metadata"] = metadata
        end

        # Generate and return checksum
        return generate_file_checksum(file_path)

    catch e
        throw(
            SerializationError(
                "Failed to serialize data to cache file",
                "serialize",
                string(typeof(data)),
                "JLD2",
                e,
            ),
        )
    end
end

"""
    deserialize_from_cache(file_path::String; verify_checksum::Union{String,Nothing}=nothing)

Deserialize data from a cache file with optional integrity verification.

# Arguments
- `file_path::String`: Path to the cached data file
- `verify_checksum::Union{String,Nothing}`: Expected checksum for verification (optional)

# Returns
- `Any`: Deserialized data object

# Throws
- `SerializationError`: If deserialization fails
- `CacheCorruptionError`: If integrity check fails
"""
function deserialize_from_cache(
    file_path::String;
    verify_checksum::Union{String, Nothing} = nothing,
)
    try
        # Verify file exists
        if !isfile(file_path)
            throw(
                SerializationError(
                    "Cache file does not exist",
                    "deserialize",
                    "unknown",
                    "JLD2",
                    SystemError("File not found: $file_path"),
                ),
            )
        end

        # Verify checksum if provided
        if verify_checksum !== nothing
            validate_cache_integrity(file_path, verify_checksum)
        end

        # Deserialize with JLD2
        data, metadata = jldopen(file_path, "r") do file
            if !haskey(file, "data")
                throw(
                    SerializationError(
                        "Cache file missing data field",
                        "deserialize",
                        "unknown",
                        "JLD2",
                        nothing,
                    ),
                )
            end

            data = file["data"]
            metadata = get(file, "metadata", Dict{String, Any}())
            return data, metadata
        end

        # Log cache hit for debugging
        if get_cache_operation_logging_enabled()
            @debug "Cache hit" file_path = file_path data_type =
                get(metadata, "data_type", "unknown")
        end

        return data

    catch e
        if isa(e, CacheCorruptionError)
            rethrow(e)
        else
            throw(
                SerializationError(
                    "Failed to deserialize data from cache file",
                    "deserialize",
                    "unknown",
                    "JLD2",
                    e,
                ),
            )
        end
    end
end

"""
    get_cache_metadata(file_path::String)::Dict{String,Any}

Retrieve metadata from a cached file without loading the data.

# Arguments
- `file_path::String`: Path to the cached data file

# Returns
- `Dict{String,Any}`: Metadata dictionary

# Throws
- `SerializationError`: If metadata cannot be read
"""
function get_cache_metadata(file_path::String)::Dict{String, Any}
    try
        if !isfile(file_path)
            return Dict{String, Any}()
        end

        return jldopen(file_path, "r") do file
            return get(file, "metadata", Dict{String, Any}())
        end

    catch e
        throw(
            SerializationError(
                "Failed to read cache metadata",
                "metadata_read",
                "unknown",
                "JLD2",
                e,
            ),
        )
    end
end

"""
    estimate_serialized_size(data::Any)::Int

Estimate the size in bytes that data would occupy when serialized.

# Arguments
- `data::Any`: Data object to estimate size for

# Returns
- `Int`: Estimated size in bytes

# Note
This provides a rough estimate by serializing to memory. For large objects,
this may be expensive.
"""
function estimate_serialized_size(data::Any)::Int
    try
        io = IOBuffer()
        serialize(io, data)
        return length(take!(io))
    catch e
        # Fallback estimate based on object size in memory
        @warn "Could not estimate serialized size, using memory size estimate" error = e
        return sizeof(data)
    end
end

"""
    is_cache_file_valid(file_path::String)::Bool

Check if a cache file is valid and can be read.

# Arguments
- `file_path::String`: Path to the cache file

# Returns
- `Bool`: true if file is valid, false otherwise
"""
function is_cache_file_valid(file_path::String)::Bool
    try
        if !isfile(file_path) || filesize(file_path) == 0
            return false
        end

        # Try to open the file and read metadata
        jldopen(file_path, "r") do file
            return haskey(file, "data")
        end

        return true

    catch e
        @debug "Cache file validation failed" file_path = file_path error = e
        return false
    end
end

"""
    compress_cache_file(file_path::String)::String

Compress an existing cache file in place.

# Arguments
- `file_path::String`: Path to the cache file to compress

# Returns
- `String`: New checksum after compression

# Throws
- `SerializationError`: If compression fails
"""
function compress_cache_file(file_path::String)::String
    try
        if !isfile(file_path)
            throw(
                SerializationError(
                    "Cannot compress non-existent cache file",
                    "compress",
                    "unknown",
                    "JLD2",
                    SystemError("File not found: $file_path"),
                ),
            )
        end

        # Read data and metadata
        data, metadata = jldopen(file_path, "r") do file
            return file["data"], get(file, "metadata", Dict{String, Any}())
        end

        # Update metadata
        metadata["compression_enabled"] = true
        metadata["compressed_at"] = now()

        # Write back with compression
        jldopen(file_path, "w"; compress = true) do file
            file["data"] = data
            return file["metadata"] = metadata
        end

        return generate_file_checksum(file_path)

    catch e
        throw(
            SerializationError(
                "Failed to compress cache file",
                "compress",
                "unknown",
                "JLD2",
                e,
            ),
        )
    end
end

"""
    batch_serialize_data(data_dict::Dict{String,Any}, cache_dir::String; compress::Bool=true)::Dict{String,String}

Serialize multiple data objects to cache files efficiently.

# Arguments
- `data_dict::Dict{String,Any}`: Dictionary mapping cache keys to data objects
- `cache_dir::String`: Directory to store cache files
- `compress::Bool`: Whether to enable compression (default: true)

# Returns
- `Dict{String,String}`: Dictionary mapping cache keys to file checksums

# Example
```julia
data = Dict("key1" => df1, "key2" => df2)
checksums = batch_serialize_data(data, "/path/to/cache")
```
"""
function batch_serialize_data(
    data_dict::Dict{String, Any},
    cache_dir::String;
    compress::Bool = true,
)::Dict{String, String}
    # Ensure cache directory exists
    if !isdir(cache_dir)
        mkpath(cache_dir)
    end

    checksums = Dict{String, String}()

    for (cache_key, data) in data_dict
        try
            # Generate safe filename from cache key
            safe_filename = replace(cache_key, "/" => "_") * ".jld2"
            file_path = joinpath(cache_dir, safe_filename)

            # Serialize data
            checksum = serialize_for_caching(data, file_path; compress = compress)
            checksums[cache_key] = checksum

        catch e
            @warn "Failed to serialize data for key: $cache_key" error = e
            # Continue with other keys
        end
    end

    return checksums
end

"""
    cleanup_invalid_cache_files(cache_dir::String)::Int

Remove invalid or corrupted cache files from a directory.

# Arguments
- `cache_dir::String`: Directory containing cache files

# Returns
- `Int`: Number of files removed

# Example
```julia
removed_count = cleanup_invalid_cache_files("/path/to/cache")
println("Removed \$removed_count invalid cache files")
```
"""
function cleanup_invalid_cache_files(cache_dir::String)::Int
    if !isdir(cache_dir)
        return 0
    end

    removed_count = 0

    for file_name in readdir(cache_dir)
        file_path = joinpath(cache_dir, file_name)

        # Skip directories and non-JLD2 files
        if isdir(file_path) || !endswith(file_name, ".jld2")
            continue
        end

        # Check if file is valid
        if !is_cache_file_valid(file_path)
            try
                rm(file_path)
                removed_count += 1
                @log_info :cache "Removed invalid cache file: $file_path"
            catch e
                @log_warn :cache "Failed to remove invalid cache file: $file_path"
            end
        end
    end

    return removed_count
end

"""
    get_cache_directory_statistics(cache_dir::String)::Dict{String,Any}

Get statistics about cache files in a directory.

# Arguments
- `cache_dir::String`: Directory containing cache files

# Returns
- `Dict{String,Any}`: Statistics including file count, total size, etc.
"""
function get_cache_directory_statistics(cache_dir::String)::Dict{String, Any}
    if !isdir(cache_dir)
        return Dict{String, Any}(
            "directory_exists" => false,
            "file_count" => 0,
            "total_size_bytes" => 0,
        )
    end

    file_count = 0
    total_size = 0
    valid_files = 0
    invalid_files = 0
    compressed_files = 0

    for file_name in readdir(cache_dir)
        file_path = joinpath(cache_dir, file_name)

        # Skip directories and non-JLD2 files
        if isdir(file_path) || !endswith(file_name, ".jld2")
            continue
        end

        file_count += 1
        total_size += filesize(file_path)

        # Check validity and compression
        if is_cache_file_valid(file_path)
            valid_files += 1

            try
                metadata = get_cache_metadata(file_path)
                if get(metadata, "compression_enabled", false)
                    compressed_files += 1
                end
            catch e
                # Count as valid but unknown compression status
            end
        else
            invalid_files += 1
        end
    end

    return Dict{String, Any}(
        "directory_exists" => true,
        "file_count" => file_count,
        "valid_files" => valid_files,
        "invalid_files" => invalid_files,
        "compressed_files" => compressed_files,
        "total_size_bytes" => total_size,
        "total_size_mb" => round(total_size / 1024 / 1024, digits = 2),
    )
end

# =============================================================================
# HELPER FUNCTIONS FOR INTEGRATION
# =============================================================================

"""
    get_cache_operation_logging_enabled()::Bool

Check if cache operation logging is enabled from preferences.
This is a placeholder function that would integrate with the preferences system.
"""
function get_cache_operation_logging_enabled()::Bool
    # This would normally call the preferences system
    # For now, return false to avoid dependency issues during development
    return false
end
