using GraphNeuralNetworks
using Graphs
using OntologyTrees
using STRINGdb
using Statistics
using LinearAlgebra

"""
Enhanced GNN Graph Construction for V3
Integrates OntologyTrees and STRINGdb for comprehensive biological graphs
"""

"""
Convert OntologyTree to GNNHeteroGraph with multi-dimensional features
"""
function ontology_tree_to_gnn_hetero_graph(onto_tree::OntologyTree, 
                                          gene_expressions::Matrix{Float64},
                                          gene_symbols::Vector{String};
                                          include_string_edges::Bool=true,
                                          string_confidence::Float64=0.4)
    @info "Converting OntologyTree to GNNHeteroGraph with enhanced features"
    
    graph = onto_tree.graph
    
    # Extract node indices by type
    gene_indices = [v_index for (v_index, v_props) in graph.vprops if haskey(v_props, :gene_id)]
    cell_indices = [v_index for (v_index, v_props) in graph.vprops if haskey(v_props, :term)]
    
    @info "Found $(length(gene_indices)) gene nodes and $(length(cell_indices)) cell nodes"
    
    # Create mapping from original indices to new indices for each node type
    gene_mapping = Dict(gene_indices[i] => i for i in eachindex(gene_indices))
    cell_mapping = Dict(cell_indices[i] => i for i in eachindex(cell_indices))
    
    # Build edge dictionary for GNNHeteroGraph
    edge_dict = build_edge_dictionary(graph, gene_mapping, cell_mapping, 
                                    gene_symbols, include_string_edges, string_confidence)
    
    # Create multi-dimensional node features
    ndata = create_node_features(graph, gene_indices, cell_indices, 
                               gene_expressions, gene_symbols, onto_tree)
    
    # Create GNNHeteroGraph
    hetero_graph = GNNHeteroGraph(edge_dict; ndata)
    
    @info "Created GNNHeteroGraph: $(length(gene_indices)) genes, $(length(cell_indices)) cells"
    @info "Edge types: $(collect(keys(edge_dict)))"
    
    return hetero_graph
end

"""
Build comprehensive edge dictionary including ontology and STRING edges
"""
function build_edge_dictionary(graph, gene_mapping::Dict, cell_mapping::Dict,
                              gene_symbols::Vector{String}, include_string::Bool, 
                              string_confidence::Float64)
    edge_dict = Dict{NTuple{3,Symbol},Tuple{Vector{Int},Vector{Int}}}()
    
    # 1. Add ontology-based edges (gene-cell connections)
    for edge in edges(graph)
        src_idx = src(edge)
        dst_idx = dst(edge)
        
        src_type = haskey(graph.vprops[src_idx], :gene_id) ? :gene : :cell
        dst_type = haskey(graph.vprops[dst_idx], :gene_id) ? :gene : :cell
        
        src_new_idx = src_type == :gene ? gene_mapping[src_idx] : cell_mapping[src_idx]
        dst_new_idx = dst_type == :gene ? gene_mapping[dst_idx] : cell_mapping[dst_idx]
        
        edge_type = (src_type, :ontology, dst_type)
        
        if haskey(edge_dict, edge_type)
            push!(edge_dict[edge_type][1], src_new_idx)
            push!(edge_dict[edge_type][2], dst_new_idx)
        else
            edge_dict[edge_type] = ([src_new_idx], [dst_new_idx])
        end
    end
    
    # 2. Add cell-cell hierarchical relationships
    edge_dict = add_cell_hierarchy_edges(edge_dict, graph, cell_mapping)
    
    # 3. Add STRING-db gene-gene interactions
    if include_string
        edge_dict = add_string_gene_edges(edge_dict, gene_symbols, gene_mapping, string_confidence)
    end
    
    return edge_dict
end

"""
Add cell-to-cell hierarchical edges from ontology
"""
function add_cell_hierarchy_edges(edge_dict::Dict, graph, cell_mapping::Dict)
    @info "Adding cell hierarchy edges from ontology"
    
    # Find parent-child relationships between cell types
    cell_hierarchy_edges = Tuple{Int,Int}[]
    
    for (cell_idx, cell_props) in graph.vprops
        if haskey(cell_props, :term)
            term = cell_props[:term]
            
            # Find potential parent cells (simplified - in real implementation use ontology structure)
            for (other_cell_idx, other_props) in graph.vprops
                if haskey(other_props, :term) && cell_idx != other_cell_idx
                    other_term = other_props[:term]
                    
                    # Check if there's a hierarchical relationship
                    if is_hierarchical_relationship(term, other_term)
                        parent_idx = cell_mapping[other_cell_idx]
                        child_idx = cell_mapping[cell_idx]
                        push!(cell_hierarchy_edges, (parent_idx, child_idx))
                    end
                end
            end
        end
    end
    
    if !isempty(cell_hierarchy_edges)
        src_indices = [edge[1] for edge in cell_hierarchy_edges]
        dst_indices = [edge[2] for edge in cell_hierarchy_edges]
        edge_dict[(:cell, :hierarchy, :cell)] = (src_indices, dst_indices)
        @info "Added $(length(cell_hierarchy_edges)) cell hierarchy edges"
    end
    
    return edge_dict
