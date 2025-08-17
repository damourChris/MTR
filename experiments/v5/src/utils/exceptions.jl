"""
Exception handling system for repository-based framework.

Extended exception system with repository-specific exceptions for data access,
caching, and memory management failures. All exceptions provide maximally
descriptive error messages following the style guide.
"""

# Re-export core exceptions that are still relevant
export DataValidationError,
    ModelConvergenceError,
    InvalidProportionError,
    MissingReferenceDataError,
    IncompatibleModelConfigurationError

# New repository-specific exceptions
export RepositoryAccessError,
    CacheCorruptionError,
    MemoryLimitExceededError,
    DataSourceUnavailableError,
    CacheKeyNotFoundError,
    SerializationError,
    GraphConstructionError,
    OntologyTreeInvalidError,
    ConfigurationError

# =============================================================================
# V4 EXCEPTION TYPES (COPIED FOR SELF-CONTAINED V5)
# =============================================================================

"""
    DataValidationError <: Exception

Thrown when input data fails validation checks.

Contains specific information about which validation rule was violated
and what the expected data characteristics should be.
"""
struct DataValidationError <: Exception
    message::String
    invalid_field_name::String
    expected_characteristics::String
    actual_characteristics::String
end

function Base.showerror(io::IO, e::DataValidationError)
    print(io, "DataValidationError: ")
    print(io, e.message)
    print(io, "\nField: ", e.invalid_field_name)
    print(io, "\nExpected: ", e.expected_characteristics)
    return print(io, "\nActual: ", e.actual_characteristics)
end

"""
    ModelConvergenceError <: Exception

Thrown when iterative model training fails to converge within specified limits.

Provides information about convergence criteria and number of iterations completed.
"""
struct ModelConvergenceError <: Exception
    message::String
    model_type::String
    max_iterations_attempted::Int
    final_loss_value::Float64
    convergence_tolerance::Float64
end

function Base.showerror(io::IO, e::ModelConvergenceError)
    print(io, "ModelConvergenceError: ")
    print(io, e.message)
    print(io, "\nModel: ", e.model_type)
    print(io, "\nIterations completed: ", e.max_iterations_attempted)
    print(io, "\nFinal loss: ", e.final_loss_value)
    return print(io, "\nRequired tolerance: ", e.convergence_tolerance)
end

"""
    InvalidProportionError <: Exception

Thrown when cell type proportions violate biological constraints.

Occurs when proportions are negative or do not sum to 1.0 for each sample,
which violates the fundamental constraint that cell types partition the population.
"""
struct InvalidProportionError <: Exception
    message::String
    sample_identifier::String
    proportion_sum::Float64
    invalid_proportions::Vector{Float64}
end

function Base.showerror(io::IO, e::InvalidProportionError)
    print(io, "InvalidProportionError: ")
    print(io, e.message)
    print(io, "\nSample: ", e.sample_identifier)
    print(io, "\nProportion sum: ", e.proportion_sum)
    return print(io, "\nInvalid values: ", e.invalid_proportions)
end

"""
    MissingReferenceDataError <: Exception

Thrown when required reference datasets or gene signatures are not available.

Provides information about which specific reference data is missing and
where it was expected to be found.
"""
struct MissingReferenceDataError <: Exception
    message::String
    missing_data_type::String
    expected_file_path::String
    required_gene_identifiers::Vector{String}
end

function Base.showerror(io::IO, e::MissingReferenceDataError)
    print(io, "MissingReferenceDataError: ")
    print(io, e.message)
    print(io, "\nMissing data: ", e.missing_data_type)
    print(io, "\nExpected location: ", e.expected_file_path)
    if !isempty(e.required_gene_identifiers)
        print(
            io,
            "\nRequired genes: ",
            join(e.required_gene_identifiers[1:min(5, end)], ", "),
        )
        if length(e.required_gene_identifiers) > 5
            print(io, " (and ", length(e.required_gene_identifiers) - 5, " more)")
        end
    end
end

