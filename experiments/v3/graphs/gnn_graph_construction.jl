using GraphNeuralNetworks
using Graphs
using OntologyTrees
using STRINGdb
using Statistics
using LinearAlgebra
using SparseArrays

"""
Comprehensive GNNGraph Construction from OntologyTrees and STRING-db
Creates heterogeneous graphs for biological cell type deconvolution
"""

"""
Create GNNHeteroGraph from OntologyTree with multi-dimensional features
"""
function ontology_tree_to_gnn_graph(onto_tree::OntologyTree, 
                                    X_reference::Matrix{Float64}, 
                                    gene_symbols::Vector{String},
                                    cell_proportions::Matrix{Float64},
                                    cell_types::Vector{String};
                                    include_string_edges::Bool=true,
                                    include_hierarchy_edges::Bool=true)
    
    @info "Converting OntologyTree to GNNHeteroGraph"
    @info "Genes: $(length(gene_symbols)), Cells: $(length(cell_types))"
    
    # Get gene-term connections from ontology tree
    gene_term_connections = extract_gene_term_connections(onto_tree)
    
    # Create multi-dimensional gene features
    gene_features = create_gene_features(X_reference, gene_symbols, onto_tree)
    
    # Create multi-dimensional cell features with hierarchy information
    cell_features = create_cell_features(cell_proportions, cell_types, onto_tree)
    
    # Build edge structures
    edges = Dict{Tuple{Symbol,Symbol,Symbol}, Tuple{Vector{Int}, Vector{Int}}}()
    
    # 1. Gene-Cell connections from ontology
    gene_cell_edges = create_gene_cell_edges(gene_term_connections, gene_symbols, cell_types)
    if !isempty(gene_cell_edges[1])
        edges[(:gene, :expresses, :cell)] = gene_cell_edges
    end
    
    # 2. Cell-Cell hierarchical relationships
    if include_hierarchy_edges
        cell_hierarchy_edges = create_cell_hierarchy_edges(cell_types, onto_tree)
        if !isempty(cell_hierarchy_edges[1])
            edges[(:cell, :is_parent_of, :cell)] = cell_hierarchy_edges
        end
    end
    
    # 3. Gene-Gene STRING-db interactions
    if include_string_edges
        gene_gene_edges = create_gene_gene_string_edges(gene_symbols)
        if !isempty(gene_gene_edges[1])
            edges[(:gene, :interacts_with, :gene)] = gene_gene_edges
        end
    end
    
    # Create node feature dictionary
    node_features = Dict{Symbol, Matrix{Float32}}(
        :gene => Float32.(gene_features),
        :cell => Float32.(cell_features)
    )
    
    # Create the heterogeneous graph
    gnn_graph = GNNHeteroGraph(node_features, edges)
    
    @info "Created GNNHeteroGraph with $(length(node_features)) node types and $(length(edges)) edge types"
    
    return gnn_graph, gene_term_connections
end

"""
Extract gene-term connections from OntologyTree
"""
function extract_gene_term_connections(onto_tree::OntologyTree)
    @info "Extracting gene-term connections from OntologyTree"
    
    connections = Dict{String, Vector{String}}()  # gene -> [terms]
    
    # Get the graph from ontology tree
    onto_graph = graph(onto_tree)
    
    # Iterate through all nodes to find gene associations
    for vertex in vertices(onto_graph)
        # Get the term associated with this vertex
        # Note: This depends on the internal structure of OntologyTree
        # You may need to adjust based on actual API
        try
            # Get genes associated with this term
            # This is a placeholder - adjust based on actual OntologyTree API
            term_genes = get_genes_for_term(onto_tree, vertex)
            
            for gene in term_genes
                if haskey(connections, gene)
                    push!(connections[gene], string(vertex))
                else
                    connections[gene] = [string(vertex)]
                end
            end
        catch e
            # Skip if no genes associated
            continue
        end
    end
    
    @info "Found connections for $(length(connections)) genes"
    return connections
end

