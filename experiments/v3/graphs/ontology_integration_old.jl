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
        @info "Downloading from $url"
        response = HTTP.get(url)
        
        if response.status == 200
            open(cache_file, "w") do io
                write(io, response.body)
            end
            @info "Downloaded and cached Cell Ontology"
            return cache_file
        else
            error("Failed to download ontology: HTTP $(response.status)")
        end
    catch e
        @error "Failed to download Cell Ontology: $e"
        return nothing
    end
end

"""
Parse OBO format ontology file
"""
function parse_obo_ontology(obo_file::String)
    @info "Parsing OBO ontology file: $obo_file"
    
    terms = Dict{String, Dict{String, Any}}()
    relationships = Vector{Tuple{String, String, String}}()  # (child, parent, relation_type)
    
    open(obo_file, "r") do io
        current_term = nothing
        in_term_block = false
        
        for line in eachline(io)
            line = strip(line)
            
            if line == "[Term]"
                in_term_block = true
                current_term = Dict{String, Any}()
                continue
            elseif startswith(line, "[") && line != "[Term]"
                # End of term block
                if in_term_block && current_term !== nothing && haskey(current_term, "id")
                    terms[current_term["id"]] = current_term
                end
                in_term_block = false
                current_term = nothing
                continue
            end
            
            if in_term_block && current_term !== nothing && occursin(":", line)
                parts = split(line, ":", 2)
                if length(parts) == 2
                    key = strip(parts[1])
                    value = strip(parts[2])
                    
                    if key == "id"
                        current_term["id"] = value
                    elseif key == "name"
                        current_term["name"] = value
                    elseif key == "is_a"
                        # Parse parent relationship
                        parent_id = strip(split(value, "!")[1])
                        push!(relationships, (current_term["id"], parent_id, "is_a"))
                    elseif key == "relationship"
                        # Parse other relationships
                        rel_parts = split(value, " ", 2)
                        if length(rel_parts) >= 2
                            rel_type = strip(rel_parts[1])
                            parent_id = strip(split(rel_parts[2], "!")[1])
                            push!(relationships, (current_term["id"], parent_id, rel_type))
                        end
                    elseif key == "synonym" && haskey(current_term, "synonyms")
                        if !haskey(current_term, "synonyms")
                            current_term["synonyms"] = String[]
                        end
                        # Parse synonym (simple extraction)
                        if occursin("\"", value)
                            synonym = match(r"\"([^\"]+)\"", value)
                            if synonym !== nothing
                                push!(current_term["synonyms"], synonym.captures[1])
                            end
                        end
                    end
                end
            end
        end
        
        # Don't forget the last term
        if in_term_block && current_term !== nothing && haskey(current_term, "id")
            terms[current_term["id"]] = current_term
        end
    end
    
    @info "Parsed $(length(terms)) terms and $(length(relationships)) relationships"
    return terms, relationships
end

"""
Build ontology graph from parsed terms and relationships
"""
function build_ontology_graph(terms::Dict{String, Dict{String, Any}}, 
                            relationships::Vector{Tuple{String, String, String}};
                            config::CellOntologyConfig=DEFAULT_ONTOLOGY_CONFIG)
    @info "Building ontology graph"
    
    # Create mapping from term ID to index
    term_ids = collect(keys(terms))
    term_to_index = Dict(term_id => i for (i, term_id) in enumerate(term_ids))
    
    # Create graph
    n_terms = length(term_ids)
    graph = SimpleDiGraph(n_terms)  # Directed graph for hierarchy
    
    edges_added = 0
    for (child_id, parent_id, rel_type) in relationships
        if haskey(term_to_index, child_id) && haskey(term_to_index, parent_id)
            child_idx = term_to_index[child_id]
            parent_idx = term_to_index[parent_id]
            
            # Add edge from child to parent (hierarchy direction)
            if !has_edge(graph, child_idx, parent_idx)
                add_edge!(graph, child_idx, parent_idx)
                edges_added += 1
            end
        end
    end
    
    @info "Built ontology graph with $n_terms nodes and $edges_added edges"
    
    return graph, term_to_index, term_ids
end

"""
Find relevant cell type terms for deconvolution
"""
function find_relevant_cell_types(terms::Dict{String, Dict{String, Any}}, 
                                cell_type_names::Vector{String};
                                config::CellOntologyConfig=DEFAULT_ONTOLOGY_CONFIG)
    @info "Finding ontology terms for cell types: $(join(cell_type_names, ", "))"
    
    relevant_terms = Dict{String, String}()  # cell_type_name => term_id
    
    for cell_type in cell_type_names
        # Normalize cell type name
        normalized_name = lowercase(replace(cell_type, r"[_\s]+" => " "))
        
        best_match = nothing
        best_score = 0.0
        
        for (term_id, term_data) in terms
            term_name = lowercase(get(term_data, "name", ""))
            
            # Exact match
            if normalized_name == term_name
                relevant_terms[cell_type] = term_id
                @info "  Exact match: $cell_type -> $term_id ($(term_data["name"]))"
                break
            end
            
            # Partial match scoring
            score = 0.0
            if occursin(normalized_name, term_name)
                score += 0.8
            elseif occursin(term_name, normalized_name)
                score += 0.6
            end
            
            # Check synonyms if available
            if haskey(term_data, "synonyms") && config.include_synonyms
                for synonym in term_data["synonyms"]
                    synonym_norm = lowercase(synonym)
                    if normalized_name == synonym_norm
                        score = 1.0
                        break
                    elseif occursin(normalized_name, synonym_norm) || occursin(synonym_norm, normalized_name)
                        score = max(score, 0.7)
                    end
                end
            end
            
            if score > best_score
                best_match = term_id
                best_score = score
            end
        end
        
        # Accept matches above threshold
        if best_match !== nothing && best_score >= 0.5
            relevant_terms[cell_type] = best_match
            @info "  Match: $cell_type -> $best_match ($(terms[best_match]["name"]), score: $best_score)"
        else
            @warn "  No suitable ontology term found for: $cell_type"
        end
    end
    
    return relevant_terms
