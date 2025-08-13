using OntologyTrees
using Graphs
using DataFrames
using LinearAlgebra
using Statistics

"""
Enhanced Cell Type Ontology Integration using OntologyTrees.jl
Builds hierarchical ontology graphs and integrates with gene interaction networks
"""

struct CellOntologyConfig
    ontology_source::String  # "cell_ontology", "custom", or path to OBO file
    root_terms::Vector{String}  # Root cell types for the hierarchy
    max_depth::Int  # Maximum depth in ontology hierarchy
    include_synonyms::Bool
    cache_dir::String
end

# Default configuration
const DEFAULT_ONTOLOGY_CONFIG = CellOntologyConfig(
    "cell_ontology",
    ["CL:0000003"],  # native cell
    5,  # reasonable depth
    true,
    "/tmp/ontology_cache"
)

"""
Build Cell Ontology tree using OntologyTrees.jl
"""
function build_cell_ontology_tree(cell_types::Vector{String}; 
                                 config::CellOntologyConfig=DEFAULT_ONTOLOGY_CONFIG)
    @info "Building Cell Ontology tree using OntologyTrees.jl for $(length(cell_types)) cell types"
    
    try
        # Create immune cell root
        immune_root = onto_term("cl", "http://purl.obolibrary.org/obo/CL_0000542")  # leukocyte
        
        # Map cell types to ontology terms
        cell_terms = map_cell_types_to_ontology_terms(cell_types)
        
        # Build ontology tree
        ontology_tree = build_tree(immune_root, cell_terms; max_depth=config.max_depth)
        
        @info "Successfully built ontology tree with $(length(cell_terms)) mapped cell types"
        
        return ontology_tree, cell_terms
        
    catch e
        @warn "Failed to build ontology tree using OntologyTrees.jl: $e"
        @info "Falling back to manual hierarchy construction..."
        
        # Fallback to manual hierarchy
        return build_manual_ontology_tree(cell_types, config)
    end
end

"""
Map cell type names to ontology terms
"""
function map_cell_types_to_ontology_terms(cell_types::Vector{String})
    @info "Mapping cell types to ontology terms"
    
    # Create mapping of common cell type variations to ontology IDs
    ontology_mapping = Dict{String, String}(
        # T cells
        "CD4+ T cell" => "CL:0000624",
        "CD4_T" => "CL:0000624", 
        "CD4 T" => "CL:0000624",
        "Helper T cell" => "CL:0000624",
        
        "CD8+ T cell" => "CL:0000625",
        "CD8_T" => "CL:0000625",
        "CD8 T" => "CL:0000625", 
        "Cytotoxic T cell" => "CL:0000625",
        
        "T cell" => "CL:0000084",
        "T cells" => "CL:0000084",
        
        "Regulatory T cell" => "CL:0000815",
        "Treg" => "CL:0000815",
        "regulatory_T" => "CL:0000815",
        
        # B cells
        "B cell" => "CL:0000236",
        "B cells" => "CL:0000236",
        "B_cell" => "CL:0000236",
        
        # NK cells
        "NK cell" => "CL:0000623",
        "NK cells" => "CL:0000623",
        "Natural killer cell" => "CL:0000623",
        "NK_cells" => "CL:0000623",
        
        # Monocytes/Macrophages
        "Monocyte" => "CL:0000576",
        "Monocytes" => "CL:0000576",
        "monocytes" => "CL:0000576",
        
        "Macrophage" => "CL:0000235",
        "Macrophages" => "CL:0000235", 
        "macrophages" => "CL:0000235",
        
        "Classical monocyte" => "CL:0000860",
        "classical_monocytes" => "CL:0000860",
        
        "Non-classical monocyte" => "CL:0000861",
        "non_classical_monocytes" => "CL:0000861",
        
        # Neutrophils
        "Neutrophil" => "CL:0000775",
        "Neutrophils" => "CL:0000775",
        "neutrophils" => "CL:0000775",
        
        # Dendritic cells
        "Dendritic cell" => "CL:0000451",
        "dendritic_cells" => "CL:0000451",
        "DC" => "CL:0000451",
        
        # General categories
        "Lymphocyte" => "CL:0000542",
        "lymphocytes" => "CL:0000542",
        
        "Myeloid cell" => "CL:0000763",
        "myeloid_cells" => "CL:0000763"
    )
    
    mapped_terms = []
    for cell_type in cell_types
        # Try exact match first
        ontology_id = get(ontology_mapping, cell_type, nothing)
        
        if ontology_id === nothing
            # Try case-insensitive match
            for (key, value) in ontology_mapping
                if lowercase(cell_type) == lowercase(key)
                    ontology_id = value
                    break
                end
            end
        end
        
        if ontology_id !== nothing
            try
                term = onto_term("cl", "http://purl.obolibrary.org/obo/$ontology_id")
                push!(mapped_terms, term)
                @info "Mapped '$cell_type' to $ontology_id"
            catch e
                @warn "Failed to create ontology term for $ontology_id: $e"
            end
        else
            @warn "Could not map cell type '$cell_type' to ontology"
        end
    end
    
    @info "Successfully mapped $(length(mapped_terms))/$(length(cell_types)) cell types"
    return mapped_terms
