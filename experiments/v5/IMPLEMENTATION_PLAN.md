# V5 Implementation Plan: Repository-Based Scientific Computing Framework

## Overview

V5 builds upon the solid foundations of V4 (logging, preferences, exceptions) and incorporates the caching intelligence from V3, while addressing the core challenge of GNN graph construction from OntologyTrees.

## Core Architecture

### 1. Repository Pattern Implementation

**Goal**: Create a dictionary-like API that transparently handles caching, loading, and saving of scientific data.

```julia
# Example usage:
repo = DataRepository()
reference_data = repo["preprocessed_reference/GSE22886"]  # Auto-loads/caches
gene_graph = repo["gene_correlation_graph/threshold_0.3"]  # Computed on demand
ontology_tree = repo["ontology/immune_cells"]  # Cached from OBO files
```

**Components**:
- `AbstractRepository` - Interface defining the repository contract
- `CachedFileRepository` - File-based repository with intelligent caching
- `MemoryRepository` - In-memory repository for temporary data
- `CompositeRepository` - Hierarchical repository combining multiple sources

### 2. Resource Management System

**Goal**: Memory-aware caching that prevents OOM while maximizing performance.

**Features**:
- Automatic memory monitoring and cache eviction
- LRU-based eviction with usage tracking
- Configurable memory limits via preferences
- Lazy loading with dependency tracking
- TTL-based invalidation for time-sensitive data

### 3. GNN Graph Construction Pipeline

**Goal**: Clean, reproducible conversion from OntologyTrees to GNN-ready graph structures.

**Pipeline Stages**:
1. **Ontology Loading** - Load and validate OntologyTree structures
2. **Graph Generation** - Convert hierarchical ontology to graph representation
3. **Feature Engineering** - Add node/edge features from gene expression data
4. **Graph Optimization** - Prune, normalize, and prepare for GNN training
5. **Serialization** - Cache processed graphs for reuse

### 4. Integration with V4 Systems

**Logging Integration**:
- Repository operations logged with structured metadata
- Cache hit/miss metrics and performance tracking
- Memory usage monitoring and alerts

**Preferences Integration**:
- Cache configuration (memory limits, file paths, TTL)
- GNN graph construction parameters
- Repository backend selection

**Exception Integration**:
- Repository-specific exceptions for data access failures
- Cache corruption detection and recovery
- Dependency resolution failures

## Directory Structure

```
v5/
├── Project.toml
├── Manifest.toml
├── LocalPreferences.toml
├── .JuliaFormatter.toml
├── README.md
├── IMPLEMENTATION_PLAN.md
├── src/
│   ├── CellTypeDeconvolutionFrameworkV5.jl
│   ├── repositories/
│   │   ├── abstract_repository.jl
│   │   ├── cached_file_repository.jl
│   │   ├── memory_repository.jl
│   │   ├── composite_repository.jl
│   │   └── repository_factory.jl
│   ├── resource_management/
│   │   ├── cache_manager.jl
│   │   ├── memory_monitor.jl
│   │   ├── eviction_policies.jl
│   │   └── dependency_tracker.jl
│   ├── graph_construction/
│   │   ├── ontology_loader.jl
│   │   ├── graph_converter.jl
│   │   ├── feature_engineering.jl
│   │   ├── graph_optimizer.jl
│   │   └── gnn_adapters.jl
│   ├── data_sources/
│   │   ├── reference_data_source.jl
│   │   ├── ontology_data_source.jl
│   │   ├── synthetic_data_source.jl
│   │   └── computed_data_source.jl
│   ├── integration/
│   │   ├── v4_compatibility.jl
│   │   ├── preferences_config.jl
│   │   ├── logging_setup.jl
│   │   └── exception_handling.jl
│   └── utils/
│       ├── serialization.jl
│       ├── hashing.jl
│       └── validation.jl
├── test/
│   ├── runtests.jl
│   ├── test_repositories.jl
│   ├── test_resource_management.jl
│   ├── test_graph_construction.jl
│   └── test_integration.jl
├── examples/
│   ├── basic_usage.jl
│   ├── graph_construction_demo.jl
│   └── performance_comparison.jl
└── docs/
    ├── repository_api.md
    ├── graph_construction_guide.md
    └── migration_from_v3_v4.md
```