"""
Create multi-dimensional gene features
"""
function create_gene_features(X_reference::Matrix{Float64}, 
                             gene_symbols::Vector{String}, 
                             onto_tree::OntologyTree)
    @info "Creating multi-dimensional gene features"
    
    n_genes = length(gene_symbols)
    n_samples = size(X_reference, 2)
    
    # Base features: expression statistics
    mean_expr = vec(mean(X_reference, dims=2))
    std_expr = vec(std(X_reference, dims=2))
    max_expr = vec(maximum(X_reference, dims=2))
    
    # Normalize expression values
    log_mean_expr = log2.(mean_expr .+ 1.0)
    cv_expr = std_expr ./ (mean_expr .+ 1e-8)  # Coefficient of variation
    
    # Ontology-based features
    ontology_depth = calculate_gene_ontology_depth(gene_symbols, onto_tree)
    ontology_connectivity = calculate_gene_ontology_connectivity(gene_symbols, onto_tree)
    
    # Network topology features (if available)
    network_centrality = calculate_gene_network_centrality(gene_symbols)
    
    # Combine all features
    features = hcat(
        log_mean_expr,           # Log-transformed mean expression
        std_expr,                # Expression variability
        cv_expr,                 # Coefficient of variation
        ontology_depth,          # Depth in ontology hierarchy
        ontology_connectivity,   # Number of ontology connections
        network_centrality       # Network centrality measures
    )
    
    @info "Created gene features: $(size(features)) (genes × features)"
    return features
end

"""
Create multi-dimensional cell features with hierarchy information
"""
function create_cell_features(cell_proportions::Matrix{Float64}, 
                             cell_types::Vector{String}, 
                             onto_tree::OntologyTree)
    @info "Creating multi-dimensional cell features"
    
    n_cells = length(cell_types)
    n_samples = size(cell_proportions, 2)
    
    # Base features: proportion statistics
    mean_prop = vec(mean(cell_proportions, dims=2))
    std_prop = vec(std(cell_proportions, dims=2))
    
    # Handle missing values
    mean_prop = replace(mean_prop, NaN => 0.0)
    std_prop = replace(std_prop, NaN => 0.0)
    
    # Ontology hierarchy features
    hierarchy_depth = calculate_cell_hierarchy_depth(cell_types, onto_tree)
    hierarchy_level = calculate_cell_hierarchy_level(cell_types, onto_tree)
    parent_connectivity = calculate_cell_parent_connectivity(cell_types, onto_tree)
    
    # Biological category encoding
    cell_category = encode_cell_categories(cell_types)
    
    # Combine all features
    features = hcat(
        mean_prop,              # Mean proportion across samples
        std_prop,               # Proportion variability
        hierarchy_depth,        # Depth in cell ontology
        hierarchy_level,        # Level in hierarchy (0=root, 1=child, etc.)
        parent_connectivity,    # Number of parent relationships
        cell_category           # Encoded biological category
    )
    
    @info "Created cell features: $(size(features)) (cells × features)"
    return features
end

"""
Create gene-cell edges based on ontology connections
"""
function create_gene_cell_edges(gene_term_connections::Dict{String, Vector{String}},
                               gene_symbols::Vector{String},
                               cell_types::Vector{String})
    @info "Creating gene-cell edges from ontology"
    
    gene_indices = Dict(gene => i for (i, gene) in enumerate(gene_symbols))
    cell_indices = Dict(cell => i for (i, cell) in enumerate(cell_types))
    
    src_nodes = Int[]
    dst_nodes = Int[]
    
    for (gene, terms) in gene_term_connections
        gene_idx = get(gene_indices, gene, nothing)
        if gene_idx === nothing
            continue
        end
        
        # Find cells associated with these terms
        for term in terms
            # Map term to cell types (this is simplified)
            associated_cells = map_term_to_cells(term, cell_types)
            
            for cell in associated_cells
                cell_idx = get(cell_indices, cell, nothing)
                if cell_idx !== nothing
                    push!(src_nodes, gene_idx)
                    push!(dst_nodes, cell_idx)
                end
            end
        end
    end
    
    @info "Created $(length(src_nodes)) gene-cell edges"
    return (src_nodes, dst_nodes)
end

"""
Create cell-cell hierarchical edges
"""
function create_cell_hierarchy_edges(cell_types::Vector{String}, onto_tree::OntologyTree)
    @info "Creating cell hierarchy edges"
    
    cell_indices = Dict(cell => i for (i, cell) in enumerate(cell_types))
    
    src_nodes = Int[]
    dst_nodes = Int[]
    
    # Create hierarchy based on ontology structure
    hierarchy_map = build_cell_hierarchy_map(cell_types, onto_tree)
    
    for (parent, children) in hierarchy_map
        parent_idx = get(cell_indices, parent, nothing)
        if parent_idx === nothing
            continue
        end
        
        for child in children
            child_idx = get(cell_indices, child, nothing)
            if child_idx !== nothing
                push!(src_nodes, parent_idx)
                push!(dst_nodes, child_idx)
            end
        end
    end
    
    @info "Created $(length(src_nodes)) cell hierarchy edges"
    return (src_nodes, dst_nodes)
end