end

"""
Add gene-gene interactions from STRING-db
"""
function add_string_gene_edges(edge_dict::Dict, gene_symbols::Vector{String}, 
                              gene_mapping::Dict, confidence_threshold::Float64)
    @info "Adding STRING-db gene-gene interactions"
    
    try
        # Get STRING interactions
        required_score = Int(confidence_threshold * 1000)
        interactions = get_interactions(gene_symbols; required_score=required_score, species=9606)
        
        # Convert to edge indices
        string_edges = Tuple{Int,Int}[]
        
        for interaction in interactions
            gene_a = interaction.protein_a
            gene_b = interaction.protein_b
            
            # Find indices in our gene list
            idx_a = findfirst(==(gene_a), gene_symbols)
            idx_b = findfirst(==(gene_b), gene_symbols)
            
            if idx_a !== nothing && idx_b !== nothing && idx_a != idx_b
                # Map to new indices
                new_idx_a = gene_mapping[idx_a]
                new_idx_b = gene_mapping[idx_b]
                push!(string_edges, (new_idx_a, new_idx_b))
            end
        end
        
        if !isempty(string_edges)
            src_indices = [edge[1] for edge in string_edges]
            dst_indices = [edge[2] for edge in string_edges]
            edge_dict[(:gene, :string, :gene)] = (src_indices, dst_indices)
            @info "Added $(length(string_edges)) STRING-db gene edges"
        end
        
    catch e
        @warn "Failed to add STRING edges: $e"
    end
    
    return edge_dict
end

"""
Create multi-dimensional node features for genes and cells
"""
function create_node_features(graph, gene_indices::Vector, cell_indices::Vector,
                            gene_expressions::Matrix{Float64}, gene_symbols::Vector{String},
                            onto_tree::OntologyTree)
    @info "Creating multi-dimensional node features"
    
    ndata = Dict{Symbol, DataStore}()
    
    # 1. Gene node features (multi-dimensional)
    gene_features = create_gene_features(graph, gene_indices, gene_expressions, gene_symbols)
    ndata[:gene] = DataStore(features=gene_features)
    
    # 2. Cell node features (with hierarchy information)
    cell_features = create_cell_features(graph, cell_indices, onto_tree)
    ndata[:cell] = DataStore(features=cell_features)
    
    @info "Created gene features: $(size(gene_features))"
    @info "Created cell features: $(size(cell_features))"
    
    return ndata
end

"""
Create enhanced gene features including expression, network properties, and biological context
"""
function create_gene_features(graph, gene_indices::Vector, gene_expressions::Matrix{Float64}, 
                            gene_symbols::Vector{String})
    n_genes = length(gene_indices)
    n_samples = size(gene_expressions, 2)
    
    # Feature dimensions:
    # 1. Log-normalized expression (n_samples)
    # 2. Expression statistics (4: mean, std, min, max)
    # 3. Network centrality (3: degree, betweenness estimate, clustering)
    # 4. Biological context (2: pathway score, ontology depth)
    
    feature_dim = n_samples + 4 + 3 + 2
    gene_features = zeros(Float32, feature_dim, n_genes)
    
    for (i, gene_idx) in enumerate(gene_indices)
        gene_props = graph.vprops[gene_idx]
        gene_id = gene_props[:gene_id]
        
        # Find gene in expression matrix
        gene_symbol_idx = findfirst(==(gene_id), gene_symbols)
        
        if gene_symbol_idx !== nothing
            expr_values = gene_expressions[gene_symbol_idx, :]
            
            # 1. Log-normalized expression values
            log_expr = log2.(expr_values .+ 1.0)
            gene_features[1:n_samples, i] = log_expr
            
            # 2. Expression statistics
            gene_features[n_samples + 1, i] = mean(log_expr)
            gene_features[n_samples + 2, i] = std(log_expr)
            gene_features[n_samples + 3, i] = minimum(log_expr)
            gene_features[n_samples + 4, i] = maximum(log_expr)
            
            # 3. Network properties (simplified)
            degree_centrality = haskey(gene_props, :expression) ? length(gene_props[:expression]) : 0.0
            gene_features[n_samples + 5, i] = Float32(degree_centrality)
            gene_features[n_samples + 6, i] = Float32(rand()) # Placeholder for betweenness
            gene_features[n_samples + 7, i] = Float32(rand()) # Placeholder for clustering
            
            # 4. Biological context (simplified)
            gene_features[n_samples + 8, i] = Float32(rand()) # Placeholder for pathway score
            gene_features[n_samples + 9, i] = Float32(1.0)    # Placeholder for ontology depth
        else
            @warn "Gene $gene_id not found in expression matrix"
            # Fill with zeros for missing genes
            gene_features[:, i] .= 0.0
        end
    end
    
    return gene_features