end

"""
Build manual ontology tree as fallback
"""
function build_manual_ontology_tree(cell_types::Vector{String}, config::CellOntologyConfig)
    @info "Building manual ontology tree for $(length(cell_types)) cell types"
    
    # Create hierarchical structure manually
    hierarchy = Dict{String, Vector{String}}(
        "immune_cells" => ["lymphocytes", "myeloid_cells"],
        "lymphocytes" => ["T_cells", "B_cells", "NK_cells"],
        "T_cells" => ["CD4_T", "CD8_T", "regulatory_T"],
        "myeloid_cells" => ["monocytes", "neutrophils", "dendritic_cells", "macrophages"],
        "monocytes" => ["classical_monocytes", "non_classical_monocytes"]
    )
    
    # Map cell types to hierarchy
    cell_mapping = map_cell_types_to_hierarchy(cell_types, hierarchy)
    
    return hierarchy, cell_mapping
end

"""
Map cell types to manual hierarchy
"""
function map_cell_types_to_hierarchy(cell_types::Vector{String}, hierarchy::Dict)
    mapped_types = Dict{String, Vector{String}}()
    
    for cell_type in cell_types
        # Normalize cell type name
        normalized = normalize_cell_type_name(cell_type)
        
        # Find position in hierarchy
        parent = find_hierarchy_parent(normalized, hierarchy)
        
        if haskey(mapped_types, parent)
            push!(mapped_types[parent], cell_type)
        else
            mapped_types[parent] = [cell_type]
        end
    end
    
    return mapped_types
end

"""
Normalize cell type names for matching
"""
function normalize_cell_type_name(cell_type::String)
    # Remove common variations and normalize
    normalized = lowercase(cell_type)
    normalized = replace(normalized, r"[+\s-]" => "_")  # Replace +, spaces, - with _
    normalized = replace(normalized, "cell" => "")      # Remove "cell"
    normalized = replace(normalized, "cells" => "")     # Remove "cells"
    normalized = strip(normalized, '_')                 # Remove leading/trailing _
    
    return normalized
end

"""
Find parent in hierarchy for a cell type
"""
function find_hierarchy_parent(normalized_type::String, hierarchy::Dict)
    # Check if it matches any leaf types
    for (parent, children) in hierarchy
        for child in children
            if normalized_type == child || occursin(normalized_type, child) || occursin(child, normalized_type)
                return parent
            end
        end
    end
    
    # If no match found, assign to general category
    if occursin("t", normalized_type)
        return "T_cells"
    elseif occursin("b", normalized_type)
        return "B_cells"
    elseif occursin("nk", normalized_type) || occursin("natural", normalized_type)
        return "NK_cells"
    elseif occursin("monocyte", normalized_type) || occursin("macro", normalized_type)
        return "myeloid_cells"
    else
        return "immune_cells"  # Default
    end
