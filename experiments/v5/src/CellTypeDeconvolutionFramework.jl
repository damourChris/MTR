"""
Cell Type Deconvolution Framework

A repository-based scientific code framework for cell type deconvolution

Repository infrastructure framework with robust
logging, preferences, and exception systems while incorporating intelligent
caching and GNN graph construction capabilities.

# Key Features

- **Repository Pattern**: Dictionary-like API for transparent data access
- **Intelligent Caching**: Memory-aware caching with automatic eviction
- **GNN Graph Construction**: Clean conversion from OntologyTrees to GNN graphs
- **Resource Management**: Memory monitoring and dependency tracking
- **Legacy Integration**: Seamless use of logging, preferences, and exceptions

# Quick Start

```julia
using CellTypeDeconvolutionFramework

# Create a repository with intelligent caching
repo = create_data_repository()

# Access data with automatic caching
reference_data = repo["reference/GSE22886"]
gene_graph = repo["graphs/correlation_threshold_0.3"]
ontology_tree = repo["ontology/immune_cells"]

# GNN graph construction
gnn_graph = construct_gnn_graph_from_ontology(ontology_tree, reference_data)
```

# Repository API

The repository provides a dictionary-like interface:
- `repo[key]` - Get data, loading and caching as needed
- `haskey(repo, key)` - Check if data exists
- `delete!(repo, key)` - Remove cached data
- `keys(repo)` - List available data keys

# Memory Management

Automatic memory management prevents OOM:
- Configurable memory limits via preferences
- LRU eviction with usage tracking
- Dependency-aware cache invalidation
- Lazy loading for large datasets
"""
module CellTypeDeconvolutionFramework

# Re-export key components for seamless integration
using Preferences
using Logging
using LoggingExtras

# Core dependencies for repository and caching functionality
using JLD2
using HDF5
using SHA
using Serialization
using Dates
using Statistics
using LinearAlgebra

# Data structure and graph dependencies
using DataFrames
using Graphs
using GraphNeuralNetworks
using OntologyTrees
using LRUCache

# Utility modules
include("utils/exceptions.jl")
include("utils/preferences_config.jl")
include("utils/logging.jl")
include("utils/serialization.jl")
include("utils/hashing.jl")

# Repository infrastructure
include("repositories/abstract_repository.jl")
include("repositories/memory_repository.jl")

# Resource management system
include("resource_management/memory_monitor.jl")
include("resource_management/cache_manager.jl")

# Data source implementations (placeholder for future implementation)
# include("data_sources/reference_data_source.jl")
# include("data_sources/ontology_data_source.jl")
# include("data_sources/synthetic_data_source.jl")
# include("data_sources/computed_data_source.jl")

# GNN graph construction pipeline
include("graph_construction/ontology_loader.jl")
include("graph_construction/graph_converter.jl")

# =============================================================================
# PUBLIC API EXPORTS
# =============================================================================

# Repository interface and basic implementations
export AbstractRepository, MemoryRepository

# Exception system
export RepositoryAccessError,
    CacheCorruptionError, MemoryLimitExceededError, ConfigurationError

# Preferences management (simplified functions)
export get_memory_limit_gb,
    get_cache_directory_path, set_memory_limit_gb!, set_cache_directory_path!

# Graph construction
export load_ontology_tree, build_gnn_hetero_graph_from_ontology

# Utility functions
export generate_cache_key, serialize_for_caching, deserialize_from_cache

# Convenience functions
export create_memory_repository

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

function __init__()
    # Initialize framework preferences
    initialize_framework_preferences!()

    # Initialize memory monitoring
    return initialize_memory_monitoring!()
end

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

"""
    create_memory_repository(; memory_limit_gb=2.0, max_items=10000)

Create a memory repository with specified limits.

# Arguments
- `memory_limit_gb::Float64`: Memory limit in GB (default: 2.0)
- `max_items::Int`: Maximum number of items (default: 10000)

# Returns
- `MemoryRepository`: Repository instance ready for data access

# Example
```julia
# Create repository with default settings
repo = create_memory_repository()

# Create repository with custom limits
repo = create_memory_repository(memory_limit_gb=4.0, max_items=5000)
```
"""
function create_memory_repository(; memory_limit_gb::Float64 = 2.0, max_items::Int = 10000)
    return MemoryRepository(memory_limit_gb = memory_limit_gb, max_items = max_items)
end

end # module CellTypeDeconvolutionFramework
