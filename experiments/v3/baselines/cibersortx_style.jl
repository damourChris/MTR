"""
CIBERSORTx-style baseline implementation for cell type deconvolution
This implements the support vector regression approach similar to CIBERSORT
"""

using Random
using Statistics
using LinearAlgebra
using Optim

"""
CIBERSORTx-style deconvolution using support vector regression
"""
struct CIBERSORTxModel
    reference_matrix::Matrix{Float64}  # genes × cell_types
    cell_types::Vector{String}
    marker_genes::Vector{Int}          # indices of selected marker genes
    regression_weights::Matrix{Float64} # learned weights
end

"""
Feature selection based on differential expression and correlation
This selects the most informative genes for deconvolution
"""
function select_marker_genes(X_reference::Matrix, y_reference::Vector{String};
                             top_genes_per_celltype::Int=100,
                             correlation_threshold::Float64=0.1)  # Lower threshold for better sensitivity
    cell_types = unique(y_reference)
    n_genes = size(X_reference, 1)

    # Calculate reference profiles (mean expression per cell type)
    reference_profiles = zeros(n_genes, length(cell_types))
    for (i, ct) in enumerate(cell_types)
        ct_indices = findall(x -> x == ct, y_reference)
        reference_profiles[:, i] = mean(X_reference[:, ct_indices]; dims=2)[:, 1]
    end

    selected_genes = Set{Int}()

    # For each cell type, find top differentially expressed genes
    for (ct_idx, ct) in enumerate(cell_types)
        # Calculate fold changes vs other cell types
        ct_expression = reference_profiles[:, ct_idx]
        other_expression = mean(reference_profiles[:,
                                                   setdiff(1:length(cell_types), ct_idx)];
                                dims=2)[:, 1]

        # Avoid division by zero
        fold_changes = log2.((ct_expression .+ 1e-6) ./ (other_expression .+ 1e-6))

        # Select top genes by fold change
        top_indices = sortperm(fold_changes; rev=true)[1:min(top_genes_per_celltype,
                                                             n_genes)]
        union!(selected_genes, top_indices)
    end

    # Filter by correlation with reference profiles
    marker_genes = Int[]
    for gene_idx in selected_genes
        gene_expr = reference_profiles[gene_idx, :]
        # Check if gene has good dynamic range
        if maximum(gene_expr) - minimum(gene_expr) > correlation_threshold
            push!(marker_genes, gene_idx)
        end
    end

    @info "Selected $(length(marker_genes)) marker genes from $(n_genes) total genes"

    return sort(marker_genes)
end

"""
Create reference signature matrix from selected marker genes
"""
function create_signature_matrix(X_reference::Matrix, y_reference::Vector{String},
                                 marker_genes::Vector{Int})
    cell_types = unique(y_reference)
    n_markers = length(marker_genes)
    n_cell_types = length(cell_types)

    signature_matrix = zeros(n_markers, n_cell_types)

    for (i, ct) in enumerate(cell_types)
        ct_indices = findall(x -> x == ct, y_reference)
        if !isempty(ct_indices)
            # Use median instead of mean for robustness (CIBERSORTx approach)
            for (j, gene_idx) in enumerate(marker_genes)
                signature_matrix[j, i] = median(X_reference[gene_idx, ct_indices])
            end
        end
    end

    # Normalize signature matrix (optional, but often helps)
    for i in 1:n_cell_types
        col_sum = sum(signature_matrix[:, i])
        if col_sum > 0
            signature_matrix[:, i] ./= col_sum
        end
    end

    return signature_matrix, cell_types
end

"""
Support Vector Regression for proportion estimation
This is a simplified version of the SVR approach
"""
function svr_deconvolution(mixture_expr::Vector{Float64}, signature_matrix::Matrix{Float64};
                           nu::Float64=0.5, tolerance::Float64=1e-6)
    n_markers, n_cell_types = size(signature_matrix)

    # Initialize proportions
    proportions = ones(n_cell_types) ./ n_cell_types

    # Objective function: minimize ||signature * proportions - mixture||₂ + regularization
    function objective(props::Vector{Float64})
        # Ensure proportions sum to 1 and are non-negative
        props_normalized = max.(props, 0.0)
        props_normalized ./= sum(props_normalized)

        # Reconstruction error
        reconstruction = signature_matrix * props_normalized
        mse = sum((reconstruction .- mixture_expr) .^ 2)

        # L2 regularization term
        regularization = nu * sum(props_normalized .^ 2)

        return mse + regularization
    end

    # Constraint: proportions sum to 1
    function constraint(props::Vector{Float64})
        return sum(props) - 1.0
    end

    # Optimize using constrained optimization
    try
        # Use simple gradient descent with projection
        proportions = optimize_with_projection(objective, proportions, tolerance)
    catch e
        @warn "Optimization failed, using uniform proportions: $e"
        proportions = ones(n_cell_types) ./ n_cell_types
    end

    return proportions
end