## Implementation Phases

### Phase 1: Core Repository Infrastructure
1. Abstract repository interface
2. Basic file-based repository with caching
3. Memory repository for temporary data
4. Configuration integration with V4 preferences

### Phase 2: Resource Management
1. Memory monitoring and limits
2. LRU eviction policies
3. Dependency tracking for cache invalidation
4. Performance metrics and logging

### Phase 3: GNN Graph Construction
1. OntologyTree loader with validation
2. Graph conversion algorithms
3. Feature engineering pipeline
4. GNN framework adapters

### Phase 4: Integration and Optimization
1. V4 system integration (logging, exceptions, preferences)
2. Performance optimization
3. Memory usage optimization
4. Comprehensive testing

### Phase 5: Documentation and Examples
1. API documentation
2. Usage examples
3. Migration guides
4. Performance benchmarks

## Key Design Decisions

### Repository API Design
```julia
# Dictionary-like interface with type safety
repo[key::String] -> Any
repo[key::String, ::Type{T}] -> T  # Type-safe access
haskey(repo, key::String) -> Bool
delete!(repo, key::String) -> Nothing
keys(repo) -> Iterator{String}
```

### Caching Strategy
- **Hash-based keys**: SHA256 of input parameters and data dependencies
- **Hierarchical invalidation**: Changes to source data invalidate derived data
- **Configurable backends**: File, memory, or hybrid storage
- **Compression**: Automatic compression for large cached objects

### Memory Management
- **Soft limits**: Begin eviction at 80% of memory limit
- **Hard limits**: Force eviction at 95% of memory limit
- **Priority-based eviction**: Prefer evicting computed over source data
- **Usage tracking**: LRU with access frequency weighting

### GNN Graph Construction
- **Modular pipeline**: Each stage can be cached and reused independently
- **Multiple backends**: Support for different GNN frameworks
- **Validation**: Automatic graph validation and consistency checking
- **Optimization**: Graph pruning and normalization for training efficiency

## Benefits over V3/V4

1. **Unified Data Access**: Single API for all data types (source, computed, cached)
2. **Memory Efficiency**: Intelligent caching prevents OOM while maximizing performance
3. **Reproducibility**: Hash-based caching ensures consistent results
4. **Extensibility**: Plugin architecture for new data sources and repositories
5. **Integration**: Seamless use of V4's robust logging and configuration systems
6. **Performance**: Lazy loading and intelligent prefetching reduce wait times

## Questions for Implementation

1. **Cache Storage Format**: Prefer JLD2 for Julia compatibility or HDF5 for cross-language use?
2. **Memory Limits**: Default to 50% of system RAM or make it configurable?
3. **GNN Framework**: Target GraphNeuralNetworks.jl, Flux.jl, or multiple backends?
4. **Dependency Tracking**: Should changes to preferences invalidate all cached data?
5. **Concurrency**: Support for multi-threaded repository access?

## Migration Path

### From V3
- Import existing cache files with format detection
- Migrate cache configuration to V5 preferences
- Preserve cache keys for backward compatibility

### From V4
- Direct import of logging, preferences, and exception systems
- Configuration migration with validation
- Preserve existing experiment configurations

## Success Metrics

1. **Performance**: 10x reduction in data loading time for cached data
2. **Memory Usage**: Stable memory usage under configurable limits
3. **Developer Experience**: Simple dictionary-like API reduces code complexity
4. **Reliability**: Automatic cache validation prevents corruption issues
5. **Maintainability**: Clear separation of concerns and modular architecture
