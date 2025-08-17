"""
Graph conversion module.

Converts OntologyTree structures to GNN-compatible graph formats using
GraphNeuralNetworks.jl. 
"""

using GraphNeuralNetworks
using Graphs
using MetaGraphs
using Statistics

"""
    GraphConverter

Handles conversion from OntologyTree to GNN-compatible graph structures.

Provides methods to convert heterogeneous ontology graphs with both
gene nodes and cell type (term) nodes into formats suitable for
GraphNeuralNetworks.jl training.

# Features
- Heterogeneous graph construction (gene + cell type nodes)
- Automatic node feature extraction
- Edge type mapping and validation
- Integration with V5 repository caching
- Comprehensive validation and error handling
"""
struct GraphConverter
    repository::Union{AbstractRepository, Nothing}
    cache_prefix::String

    function GraphConverter(repository::Union{AbstractRepository, Nothing} = nothing)
        cache_prefix = "gnn_graphs"
        return new(repository, cache_prefix)
    end
end

"""
    convert_ontology_to_gnn_graph(converter::GraphConverter, ontology_tree::OntologyTree; options...)::GNNHeteroGraph

Convert an OntologyTree to a GNNHeteroGraph for neural network training.

# Arguments
- `converter::GraphConverter`: Converter instance
- `ontology_tree::OntologyTree`: Source ontology tree

# Keyword Arguments
- `include_hierarchy_edges::Bool`: Include ontology hierarchy edges (default: from preferences)
- `gene_feature_dim::Int`: Dimension of gene feature vectors (default: auto-detect)
- `cell_feature_dim::Int`: Dimension of cell type feature vectors (default: auto-detect)
- `cache_key::Union{String,Nothing}`: Custom cache key (default: auto-generated)

# Returns
- `GNNHeteroGraph`: Heterogeneous graph ready for GNN training

# Throws
- `GraphConstructionError`: If conversion fails
- `OntologyTreeInvalidError`: If ontology tree is invalid for conversion
"""
function convert_ontology_to_gnn_graph(
    converter::GraphConverter,
    ontology_tree::OntologyTree;
    include_hierarchy_edges::Union{Bool, Nothing} = nothing,
    gene_feature_dim::Union{Int, Nothing} = nothing,
    cell_feature_dim::Union{Int, Nothing} = nothing,
    cache_key::Union{String, Nothing} = nothing,
)::GNNHeteroGraph

    # Set defaults from preferences
    if include_hierarchy_edges === nothing
        include_hierarchy_edges = get_include_ontology_hierarchy_edges_flag()
    end

    # Validate input ontology tree
    validate_ontology_for_gnn_conversion(ontology_tree)

    # Generate cache key if not provided
    if cache_key === nothing
        tree_stats = get_ontology_tree_statistics(ontology_tree)
        cache_params = Dict{String, Any}(
            "tree_vertex_count" => tree_stats["vertex_count"],
            "tree_edge_count" => tree_stats["edge_count"],
            "include_hierarchy_edges" => include_hierarchy_edges,
            "base_term_label" => tree_stats["base_term"],
            "conversion_version" => "v5.1.0",
        )
        cache_key = generate_cache_key(converter.cache_prefix, cache_params)
    end

    # Try to load from cache if repository is available
    if converter.repository !== nothing && haskey(converter.repository, cache_key)
        try
            gnn_graph = converter.repository[cache_key, GNNHeteroGraph]
            validate_gnn_graph_structure(gnn_graph)
            @debug "Loaded GNN graph from cache" cache_key = cache_key
            return gnn_graph
        catch e
            @warn "Failed to load cached GNN graph, rebuilding" cache_key = cache_key error =
                e
            # Continue to build new graph
        end
    end

    # Convert ontology tree to GNN graph
    gnn_graph = build_gnn_hetero_graph_from_ontology(
        ontology_tree,
        include_hierarchy_edges,
        gene_feature_dim,
        cell_feature_dim,
    )

    # Validate the constructed graph
    validate_gnn_graph_structure(gnn_graph)

    # Cache the result if repository is available
    if converter.repository !== nothing &&
       get_data_source_caching_configuration()["graph_construction"]
        try
            converter.repository[cache_key] = gnn_graph
            @debug "Cached GNN graph" cache_key = cache_key
        catch e
            @warn "Failed to cache GNN graph" cache_key = cache_key error = e
            # Continue without caching
        end
    end

    return gnn_graph