"""
Simple projected gradient descent for proportion optimization
"""
function optimize_with_projection(objective::Function, initial_props::Vector{Float64},
                                  tolerance::Float64, max_iter::Int=1000, lr::Float64=0.01)
    props = copy(initial_props)
    n_cell_types = length(props)

    for iter in 1:max_iter
        # Compute gradient numerically (simple finite differences)
        grad = zeros(n_cell_types)
        eps = 1e-8

        for i in 1:n_cell_types
            props_plus = copy(props)
            props_plus[i] += eps
            props_minus = copy(props)
            props_minus[i] -= eps

            grad[i] = (objective(props_plus) - objective(props_minus)) / (2 * eps)
        end

        # Gradient step
        props_new = props .- lr .* grad

        # Project onto simplex (non-negative, sum to 1)
        props_new = project_simplex(props_new)

        # Check convergence
        if norm(props_new - props) < tolerance
            break
        end

        props = props_new
    end

    return props
end

"""
Project vector onto probability simplex
"""
function project_simplex(v::Vector{Float64})
    n = length(v)

    # Sort in descending order
    v_sorted = sort(v; rev=true)

    # Find the projection
    cumsum_v = cumsum(v_sorted)

    # Find the largest k such that v_sorted[k] + (1 - cumsum_v[k])/k > 0
    k = n
    for i in 1:n
        if v_sorted[i] + (1 - cumsum_v[i]) / i <= 0
            k = i - 1
            break
        end
    end

    if k == 0
        return zeros(n)
    end

    # Compute the threshold
    theta = (1 - cumsum_v[k]) / k

    # Project
    return max.(v .+ theta, 0.0)
end

"""
Train CIBERSORTx-style model
"""
function train_cibersortx_model(X_reference::Matrix, y_reference::Vector{String};
                                top_genes_per_celltype::Int=100,
                                correlation_threshold::Float64=0.3)
    @info "Training CIBERSORTx-style model..."

    # Step 1: Feature selection
    marker_genes = select_marker_genes(X_reference, y_reference;
                                       top_genes_per_celltype, correlation_threshold)

    # Step 2: Create signature matrix
    signature_matrix, cell_types = create_signature_matrix(X_reference, y_reference,
                                                           marker_genes)

    @info "Created signature matrix: $(size(signature_matrix)) for $(length(cell_types)) cell types"

    # Create model object
    model = CIBERSORTxModel(signature_matrix, cell_types, marker_genes, signature_matrix)

    return model
end

"""
Predict cell type proportions using CIBERSORTx-style model
"""
function predict_cibersortx(model::CIBERSORTxModel, X_mixture::Matrix; nu::Float64=0.5)
    n_mixtures = size(X_mixture, 2)
    n_cell_types = length(model.cell_types)

    predictions = zeros(n_mixtures, n_cell_types)

    @info "Predicting proportions for $(n_mixtures) mixtures..."

    for i in 1:n_mixtures
        # Extract marker gene expression for this mixture
        mixture_markers = X_mixture[model.marker_genes, i]

        # Predict proportions using SVR
        proportions = svr_deconvolution(mixture_markers, model.reference_matrix; nu=nu)

        predictions[i, :] = proportions
    end

    return predictions
end

"""
Cross-validation wrapper for CIBERSORTx baseline
"""
function run_cibersortx_baseline_cv(cv_folds, X_reference::Matrix,
                                    y_reference::Vector{String};
                                    config::NamedTuple=(top_genes_per_celltype=100,
                                                        correlation_threshold=0.3, nu=0.5))
    @info "Running CIBERSORTx-style baseline with cross-validation..."

    fold_results = []

    for (fold_idx, fold_data) in enumerate(cv_folds)
        @info "  Processing fold $fold_idx/$(length(cv_folds))"

        # Get training and test data from fold structure
        X_train = fold_data.X_train
        y_train = fold_data.y_train
        X_test = fold_data.X_test
        y_test = fold_data.y_test

        try
            # Train model
            model = train_cibersortx_model(X_reference, y_reference;
                                           top_genes_per_celltype=get(config,
                                                                      :top_genes_per_celltype,
                                                                      100),
                                           correlation_threshold=get(config,
                                                                     :correlation_threshold,
                                                                     0.3))

            # Predict on test set
            y_pred = predict_cibersortx(model, X_test; nu=get(config, :nu, 0.5))

            # Store results
            fold_result = (fold=fold_idx,
                           y_true=y_test,
                           y_pred=y_pred,
                           model=model)

            push!(fold_results, fold_result)

        catch e
            @warn "Failed to process fold $fold_idx: $e"
            # Create dummy results for failed fold
            dummy_pred = ones(size(X_test, 2), length(unique(y_reference))) ./
                         length(unique(y_reference))
            fold_result = (fold=fold_idx,
                           y_true=y_test,
                           y_pred=dummy_pred,
                           model=nothing)
            push!(fold_results, fold_result)
        end
    end

    return fold_results
end