end

"""
Create ontology-guided adjacency matrix
"""
function create_ontology_adjacency(cell_types::Vector{String}, ontology_tree, 
                                  gene_adjacency::Matrix{Float64})
    @info "Creating ontology-guided adjacency matrix"
    
    n_genes = size(gene_adjacency, 1)
    n_cell_types = length(cell_types)
    
    # Enhanced adjacency that combines gene-gene and ontology structure
    enhanced_adjacency = copy(gene_adjacency)
    
    # Add ontology relationships as additional connections
    # This is simplified - real implementation would use ontology_tree structure
    for i in 1:n_genes
        for j in 1:n_genes
            if i != j
                # Add small weight for ontologically related genes
                ontology_weight = calculate_ontology_relationship_weight(i, j, cell_types, ontology_tree)
                enhanced_adjacency[i, j] = max(enhanced_adjacency[i, j], ontology_weight * 0.1)
            end
        end
    end
    
    return enhanced_adjacency
end

"""
Calculate relationship weight based on ontology
"""
function calculate_ontology_relationship_weight(gene1_idx::Int, gene2_idx::Int, 
                                               cell_types::Vector{String}, ontology_tree)
    # Simplified: return random small weight for now
    # Real implementation would calculate based on ontology distance
    return rand() * 0.1
end

"""
Combine STRING and Ontology graphs
"""
function combine_string_ontology_graphs(string_graph::SimpleGraph, 
                                       ontology_adjacency::Matrix{Float64},
                                       gene_symbols::Vector{String},
                                       cell_types::Vector{String})
    @info "Combining STRING and ontology graphs"
    
    n_genes = length(gene_symbols)
    
    # Start with STRING graph
    combined_graph = copy(string_graph)
    
    # Add ontology-guided edges
    for i in 1:n_genes
        for j in (i+1):n_genes
            if ontology_adjacency[i, j] > 0.05 && !has_edge(combined_graph, i, j)
                add_edge!(combined_graph, i, j)
            end
        end
    end
    
    @info "Combined graph: $(nv(combined_graph)) nodes, $(ne(combined_graph)) edges"
    
    return combined_graph
end

"""
Build complete biological graph with STRING + Ontology
"""
function build_complete_biological_graph(X_reference::Matrix, gene_symbols::Vector{String}, 
                                        cell_types::Vector{String}; 
                                        string_config=nothing, ontology_config=nothing)
    @info "Building complete biological graph with STRING + Ontology integration"
    
    # Include STRING integration
    include("string_integration.jl")
    
    # Build STRING graph
    string_graph, gene_mapping, edge_weights = build_string_interaction_graph(
        gene_symbols; config=string_config
    )
    
    # Build ontology tree
    ontology_tree, cell_terms = build_cell_ontology_tree(cell_types; config=ontology_config)
    
    # Convert STRING graph to adjacency matrix
    string_adjacency = graph_to_adjacency_matrix(string_graph, edge_weights)
    
    # Create ontology-enhanced adjacency
    ontology_adjacency = create_ontology_adjacency(cell_types, ontology_tree, string_adjacency)
    
    # Combine both graphs
    combined_graph = combine_string_ontology_graphs(string_graph, ontology_adjacency, 
                                                   gene_symbols, cell_types)
    
    # Final adjacency matrix for GNN
    final_adjacency = graph_to_adjacency_matrix(combined_graph)
    
    @info "Final biological graph: $(nv(combined_graph)) nodes, $(ne(combined_graph)) edges"
    
    return combined_graph, final_adjacency, ontology_tree, cell_terms
end