end

"""
    build_gnn_hetero_graph_from_ontology(ontology_tree::OntologyTree,
                                         include_hierarchy_edges::Bool,
                                         gene_feature_dim::Union{Int,Nothing},
                                         cell_feature_dim::Union{Int,Nothing})::GNNHeteroGraph

Build a GNNHeteroGraph from an OntologyTree structure.

# Arguments
- `ontology_tree::OntologyTree`: Source ontology tree
- `include_hierarchy_edges::Bool`: Whether to include hierarchy edges
- `gene_feature_dim::Union{Int,Nothing}`: Gene feature dimension
- `cell_feature_dim::Union{Int,Nothing}`: Cell feature dimension

# Returns
- `GNNHeteroGraph`: Constructed heterogeneous graph
"""
function build_gnn_hetero_graph_from_ontology(
    ontology_tree::OntologyTree,
    include_hierarchy_edges::Bool,
    gene_feature_dim::Union{Int, Nothing},
    cell_feature_dim::Union{Int, Nothing},
)::GNNHeteroGraph
    try
        graph = ontology_tree.graph

        # Extract gene and cell type node indices
        gene_indices, cell_indices = extract_node_indices_by_type(graph)

        if isempty(gene_indices) && isempty(cell_indices)
            throw(
                GraphConstructionError(
                    "Ontology tree contains no gene or cell type nodes",
                    "node_extraction",
                    "Empty graph",
                    "No node data available",
                    nothing,
                ),
            )
        end

        # Create index mappings for GNN graph (each node type indexed separately)
        gene_index_mapping = create_node_index_mapping(gene_indices)
        cell_index_mapping = create_node_index_mapping(cell_indices)

        # Build edge dictionary for heterogeneous graph
        edge_dict = build_edge_dictionary(
            graph,
            gene_index_mapping,
            cell_index_mapping,
            include_hierarchy_edges,
        )

        # Extract node features
        ndata = build_node_data_dictionary(
            graph,
            gene_indices,
            cell_indices,
            gene_feature_dim,
            cell_feature_dim,
        )

        # Create the GNNHeteroGraph
        gnn_graph = GNNHeteroGraph(edge_dict; ndata)

        @debug "Built GNN hetero graph" gene_nodes = length(gene_indices) cell_nodes =
            length(cell_indices) edge_types = length(edge_dict)

        return gnn_graph

    catch e
        if isa(e, GraphConstructionError)
            rethrow(e)
        else
            throw(
                GraphConstructionError(
                    "Failed to build GNN hetero graph from ontology tree",
                    "graph_construction",
                    "OntologyTree with $(nv(ontology_tree.graph)) nodes",
                    "Unknown",
                    e,
                ),
            )
        end
    end
end

"""
    extract_node_indices_by_type(graph::MetaGraphs.MetaDiGraph)::Tuple{Vector{Int},Vector{Int}}

Extract node indices separated by type (gene vs cell type).

# Arguments
- `graph::MetaGraphs.MetaDiGraph`: Ontology graph

# Returns
- `Tuple{Vector{Int},Vector{Int}}`: (gene_indices, cell_indices)
"""
function extract_node_indices_by_type(
    graph::MetaGraphs.MetaDiGraph,
)::Tuple{Vector{Int}, Vector{Int}}
    gene_indices = Int[]
    cell_indices = Int[]

    for (vertex_id, vertex_props) in graph.vprops
        node_type = get(vertex_props, :type, :unknown)

        if node_type == :gene || haskey(vertex_props, :gene_id)
            push!(gene_indices, vertex_id)
        elseif node_type == :term || haskey(vertex_props, :term)
            push!(cell_indices, vertex_id)
        else
            @warn "Unknown node type for vertex $vertex_id: $node_type"
        end
    end

    return gene_indices, cell_indices
end