"""
    IncompatibleModelConfigurationError <: Exception

Thrown when model hyperparameters are incompatible with the provided data.

For example, when the specified number of output neurons doesn't match
the number of cell types in the reference dataset.
"""
struct IncompatibleModelConfigurationError <: Exception
    message::String
    configuration_parameter_name::String
    configured_value::Any
    data_derived_requirement::Any
end

function Base.showerror(io::IO, e::IncompatibleModelConfigurationError)
    print(io, "IncompatibleModelConfigurationError: ")
    print(io, e.message)
    print(io, "\nParameter: ", e.configuration_parameter_name)
    print(io, "\nConfigured value: ", e.configured_value)
    return print(io, "\nRequired by data: ", e.data_derived_requirement)
end

# =============================================================================
# V5 REPOSITORY-SPECIFIC EXCEPTIONS
# =============================================================================

"""
    RepositoryAccessError <: Exception

Thrown when repository operations fail due to access permissions, file system
errors, or other storage-related issues.

Provides detailed information about the failed operation and underlying cause.
"""
struct RepositoryAccessError <: Exception
    message::String
    operation_type::String
    cache_key::String
    underlying_error::Union{Exception, Nothing}
    suggested_resolution::String
end

function Base.showerror(io::IO, e::RepositoryAccessError)
    print(io, "RepositoryAccessError: ")
    print(io, e.message)
    print(io, "\nOperation: ", e.operation_type)
    print(io, "\nCache key: ", e.cache_key)
    if e.underlying_error !== nothing
        print(io, "\nUnderlying error: ", e.underlying_error)
    end
    return print(io, "\nSuggested resolution: ", e.suggested_resolution)
end

"""
    CacheCorruptionError <: Exception

Thrown when cached data fails integrity checks or cannot be deserialized.

Indicates that cached data has been corrupted and needs to be regenerated
from the original source.
"""
struct CacheCorruptionError <: Exception
    message::String
    cache_key::String
    cache_file_path::String
    corruption_type::String
    expected_checksum::Union{String, Nothing}
    actual_checksum::Union{String, Nothing}
end

function Base.showerror(io::IO, e::CacheCorruptionError)
    print(io, "CacheCorruptionError: ")
    print(io, e.message)
    print(io, "\nCache key: ", e.cache_key)
    print(io, "\nFile path: ", e.cache_file_path)
    print(io, "\nCorruption type: ", e.corruption_type)
    if e.expected_checksum !== nothing && e.actual_checksum !== nothing
        print(io, "\nExpected checksum: ", e.expected_checksum)
        print(io, "\nActual checksum: ", e.actual_checksum)
    end
end

"""
    MemoryLimitExceededError <: Exception

Thrown when repository operations would exceed configured memory limits.

Provides information about current memory usage and the operation that
would have caused the limit to be exceeded.
"""
struct MemoryLimitExceededError <: Exception
    message::String
    current_memory_usage_gb::Float64
    memory_limit_gb::Float64
    requested_operation::String
    estimated_additional_memory_gb::Float64
    suggested_actions::Vector{String}
end

function Base.showerror(io::IO, e::MemoryLimitExceededError)
    print(io, "MemoryLimitExceededError: ")
    print(io, e.message)
    print(io, "\nCurrent usage: ", e.current_memory_usage_gb, " GB")
    print(io, "\nMemory limit: ", e.memory_limit_gb, " GB")
    print(io, "\nRequested operation: ", e.requested_operation)
    print(io, "\nEstimated additional memory: ", e.estimated_additional_memory_gb, " GB")
    print(io, "\nSuggested actions:")
    for action in e.suggested_actions
        print(io, "\n  - ", action)
    end
end

"""
    DataSourceUnavailableError <: Exception

Thrown when a data source (file, URL, database) is not accessible.

Provides information about the data source that failed and potential
reasons for the failure.
"""
struct DataSourceUnavailableError <: Exception
    message::String
    data_source_type::String
    data_source_location::String
    failure_reason::String
    retry_recommended::Bool
end

