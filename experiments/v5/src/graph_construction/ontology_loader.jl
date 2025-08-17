"""
Ontology loading and validation for V5 graph construction pipeline.

Handles loading OntologyTree structures from various sources and validates
them for compatibility with GNN graph construction. Integrates with the
repository system for caching ontology data.
"""

using OntologyTrees
using Graphs
using MetaGraphs

"""
    OntologyLoader

Handles loading and validation of ontology trees for graph construction.

Provides methods to load ontology trees from different sources:
- Cell type lists with automatic hierarchy construction
- Pre-built OntologyTree objects
- Cached ontology data from repository

# Features
- Automatic validation of ontology structure
- Integration with V5 repository caching
- Support for various cell type sources
- Configurable ontology depth and complexity
"""
struct OntologyLoader
    repository::Union{AbstractRepository, Nothing}
    cache_prefix::String

    function OntologyLoader(repository::Union{AbstractRepository, Nothing} = nothing)
        cache_prefix = "ontology"
        return new(repository, cache_prefix)
    end
end

"""
    load_ontology_tree(loader::OntologyLoader, cell_types::Vector{String}; options...)::OntologyTree

Load an ontology tree for the specified cell types.

# Arguments
- `loader::OntologyLoader`: Loader instance
- `cell_types::Vector{String}`: List of cell type identifiers

# Keyword Arguments
- `base_term_iri::String`: IRI of the base term (default: leukocyte)
- `max_depth::Int`: Maximum ontology depth (default: from preferences)
- `include_uberon::Bool`: Include UBERON terms (default: false)
- `cache_key::Union{String,Nothing}`: Custom cache key (default: auto-generated)

# Returns
- `OntologyTree`: Loaded and validated ontology tree

# Throws
- `OntologyTreeInvalidError`: If ontology tree is invalid
- `DataSourceUnavailableError`: If ontology data cannot be accessed
"""
function load_ontology_tree(
    loader::OntologyLoader,
    cell_types::Vector{String};
    base_term_iri::String = "http://purl.obolibrary.org/obo/CL_0000542",
    max_depth::Union{Int, Nothing} = nothing,
    include_uberon::Bool = false,
    cache_key::Union{String, Nothing} = nothing,
)::OntologyTree

    # Validate inputs
    validate_cell_type_list(cell_types)

    # Set default max_depth from preferences if not provided
    if max_depth === nothing
        max_depth = get_ontology_maximum_depth_limit()
    end

    # Generate cache key if not provided
    if cache_key === nothing
        cache_params = Dict{String, Any}(
            "cell_types" => sort(cell_types),
            "base_term_iri" => base_term_iri,
            "max_depth" => max_depth,
            "include_uberon" => include_uberon,
            "cache_version" => "v5.1.0",
        )
        cache_key = generate_cache_key(loader.cache_prefix, cache_params)
    end

    # Try to load from cache if repository is available
    if loader.repository !== nothing && haskey(loader.repository, cache_key)
        try
            ontology_tree = loader.repository[cache_key, OntologyTree]
            validate_ontology_tree_structure(ontology_tree, cell_types)
            @debug "Loaded ontology tree from cache" cache_key = cache_key
            return ontology_tree
        catch e
            @warn "Failed to load cached ontology tree, rebuilding" cache_key = cache_key error =
                e
            # Continue to build new tree
        end
    end

    # Build new ontology tree
    ontology_tree = build_ontology_tree_from_cell_types(
        cell_types,
        base_term_iri,
        max_depth,
        include_uberon,
    )

    # Validate the constructed tree
    validate_ontology_tree_structure(ontology_tree, cell_types)

    # Cache the result if repository is available
    if loader.repository !== nothing &&
       get_data_source_caching_configuration()["ontology_data"]
        try
            loader.repository[cache_key] = ontology_tree
            @debug "Cached ontology tree" cache_key = cache_key
        catch e
            @warn "Failed to cache ontology tree" cache_key = cache_key error = e
            # Continue without caching
        end
    end

    return ontology_tree
end