"""
    create_node_index_mapping(original_indices::Vector{Int})::Dict{Int,Int}

Create mapping from original graph indices to GNN graph indices.

# Arguments
- `original_indices::Vector{Int}`: Original node indices

# Returns
- `Dict{Int,Int}`: Mapping from original to new indices (1-based)
"""
function create_node_index_mapping(original_indices::Vector{Int})::Dict{Int, Int}
    return Dict(original_indices[i] => i for i in eachindex(original_indices))
end

"""
    build_edge_dictionary(graph::MetaGraphs.MetaDiGraph,
                          gene_mapping::Dict{Int,Int},
                          cell_mapping::Dict{Int,Int},
                          include_hierarchy::Bool)::Dict{NTuple{3,Symbol},Tuple{Vector{Int},Vector{Int}}}

Build edge dictionary for GNNHeteroGraph from ontology graph edges.

# Arguments
- `graph::MetaGraphs.MetaDiGraph`: Source ontology graph
- `gene_mapping::Dict{Int,Int}`: Gene index mapping
- `cell_mapping::Dict{Int,Int}`: Cell index mapping
- `include_hierarchy::Bool`: Whether to include hierarchy edges

# Returns
- Edge dictionary mapping edge types to source/destination vectors
"""
function build_edge_dictionary(
    graph::MetaGraphs.MetaDiGraph,
    gene_mapping::Dict{Int, Int},
    cell_mapping::Dict{Int, Int},
    include_hierarchy::Bool,
)::Dict{NTuple{3, Symbol}, Tuple{Vector{Int}, Vector{Int}}}
    edge_dict = Dict{NTuple{3, Symbol}, Tuple{Vector{Int}, Vector{Int}}}()

    for edge in edges(graph)
        src_vertex = src(edge)
        dst_vertex = dst(edge)

        # Determine node types
        src_props = get(graph.vprops, src_vertex, Dict())
        dst_props = get(graph.vprops, dst_vertex, Dict())

        src_type = determine_node_type(src_props)
        dst_type = determine_node_type(dst_props)

        # Skip hierarchy edges if not requested
        if !include_hierarchy && src_type == :cell && dst_type == :cell
            continue
        end

        # Get mapped indices
        src_index = get_mapped_index(src_vertex, src_type, gene_mapping, cell_mapping)
        dst_index = get_mapped_index(dst_vertex, dst_type, gene_mapping, cell_mapping)

        if src_index === nothing || dst_index === nothing
            @warn "Could not map edge indices" src_vertex = src_vertex dst_vertex =
                dst_vertex
            continue
        end

        # Create edge type tuple
        edge_type = (src_type, :to, dst_type)

        # Add edge to dictionary
        if haskey(edge_dict, edge_type)
            push!(edge_dict[edge_type][1], src_index)
            push!(edge_dict[edge_type][2], dst_index)
        else
            edge_dict[edge_type] = ([src_index], [dst_index])
        end
    end

    return edge_dict
end

"""
    determine_node_type(vertex_props::Dict)::Symbol

Determine node type from vertex properties.

# Arguments
- `vertex_props::Dict`: Vertex properties dictionary

# Returns
- `Symbol`: Node type (:gene or :cell)
"""
function determine_node_type(vertex_props::Dict)::Symbol
    if haskey(vertex_props, :gene_id) || get(vertex_props, :type, :unknown) == :gene
        return :gene
    elseif haskey(vertex_props, :term) || get(vertex_props, :type, :unknown) == :term
        return :cell
    else
        @warn "Could not determine node type from properties: $vertex_props"
        return :unknown
    end
end

"""
    get_mapped_index(vertex_id::Int, node_type::Symbol, 
                     gene_mapping::Dict{Int,Int}, 
                     cell_mapping::Dict{Int,Int})::Union{Int,Nothing}

Get the mapped index for a vertex based on its type.

# Arguments
- `vertex_id::Int`: Original vertex ID
- `node_type::Symbol`: Node type (:gene or :cell)
- `gene_mapping::Dict{Int,Int}`: Gene index mapping
- `cell_mapping::Dict{Int,Int}`: Cell index mapping

# Returns
- `Union{Int,Nothing}`: Mapped index or nothing if not found
"""
function get_mapped_index(
    vertex_id::Int,
    node_type::Symbol,
    gene_mapping::Dict{Int, Int},
    cell_mapping::Dict{Int, Int},
)::Union{Int, Nothing}
    if node_type == :gene
        return get(gene_mapping, vertex_id, nothing)
    elseif node_type == :cell
        return get(cell_mapping, vertex_id, nothing)
    else
        return nothing
    end