end

"""
Extract ontology subgraph for relevant cell types
"""
function extract_cell_type_subgraph(ontology_graph::SimpleDiGraph, 
                                   term_to_index::Dict{String, Int},
                                   relevant_terms::Dict{String, String};
                                   config::CellOntologyConfig=DEFAULT_ONTOLOGY_CONFIG)
    @info "Extracting subgraph for $(length(relevant_terms)) relevant cell types"
    
    # Get indices of relevant terms
    relevant_indices = Set{Int}()
    for (cell_type, term_id) in relevant_terms
        if haskey(term_to_index, term_id)
            push!(relevant_indices, term_to_index[term_id])
        end
    end
    
    # Find all ancestors up to specified depth
    expanded_indices = copy(relevant_indices)
    
    for depth in 1:config.max_depth
        new_indices = Set{Int}()
        
        for idx in expanded_indices
            # Add all parents (outgoing edges in our hierarchy)
            for parent_idx in outneighbors(ontology_graph, idx)
                push!(new_indices, parent_idx)
            end
        end
        
        union!(expanded_indices, new_indices)
        
        if isempty(new_indices)
            break  # No more parents found
        end
    end
    
    @info "Expanded to $(length(expanded_indices)) terms including ancestors"
    
    # Create subgraph
    expanded_list = collect(expanded_indices)
    subgraph, vertex_map = induced_subgraph(ontology_graph, expanded_list)
    
    # Create reverse mapping
    subgraph_to_original = Dict(i => expanded_list[i] for i in 1:length(expanded_list))
    
    return subgraph, subgraph_to_original, expanded_indices
end

"""
Create integrated gene-ontology graph
"""
function create_integrated_graph(gene_graph::SimpleGraph, 
                                ontology_subgraph::SimpleDiGraph,
                                gene_symbols::Vector{String},
                                cell_types::Vector{String},
                                relevant_terms::Dict{String, String})
    @info "Creating integrated gene-ontology graph"
    
    n_genes = nv(gene_graph)
    n_ontology_terms = nv(ontology_subgraph)
    n_total = n_genes + n_ontology_terms
    
    # Create heterogeneous graph (genes + ontology terms)
    integrated_graph = SimpleGraph(n_total)
    
    # Add gene-gene edges
    for edge in edges(gene_graph)
        add_edge!(integrated_graph, src(edge), dst(edge))
    end
    
    # Add ontology edges (convert directed to undirected for GNN)
    gene_offset = n_genes
    for edge in edges(ontology_subgraph)
        src_idx = src(edge) + gene_offset
        dst_idx = dst(edge) + gene_offset
        add_edge!(integrated_graph, src_idx, dst_idx)
    end
    
    # Add gene-to-cell-type edges based on expression specificity
    # This connects genes to the cell types they are most expressed in
    gene_to_celltype_edges = 0
    
    for (i, cell_type) in enumerate(cell_types)
        if haskey(relevant_terms, cell_type)
            # Find the ontology term index in the integrated graph
            term_idx = n_genes + i  # Simplified mapping for now
            
            # Connect to genes (this would be based on expression analysis)
            # For now, connect each cell type to a few random genes as placeholder
            # In real implementation, this would be based on marker gene analysis
            
            n_connections = min(10, n_genes)  # Connect to top 10 marker genes
            for gene_idx in 1:n_connections
                add_edge!(integrated_graph, gene_idx, term_idx)
                gene_to_celltype_edges += 1
            end
        end
    end
    
    @info "Integrated graph: $(nv(integrated_graph)) nodes, $(ne(integrated_graph)) edges"
    @info "Added $gene_to_celltype_edges gene-to-cell-type edges"
    
    # Create node type mapping
    node_types = vcat(
        fill("gene", n_genes),
        fill("cell_type", n_ontology_terms)
    )
    
    return integrated_graph, node_types
end

"""
Main function to build complete ontology-guided graph
"""
function build_ontology_guided_graph(gene_graph::SimpleGraph,
                                    gene_symbols::Vector{String},
                                    cell_types::Vector{String};
                                    config::CellOntologyConfig=DEFAULT_ONTOLOGY_CONFIG)
    @info "="^50
    @info "BUILDING ONTOLOGY-GUIDED GRAPH"
    @info "="^50
    
    # Download and parse ontology
    obo_file = download_cell_ontology(config)
    if obo_file === nothing
        @error "Failed to download ontology, falling back to gene graph only"
        return gene_graph, fill("gene", nv(gene_graph))
    end
    
    terms, relationships = parse_obo_ontology(obo_file)
    
    # Build ontology graph
    ontology_graph, term_to_index, term_ids = build_ontology_graph(terms, relationships; config=config)
    
    # Find relevant cell type terms
    relevant_terms = find_relevant_cell_types(terms, cell_types; config=config)
    
    if isempty(relevant_terms)
        @warn "No relevant ontology terms found, using gene graph only"
        return gene_graph, fill("gene", nv(gene_graph))
    end
    
    # Extract subgraph for relevant terms
    ontology_subgraph, subgraph_mapping, expanded_indices = extract_cell_type_subgraph(
        ontology_graph, term_to_index, relevant_terms; config=config
    )
    
    # Create integrated graph
    integrated_graph, node_types = create_integrated_graph(
        gene_graph, ontology_subgraph, gene_symbols, cell_types, relevant_terms
    )
    
    return integrated_graph, node_types
end