end

"""
Create enhanced cell features including proportions and hierarchy information
"""
function create_cell_features(graph, cell_indices::Vector, onto_tree::OntologyTree)
    n_cells = length(cell_indices)
    
    # Feature dimensions:
    # 1. Cell proportion (1)
    # 2. Hierarchy level (1)
    # 3. Number of child terms (1)
    # 4. Number of associated genes (1)
    # 5. Cell type encoding (one-hot would be too large, use index) (1)
    
    feature_dim = 5
    cell_features = zeros(Float32, feature_dim, n_cells)
    
    for (i, cell_idx) in enumerate(cell_indices)
        cell_props = graph.vprops[cell_idx]
        
        # 1. Cell proportion (handle missing values)
        proportion = haskey(cell_props, :proportion) ? cell_props[:proportion] : 0.0
        if proportion isa Missing
            proportion = 0.0
        end
        cell_features[1, i] = Float32(proportion)
        
        # 2. Hierarchy information
        if haskey(cell_props, :term)
            term = cell_props[:term]
            
            # Get hierarchy level (depth in tree)
            hierarchy_level = calculate_term_depth(term, onto_tree)
            cell_features[2, i] = Float32(hierarchy_level)
            
            # Number of child terms (connectivity)
            n_children = count_child_terms(term, onto_tree)
            cell_features[3, i] = Float32(n_children)
        else
            cell_features[2, i] = 1.0  # Default depth
            cell_features[3, i] = 0.0  # No children
        end
        
        # 4. Number of associated genes
        n_genes = haskey(cell_props, :genes) ? length(cell_props[:genes]) : 0
        cell_features[4, i] = Float32(n_genes)
        
        # 5. Cell type index (simple encoding)
        cell_features[5, i] = Float32(i)  # Use position as identifier
    end
    
    return cell_features
end

"""
Helper functions for ontology analysis
"""
function is_hierarchical_relationship(term1, term2)
    # Simplified check - in real implementation, use ontology structure
    return false  # Placeholder
end

function calculate_term_depth(term, onto_tree::OntologyTree)
    # Calculate depth of term in ontology tree
    # Simplified implementation
    return 1.0  # Placeholder
end

function count_child_terms(term, onto_tree::OntologyTree)
    # Count number of child terms
    # Simplified implementation
    return 0  # Placeholder
end

"""
Convert GNNHeteroGraph to format compatible with new GNN architecture
"""
function prepare_gnn_input(hetero_graph::GNNHeteroGraph, batch_size::Int=1)
    @info "Preparing GNNHeteroGraph for neural network input"
    
    # Extract node features
    gene_features = hetero_graph.ndata[:gene].features
    cell_features = hetero_graph.ndata[:cell].features
    
    # For the new GNN architecture, we might need to combine or process features
    # This depends on the specific GNN implementation
    
    return hetero_graph, gene_features, cell_features
end

"""
Batch processing function for multiple ontology trees
"""
function batch_ontology_trees_to_gnn(onto_trees::Vector{OntologyTree}, 
                                   gene_expressions_batch::Vector{Matrix{Float64}},
                                   gene_symbols::Vector{String};
                                   include_string_edges::Bool=true)
    @info "Batch processing $(length(onto_trees)) ontology trees to GNNHeteroGraphs"
    
    hetero_graphs = GNNHeteroGraph[]
    
    for (i, onto_tree) in enumerate(onto_trees)
        @info "Processing ontology tree $i/$(length(onto_trees))"
        
        gene_expressions = gene_expressions_batch[i]
        hetero_graph = ontology_tree_to_gnn_hetero_graph(
            onto_tree, gene_expressions, gene_symbols; 
            include_string_edges=include_string_edges
        )
        
        push!(hetero_graphs, hetero_graph)
    end
    
    @info "Completed batch processing of $(length(hetero_graphs)) GNNHeteroGraphs"
    return hetero_graphs
end