"""
    build_ontology_tree_from_cell_types(cell_types::Vector{String}, 
                                        base_term_iri::String,
                                        max_depth::Int,
                                        include_uberon::Bool)::OntologyTree

Build an OntologyTree from a list of cell types.

# Arguments
- `cell_types::Vector{String}`: List of cell type identifiers
- `base_term_iri::String`: IRI of the base term
- `max_depth::Int`: Maximum ontology depth
- `include_uberon::Bool`: Include UBERON terms

# Returns
- `OntologyTree`: Constructed ontology tree

# Throws
- `DataSourceUnavailableError`: If ontology data cannot be accessed
- `OntologyTreeInvalidError`: If tree construction fails
"""
function build_ontology_tree_from_cell_types(
    cell_types::Vector{String},
    base_term_iri::String,
    max_depth::Int,
    include_uberon::Bool,
)::OntologyTree
    try
        # Create base term
        base_term = onto_term("cl", base_term_iri)

        # Convert cell type identifiers to terms
        required_terms = Term[]
        failed_terms = String[]

        for cell_type in cell_types
            try
                # Try to parse as IRI first, then as simple identifier
                if startswith(cell_type, "http://")
                    term = onto_term("cl", cell_type)
                else
                    # Assume it's a CL identifier and construct IRI
                    iri = "http://purl.obolibrary.org/obo/CL_$(cell_type)"
                    term = onto_term("cl", iri)
                end
                push!(required_terms, term)
            catch e
                @warn "Failed to create term for cell type: $cell_type" error = e
                push!(failed_terms, cell_type)
            end
        end

        # Check if we have any valid terms
        if isempty(required_terms)
            throw(
                OntologyTreeInvalidError(
                    "No valid terms could be created from provided cell types",
                    "term_creation_failed",
                    Dict{String, Any}(
                        "requested_cell_types" => length(cell_types),
                        "valid_terms" => 0,
                        "failed_terms" => failed_terms,
                    ),
                    ["valid cell type IRIs", "valid CL identifiers"],
                ),
            )
        end

        # Build the ontology tree
        ontology_tree = OntologyTree(
            base_term,
            required_terms;
            max_parent_limit = max_depth,
            allow_multiple_roots = false,
            include_UBERON = include_uberon,
        )

        if !isempty(failed_terms)
            @warn "Some cell types could not be processed" failed_terms = failed_terms
        end

        return ontology_tree

    catch e
        if isa(e, OntologyTreeInvalidError)
            rethrow(e)
        else
            throw(
                DataSourceUnavailableError(
                    "Failed to build ontology tree from cell types",
                    "ontology_service",
                    "OntologyLookup web service",
                    "Service unavailable or network error: $e",
                    true,  # retry recommended
                ),
            )
        end
    end
end

"""
    validate_ontology_tree_structure(ontology_tree::OntologyTree, expected_cell_types::Vector{String})

Validate that an ontology tree has the required structure for GNN conversion.

# Arguments
- `ontology_tree::OntologyTree`: Tree to validate
- `expected_cell_types::Vector{String}`: Expected cell types to be present

# Throws
- `OntologyTreeInvalidError`: If validation fails
"""
function validate_ontology_tree_structure(
    ontology_tree::OntologyTree,
    expected_cell_types::Vector{String},
)
    graph = ontology_tree.graph

    # Basic structure validation
    if nv(graph) == 0
        throw(
            OntologyTreeInvalidError(
                "Ontology tree is empty",
                "empty_graph",
                Dict{String, Any}("vertex_count" => 0, "edge_count" => 0),
                ["non-empty ontology tree"],
            ),
        )
    end

    # Check for required properties
    required_props = [:id, :type]
    missing_props = String[]

    for vertex_id in vertices(graph)
        vertex_props = get(graph.vprops, vertex_id, Dict())
        for prop in required_props
            if !haskey(vertex_props, prop)
                push!(missing_props, string(prop))
            end
        end
    end

    if !isempty(missing_props)
        throw(
            OntologyTreeInvalidError(
                "Ontology tree vertices missing required properties",
                "missing_vertex_properties",
                Dict{String, Any}(
                    "vertex_count" => nv(graph),
                    "missing_properties" => unique(missing_props),
                ),
                required_props,
            ),
        )
    end

    # Count different node types
    term_count = 0
    gene_count = 0

    for vertex_id in vertices(graph)
        vertex_props = get(graph.vprops, vertex_id, Dict())
        node_type = get(vertex_props, :type, :unknown)

        if node_type == :term
            term_count += 1
        elseif node_type == :gene
            gene_count += 1
        end
    end

    # Validate minimum structure
    if term_count == 0
        throw(
            OntologyTreeInvalidError(
                "Ontology tree contains no term nodes",
                "no_term_nodes",
                Dict{String, Any}(
                    "vertex_count" => nv(graph),
                    "term_count" => term_count,
                    "gene_count" => gene_count,
                ),
                ["at least one term node"],
            ),
        )
    end

    # Check connectivity
    if !is_connected(graph.graph)
        components = connected_components(graph.graph)
        throw(
            OntologyTreeInvalidError(
                "Ontology tree is not connected",
                "disconnected_graph",
                Dict{String, Any}(
                    "vertex_count" => nv(graph),
                    "component_count" => length(components),
                    "largest_component_size" => maximum(length.(components)),
                ),
                ["connected graph structure"],
            ),
        )
    end

    @debug "Ontology tree validation passed" vertex_count = nv(graph) edge_count = ne(graph) term_count =
        term_count gene_count = gene_count