function Base.showerror(io::IO, e::DataSourceUnavailableError)
    print(io, "DataSourceUnavailableError: ")
    print(io, e.message)
    print(io, "\nSource type: ", e.data_source_type)
    print(io, "\nLocation: ", e.data_source_location)
    print(io, "\nFailure reason: ", e.failure_reason)
    return print(io, "\nRetry recommended: ", e.retry_recommended ? "Yes" : "No")
end

"""
    CacheKeyNotFoundError <: Exception

Thrown when a requested cache key does not exist and cannot be generated.

Indicates that the repository cannot provide the requested data because
the key is invalid or the data source is unavailable.
"""
struct CacheKeyNotFoundError <: Exception
    message::String
    requested_key::String
    available_keys::Vector{String}
    key_pattern_suggestion::Union{String, Nothing}
end

function Base.showerror(io::IO, e::CacheKeyNotFoundError)
    print(io, "CacheKeyNotFoundError: ")
    print(io, e.message)
    print(io, "\nRequested key: ", e.requested_key)
    if e.key_pattern_suggestion !== nothing
        print(io, "\nSuggested pattern: ", e.key_pattern_suggestion)
    end
    if !isempty(e.available_keys)
        print(io, "\nAvailable keys (first 5): ")
        print(io, join(e.available_keys[1:min(5, end)], ", "))
        if length(e.available_keys) > 5
            print(io, " (and ", length(e.available_keys) - 5, " more)")
        end
    end
end

"""
    SerializationError <: Exception

Thrown when data cannot be serialized to or deserialized from cache storage.

Provides information about the serialization format and the data type
that caused the failure.
"""
struct SerializationError <: Exception
    message::String
    operation_type::String  # "serialize" or "deserialize"
    data_type::String
    serialization_format::String
    underlying_error::Union{Exception, Nothing}
end

function Base.showerror(io::IO, e::SerializationError)
    print(io, "SerializationError: ")
    print(io, e.message)
    print(io, "\nOperation: ", e.operation_type)
    print(io, "\nData type: ", e.data_type)
    print(io, "\nFormat: ", e.serialization_format)
    if e.underlying_error !== nothing
        print(io, "\nUnderlying error: ", e.underlying_error)
    end
end

"""
    GraphConstructionError <: Exception

Thrown when GNN graph construction from ontology trees fails.

Provides detailed information about the stage of graph construction
that failed and the specific error encountered.
"""
struct GraphConstructionError <: Exception
    message::String
    construction_stage::String  # "loading", "conversion", "feature_engineering", "optimization"
    ontology_tree_info::String
    reference_data_info::String
    underlying_error::Union{Exception, Nothing}
end

function Base.showerror(io::IO, e::GraphConstructionError)
    print(io, "GraphConstructionError: ")
    print(io, e.message)
    print(io, "\nConstruction stage: ", e.construction_stage)
    print(io, "\nOntology tree: ", e.ontology_tree_info)
    print(io, "\nReference data: ", e.reference_data_info)
    if e.underlying_error !== nothing
        print(io, "\nUnderlying error: ", e.underlying_error)
    end
end

"""
    OntologyTreeInvalidError <: Exception

Thrown when an OntologyTree structure is invalid or corrupted.

Validates that the ontology tree has the required structure for
GNN graph construction.
"""
struct OntologyTreeInvalidError <: Exception
    message::String
    validation_failure::String
    tree_statistics::Dict{String, Any}
    required_properties::Vector{String}
end

function Base.showerror(io::IO, e::OntologyTreeInvalidError)
    print(io, "OntologyTreeInvalidError: ")
    print(io, e.message)
    print(io, "\nValidation failure: ", e.validation_failure)
    print(io, "\nRequired properties: ", join(e.required_properties, ", "))
    print(io, "\nTree statistics:")
    for (key, value) in e.tree_statistics
        print(io, "\n  $key: $value")
    end
end

# =============================================================================
# EXCEPTION HELPER FUNCTIONS
# =============================================================================