end

"""
    build_node_data_dictionary(graph::MetaGraphs.MetaDiGraph,
                               gene_indices::Vector{Int},
                               cell_indices::Vector{Int},
                               gene_feature_dim::Union{Int,Nothing},
                               cell_feature_dim::Union{Int,Nothing})::Dict{Symbol,DataStore}

Build node data dictionary for GNNHeteroGraph.

# Arguments
- `graph::MetaGraphs.MetaDiGraph`: Source ontology graph
- `gene_indices::Vector{Int}`: Gene node indices
- `cell_indices::Vector{Int}`: Cell node indices  
- `gene_feature_dim::Union{Int,Nothing}`: Gene feature dimension
- `cell_feature_dim::Union{Int,Nothing}`: Cell feature dimension

# Returns
- `Dict{Symbol,DataStore}`: Node data dictionary for GNN graph
"""
function build_node_data_dictionary(
    graph::MetaGraphs.MetaDiGraph,
    gene_indices::Vector{Int},
    cell_indices::Vector{Int},
    gene_feature_dim::Union{Int, Nothing},
    cell_feature_dim::Union{Int, Nothing},
)::Dict{Symbol, DataStore}
    ndata = Dict{Symbol, DataStore}()

    # Build gene node data
    if !isempty(gene_indices)
        gene_features = extract_gene_features(graph, gene_indices, gene_feature_dim)
        ndata[:gene] = DataStore(; x = gene_features)
    end

    # Build cell node data
    if !isempty(cell_indices)
        cell_features = extract_cell_features(graph, cell_indices, cell_feature_dim)
        ndata[:cell] = DataStore(; x = cell_features)
    end

    return ndata
end

"""
    extract_gene_features(graph::MetaGraphs.MetaDiGraph, 
                          gene_indices::Vector{Int},
                          feature_dim::Union{Int,Nothing})::Matrix{Float32}

Extract feature matrix for gene nodes.

# Arguments
- `graph::MetaGraphs.MetaDiGraph`: Source graph
- `gene_indices::Vector{Int}`: Gene node indices
- `feature_dim::Union{Int,Nothing}`: Feature dimension

# Returns
- `Matrix{Float32}`: Gene feature matrix (features × nodes)
"""
function extract_gene_features(
    graph::MetaGraphs.MetaDiGraph,
    gene_indices::Vector{Int},
    feature_dim::Union{Int, Nothing},
)::Matrix{Float32}

    # Extract expression values if available
    expressions = Float32[]
    for gene_idx in gene_indices
        gene_props = get(graph.vprops, gene_idx, Dict())
        expr_val = get(gene_props, :expression, missing)

        if ismissing(expr_val)
            push!(expressions, 0.0f0)  # Default to zero
        else
            push!(expressions, Float32(expr_val))
        end
    end

    # If no feature dimension specified, use single expression feature
    if feature_dim === nothing
        return reshape(expressions, 1, :)  # 1 × n_genes
    else
        # Create feature matrix with specified dimensions
        n_genes = length(gene_indices)
        features = zeros(Float32, feature_dim, n_genes)

        # Fill first dimension with expression values
        if feature_dim >= 1
            features[1, :] = expressions
        end

        # Fill remaining dimensions with random features (placeholder)
        if feature_dim > 1
            for i in 2:feature_dim
                features[i, :] = randn(Float32, n_genes) * 0.1f0
            end
        end

        return features
    end
end