"""
Create gene-gene STRING-db interaction edges
"""
function create_gene_gene_string_edges(gene_symbols::Vector{String})
    @info "Creating gene-gene STRING-db edges"
    
    # Use STRING-db integration
    try
        include("../graphs/string_integration.jl")
        
        # Get STRING interactions
        interactions_df = download_string_interactions(gene_symbols)
        
        if isempty(interactions_df)
            @warn "No STRING interactions found"
            return (Int[], Int[])
        end
        
        gene_indices = Dict(gene => i for (i, gene) in enumerate(gene_symbols))
        
        src_nodes = Int[]
        dst_nodes = Int[]
        
        for row in eachrow(interactions_df)
            idx1 = get(gene_indices, row.preferredName_A, nothing)
            idx2 = get(gene_indices, row.preferredName_B, nothing)
            
            if idx1 !== nothing && idx2 !== nothing && idx1 != idx2
                push!(src_nodes, idx1)
                push!(dst_nodes, idx2)
                # Add reverse edge for undirected graph
                push!(src_nodes, idx2)
                push!(dst_nodes, idx1)
            end
        end
        
        @info "Created $(length(src_nodes)) gene-gene STRING edges"
        return (src_nodes, dst_nodes)
        
    catch e
        @warn "Failed to create STRING edges: $e"
        return (Int[], Int[])
    end
end

# Helper functions for feature calculation

function calculate_gene_ontology_depth(gene_symbols::Vector{String}, onto_tree::OntologyTree)
    # Placeholder - calculate depth of gene in ontology
    return rand(Float64, length(gene_symbols))  # Replace with actual calculation
end

function calculate_gene_ontology_connectivity(gene_symbols::Vector{String}, onto_tree::OntologyTree)
    # Placeholder - calculate connectivity of gene in ontology
    return rand(Float64, length(gene_symbols))  # Replace with actual calculation
end

function calculate_gene_network_centrality(gene_symbols::Vector{String})
    # Placeholder - calculate network centrality measures
    return rand(Float64, length(gene_symbols))  # Replace with actual calculation
end

function calculate_cell_hierarchy_depth(cell_types::Vector{String}, onto_tree::OntologyTree)
    # Placeholder - calculate depth of cell type in hierarchy
    return rand(Float64, length(cell_types))  # Replace with actual calculation
end

function calculate_cell_hierarchy_level(cell_types::Vector{String}, onto_tree::OntologyTree)
    # Placeholder - calculate level of cell type in hierarchy
    return rand(Float64, length(cell_types))  # Replace with actual calculation
end

function calculate_cell_parent_connectivity(cell_types::Vector{String}, onto_tree::OntologyTree)
    # Placeholder - calculate number of parent relationships
    return rand(Float64, length(cell_types))  # Replace with actual calculation
end

function encode_cell_categories(cell_types::Vector{String})
    # Simple categorical encoding for cell types
    categories = Dict(
        "T" => 1.0, "B" => 2.0, "NK" => 3.0, 
        "monocyte" => 4.0, "neutrophil" => 5.0, "dendritic" => 6.0
    )
    
    encoded = zeros(Float64, length(cell_types))
    for (i, cell_type) in enumerate(cell_types)
        for (key, value) in categories
            if occursin(key, lowercase(cell_type))
                encoded[i] = value
                break
            end
        end
    end
    
    return encoded
end

function map_term_to_cells(term::String, cell_types::Vector{String})
    # Simplified mapping - find cells that might be associated with this term
    associated = String[]
    for cell_type in cell_types
        # Simple heuristic - improve based on actual ontology structure
        if occursin(lowercase(term), lowercase(cell_type)) || 
           occursin(lowercase(cell_type), lowercase(term))
            push!(associated, cell_type)
        end
    end
    return associated
end

function build_cell_hierarchy_map(cell_types::Vector{String}, onto_tree::OntologyTree)
    # Placeholder - build hierarchy map from ontology tree
    # This should use the actual ontology structure
    hierarchy = Dict{String, Vector{String}}()
    
    # Simple example hierarchy
    for cell_type in cell_types
        if occursin("CD4", cell_type) || occursin("CD8", cell_type)
            hierarchy["T_cells"] = get(hierarchy, "T_cells", String[])
            push!(hierarchy["T_cells"], cell_type)
        elseif occursin("B", cell_type)
            hierarchy["B_cells"] = get(hierarchy, "B_cells", String[])
            push!(hierarchy["B_cells"], cell_type)
        end
    end
    
    return hierarchy
end

function get_genes_for_term(onto_tree::OntologyTree, vertex::Int)
    # Placeholder - extract genes associated with a term
    # This depends on the actual OntologyTree API
    return String[]  # Replace with actual implementation
end