"""
    wrap_repository_exception(operation::String, key::String, error::Exception)

Wrap an underlying exception in a RepositoryAccessError with context.

# Arguments
- `operation::String`: The repository operation that failed (e.g., "read", "write", "delete")
- `key::String`: The cache key that was being accessed
- `error::Exception`: The underlying exception that caused the failure

# Returns
- `RepositoryAccessError`: Wrapped exception with repository context
"""
function wrap_repository_exception(operation::String, key::String, error::Exception)
    suggested_resolution = if isa(error, SystemError)
        "Check file permissions and disk space"
    elseif isa(error, ArgumentError)
        "Verify cache key format and parameters"
    else
        "Check repository configuration and data source availability"
    end

    return RepositoryAccessError(
        "Repository $operation operation failed for key '$key'",
        operation,
        key,
        error,
        suggested_resolution,
    )
end

"""
    validate_memory_operation(current_gb::Float64, additional_gb::Float64, limit_gb::Float64, operation::String)

Check if a memory operation would exceed limits and throw appropriate exception.

# Arguments
- `current_gb::Float64`: Current memory usage in GB
- `additional_gb::Float64`: Additional memory needed for operation in GB  
- `limit_gb::Float64`: Memory limit in GB
- `operation::String`: Description of the operation being attempted

# Throws
- `MemoryLimitExceededError`: If operation would exceed memory limits
"""
function validate_memory_operation(
    current_gb::Float64,
    additional_gb::Float64,
    limit_gb::Float64,
    operation::String,
)
    if current_gb + additional_gb > limit_gb
        suggested_actions = [
            "Increase memory limit with configure_memory_limits!()",
            "Clear cache with clean_cache!(repo, aggressive=true)",
            "Process data in smaller chunks",
            "Use streaming data access patterns",
        ]

        throw(
            MemoryLimitExceededError(
                "Operation '$operation' would exceed memory limit",
                current_gb,
                limit_gb,
                operation,
                additional_gb,
                suggested_actions,
            ),
        )
    end
end

"""
    validate_cache_integrity(file_path::String, expected_checksum::Union{String,Nothing}=nothing)

Validate that a cache file is not corrupted.

# Arguments
- `file_path::String`: Path to the cache file
- `expected_checksum::Union{String,Nothing}`: Expected file checksum (optional)

# Throws
- `CacheCorruptionError`: If file is corrupted or checksum mismatch
"""
function validate_cache_integrity(
    file_path::String,
    expected_checksum::Union{String, Nothing} = nothing,
)
    if !isfile(file_path)
        throw(
            CacheCorruptionError(
                "Cache file does not exist",
                basename(file_path),
                file_path,
                "file_missing",
                expected_checksum,
                nothing,
            ),
        )
    end

    # Check file size
    file_size = filesize(file_path)
    if file_size == 0
        throw(
            CacheCorruptionError(
                "Cache file is empty",
                basename(file_path),
                file_path,
                "empty_file",
                expected_checksum,
                "0",
            ),
        )
    end

    # Verify checksum if provided
    if expected_checksum !== nothing
        actual_checksum = open(file_path, "r") do file
            return bytes2hex(sha256(read(file)))
        end

        if actual_checksum != expected_checksum
            throw(
                CacheCorruptionError(
                    "Cache file checksum mismatch",
                    basename(file_path),
                    file_path,
                    "checksum_mismatch",
                    expected_checksum,
                    actual_checksum,
                ),
            )
        end
    end
end

# =============================================================================
# CONFIGURATION ERROR
# =============================================================================

"""
    ConfigurationError <: Exception

Generic configuration error for framework setup and preference issues.

Used when configuration values are invalid, missing, or incompatible.
"""
struct ConfigurationError <: Exception
    message::String
    parameter_name::String
    parameter_value::Any
    suggested_fixes::Vector{String}
end

function Base.showerror(io::IO, e::ConfigurationError)
    print(io, "ConfigurationError: ")
    print(io, e.message)
    print(io, "\nParameter: ", e.parameter_name)
    print(io, "\nValue: ", e.parameter_value)
    if !isempty(e.suggested_fixes)
        print(io, "\nSuggested fixes:")
        for fix in e.suggested_fixes
            print(io, "\n  - ", fix)
        end
    end
end