"""
    extract_cell_features(graph::MetaGraphs.MetaDiGraph,
                          cell_indices::Vector{Int},
                          feature_dim::Union{Int,Nothing})::Matrix{Float32}

Extract feature matrix for cell type nodes.

# Arguments
- `graph::MetaGraphs.MetaDiGraph`: Source graph
- `cell_indices::Vector{Int}`: Cell node indices
- `feature_dim::Union{Int,Nothing}`: Feature dimension

# Returns
- `Matrix{Float32}`: Cell feature matrix (features × nodes)
"""
function extract_cell_features(
    graph::MetaGraphs.MetaDiGraph,
    cell_indices::Vector{Int},
    feature_dim::Union{Int, Nothing},
)::Matrix{Float32}

    # Extract proportion values if available
    proportions = Float32[]
    for cell_idx in cell_indices
        cell_props = get(graph.vprops, cell_idx, Dict())
        prop_val = get(cell_props, :proportion, missing)

        if ismissing(prop_val)
            push!(proportions, 0.0f0)  # Default to zero
        else
            push!(proportions, Float32(prop_val))
        end
    end

    # If no feature dimension specified, use single proportion feature
    if feature_dim === nothing
        return reshape(proportions, 1, :)  # 1 × n_cells
    else
        # Create feature matrix with specified dimensions
        n_cells = length(cell_indices)
        features = zeros(Float32, feature_dim, n_cells)

        # Fill first dimension with proportion values
        if feature_dim >= 1
            features[1, :] = proportions
        end

        # Fill remaining dimensions with identity encoding (one-hot style)
        if feature_dim > 1 && n_cells <= feature_dim - 1
            for (i, cell_idx) in enumerate(cell_indices)
                if i + 1 <= feature_dim
                    features[i + 1, i] = 1.0f0
                end
            end
        end

        return features
    end
end

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

"""
    validate_ontology_for_gnn_conversion(ontology_tree::OntologyTree)

Validate that an ontology tree is suitable for GNN conversion.

# Arguments
- `ontology_tree::OntologyTree`: Tree to validate

# Throws
- `OntologyTreeInvalidError`: If tree is not suitable for conversion
"""
function validate_ontology_for_gnn_conversion(ontology_tree::OntologyTree)
    graph = ontology_tree.graph

    # Basic validation
    if nv(graph) == 0
        throw(
            OntologyTreeInvalidError(
                "Cannot convert empty ontology tree to GNN graph",
                "empty_tree",
                Dict{String, Any}("vertex_count" => 0),
                ["non-empty ontology tree"],
            ),
        )
    end

    # Check for required node types
    gene_count = 0
    cell_count = 0

    for (vertex_id, vertex_props) in graph.vprops
        node_type = get(vertex_props, :type, :unknown)
        if node_type == :gene || haskey(vertex_props, :gene_id)
            gene_count += 1
        elseif node_type == :term || haskey(vertex_props, :term)
            cell_count += 1
        end
    end

    if gene_count == 0 && cell_count == 0
        throw(
            OntologyTreeInvalidError(
                "Ontology tree contains no recognizable gene or cell type nodes",
                "no_valid_nodes",
                Dict{String, Any}(
                    "vertex_count" => nv(graph),
                    "gene_count" => gene_count,
                    "cell_count" => cell_count,
                ),
                [
                    "gene nodes with :gene_id property",
                    "cell type nodes with :term property",
                ],
            ),
        )
    end

    @debug "Ontology tree validation for GNN conversion passed" gene_count = gene_count cell_count =
        cell_count
end

"""
    validate_gnn_graph_structure(gnn_graph::GNNHeteroGraph)

Validate that a GNN graph has the expected structure.

# Arguments
- `gnn_graph::GNNHeteroGraph`: Graph to validate

# Throws
- `GraphConstructionError`: If graph structure is invalid
"""
function validate_gnn_graph_structure(gnn_graph::GNNHeteroGraph)
    # Check that graph has expected node types
    node_types = gnn_graph.ndata.keys

    if isempty(node_types)
        throw(
            GraphConstructionError(
                "GNN graph has no node types",
                "validation",
                "GNNHeteroGraph",
                "Empty node data",
                nothing,
            ),
        )
    end

    # Check for expected edge types
    edge_types = keys(gnn_graph.graph)

    if isempty(edge_types)
        @warn "GNN graph has no edges - this may indicate a problem"
    end

    @debug "GNN graph validation passed" node_types = collect(node_types) edge_type_count =
        length(edge_types)
end