end

"""
    validate_cell_type_list(cell_types::Vector{String})

Validate a list of cell type identifiers.

# Arguments
- `cell_types::Vector{String}`: List of cell type identifiers

# Throws
- `DataValidationError`: If cell type list is invalid
"""
function validate_cell_type_list(cell_types::Vector{String})
    if isempty(cell_types)
        throw(
            DataValidationError(
                "Cell type list cannot be empty",
                "cell_types",
                "non-empty list of cell type identifiers",
                "empty list",
            ),
        )
    end

    if length(cell_types) > 1000
        throw(
            DataValidationError(
                "Cell type list is too large for efficient processing",
                "cell_types",
                "list with ≤1000 cell types",
                "list with $(length(cell_types)) cell types",
            ),
        )
    end

    # Check for duplicates
    unique_types = unique(cell_types)
    if length(unique_types) != length(cell_types)
        duplicates = [ct for ct in cell_types if count(==(ct), cell_types) > 1]
        throw(
            DataValidationError(
                "Cell type list contains duplicates",
                "cell_types",
                "list with unique cell type identifiers",
                "list containing duplicates: $(join(unique(duplicates), ", "))",
            ),
        )
    end

    # Check for empty or invalid identifiers
    invalid_types =
        filter(ct -> isempty(strip(ct)) || occursin(r"[^a-zA-Z0-9_:\-/.]", ct), cell_types)
    if !isempty(invalid_types)
        throw(
            DataValidationError(
                "Cell type list contains invalid identifiers",
                "cell_types",
                "valid cell type identifiers (letters, numbers, underscore, colon, hyphen, slash, dot)",
                "invalid identifiers: $(join(invalid_types[1:min(5, end)], ", "))",
            ),
        )
    end
end

"""
    get_ontology_tree_statistics(ontology_tree::OntologyTree)::Dict{String,Any}

Get comprehensive statistics about an ontology tree.

# Arguments
- `ontology_tree::OntologyTree`: Tree to analyze

# Returns
- `Dict{String,Any}`: Statistics dictionary
"""
function get_ontology_tree_statistics(ontology_tree::OntologyTree)::Dict{String, Any}
    graph = ontology_tree.graph

    # Count different node types
    term_count = 0
    gene_count = 0

    for vertex_id in vertices(graph)
        vertex_props = get(graph.vprops, vertex_id, Dict())
        node_type = get(vertex_props, :type, :unknown)

        if node_type == :term
            term_count += 1
        elseif node_type == :gene
            gene_count += 1
        end
    end

    # Graph connectivity
    components = connected_components(graph.graph)

    return Dict{String, Any}(
        "vertex_count" => nv(graph),
        "edge_count" => ne(graph),
        "term_count" => term_count,
        "gene_count" => gene_count,
        "component_count" => length(components),
        "is_connected" => is_connected(graph.graph),
        "base_term" => ontology_tree.base_term.label,
        "required_terms_count" => length(ontology_tree.required_terms),
        "max_parent_limit" => ontology_tree.max_parent_limit,
        "allows_multiple_roots" => ontology_tree.allow_multiple_roots,
        "includes_uberon" => ontology_tree.include_UBERON,
    )
end

"""
    load_ontology_from_cell_type_names(cell_type_names::Vector{String})::OntologyTree

Convenience function to load ontology tree from cell type names.

# Arguments
- `cell_type_names::Vector{String}`: Human-readable cell type names

# Returns
- `OntologyTree`: Loaded ontology tree

# Note
This function attempts to map human-readable names to ontology identifiers.
For precise control, use `load_ontology_tree` with specific IRIs.
"""
function load_ontology_from_cell_type_names(cell_type_names::Vector{String})::OntologyTree
    loader = OntologyLoader()

    # This is a simplified mapping - in practice, you'd want a more sophisticated
    # name-to-IRI mapping system
    @warn "Loading from cell type names uses simplified mapping. For precise results, use specific IRIs."

    return load_ontology_tree(loader, cell_type_names)
end
