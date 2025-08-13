using LinearAlgebra
using Optim

"""
Linear Regression Baseline for Cell Type Deconvolution
This implements the standard approach used by methods like CIBERSORTx
"""

struct LinearDeconvolutionModel
    reference_matrix::Matrix{Float64}  # genes × cell_types
    cell_type_names::Vector{String}
    gene_names::Vector{String}
    regularization::String
    alpha::Float64
end

function train_linear_deconvolution(X_reference::Matrix, y_reference::Vector{String};
                                    regularization="nnls", alpha=0.01)
    """
    Train linear deconvolution model

    Args:
        X_reference: gene expression matrix (genes × samples)
        y_reference: cell type labels for each sample
        regularization: "nnls", "l2", or "elastic_net"
        alpha: regularization strength
    """

    # Get unique cell types
    cell_types = unique(y_reference)
    n_cell_types = length(cell_types)
    n_genes = size(X_reference, 1)

    # Create reference matrix by averaging expression per cell type
    reference_matrix = zeros(n_genes, n_cell_types)

    for (i, cell_type) in enumerate(cell_types)
        cell_indices = findall(x -> x == cell_type, y_reference)
        if length(cell_indices) > 0
            reference_matrix[:, i] = mean(X_reference[:, cell_indices]; dims=2)[:, 1]
        end
    end

    # Gene names (assuming they're not provided, use indices)
    gene_names = ["Gene_$i" for i in 1:n_genes]

    return LinearDeconvolutionModel(reference_matrix, cell_types, gene_names,
                                    regularization, alpha)
end

function predict_linear_deconvolution(model::LinearDeconvolutionModel, X_mixture::Matrix)
    """
    Predict cell type proportions for mixture samples

    Args:
        model: trained LinearDeconvolutionModel
        X_mixture: mixture gene expression (genes × samples)

    Returns:
        proportions: cell_types × samples matrix
    """

    n_samples = size(X_mixture, 2)
    n_cell_types = size(model.reference_matrix, 2)
    proportions = zeros(n_cell_types, n_samples)

    for i in 1:n_samples
        mixture_sample = X_mixture[:, i]

        if model.regularization == "nnls"
            # Non-negative least squares (standard approach)
            props = nonneg_lsq(model.reference_matrix, mixture_sample)
        elseif model.regularization == "l2"
            # L2 regularized least squares
            props = ridge_regression(model.reference_matrix, mixture_sample, model.alpha)
        else
            # Standard least squares
            props = model.reference_matrix \ mixture_sample
            props = max.(props, 0.0)  # Ensure non-negative
        end

        # Normalize to sum to 1
        props = props / sum(props)
        proportions[:, i] = props
    end

    return proportions
end

function ridge_regression(A::Matrix, b::Vector, alpha::Float64)
    """
    Solve ridge regression: argmin ||Ax - b||² + α||x||²
    """
    n = size(A, 2)
    x = (A' * A + alpha * I(n)) \ (A' * b)
    return max.(x, 0.0)  # Ensure non-negative
end

function nonneg_lsq(A::Matrix, b::Vector; max_iter=1000)
    """
    Non-negative least squares using coordinate descent fallback
    """
    # Use our own implementation to avoid dependency issues
    return coordinate_descent_nnls(A, b, max_iter)
end

function coordinate_descent_nnls(A::Matrix, b::Vector, max_iter::Int)
    """
    Simple coordinate descent for non-negative least squares
    """
    n = size(A, 2)
    x = ones(n) / n  # Initialize with uniform proportions

    AtA = A' * A
    Atb = A' * b

    for iter in 1:max_iter
        x_old = copy(x)

        for j in 1:n
            # Update j-th coordinate
            residual = Atb[j] - sum(AtA[j, k] * x[k] for k in 1:n if k != j)
            x[j] = max(0.0, residual / AtA[j, j])
        end

        # Check convergence
        if norm(x - x_old) < 1e-6
            break
        end
    end

    return x
end

"""
CIBERSORTx-style implementation with feature selection and robust regression
"""
function train_cibersortx_style(X_reference::Matrix, y_reference::Vector{String};
                                n_features=500, robust=true)
    """
    Train CIBERSORTx-style model with feature selection
    """

    # Step 1: Feature selection (select most variable genes)
    gene_variances = var(X_reference; dims=2)[:, 1]
    top_gene_indices = sortperm(gene_variances; rev=true)[1:min(n_features,
                                                                length(gene_variances))]

    X_selected = X_reference[top_gene_indices, :]

    # Step 2: Train linear model on selected features
    model = train_linear_deconvolution(X_selected, y_reference;
                                       regularization=robust ? "l2" : "nnls")

    # Store feature selection info
    model_enhanced = (model=model,
                      selected_features=top_gene_indices,
                      n_features=n_features)

    return model_enhanced
end

function predict_cibersortx_style(model_enhanced, X_mixture::Matrix)
    """
    Predict using CIBERSORTx-style model
    """
    # Apply same feature selection
    X_selected = X_mixture[model_enhanced.selected_features, :]

    # Predict using linear model
    return predict_linear_deconvolution(model_enhanced.model, X_selected)
end

"""
Evaluate feature importance for linear models
"""
function analyze_feature_importance(model::LinearDeconvolutionModel)
    """
    Analyze which genes are most important for each cell type
    """
    importance_matrix = abs.(model.reference_matrix)

    # Normalize by gene (row-wise)
    gene_sums = sum(importance_matrix; dims=2)
    normalized_importance = importance_matrix ./ gene_sums

    # Find top genes for each cell type
    top_genes_per_type = Dict()
    for (i, cell_type) in enumerate(model.cell_type_names)
        gene_importance = normalized_importance[:, i]
        top_indices = sortperm(gene_importance; rev=true)[1:min(20,
                                                                length(gene_importance))]
        top_genes_per_type[cell_type] = [(model.gene_names[idx], gene_importance[idx])
                                         for idx in top_indices]
    end

    return top_genes_per_type
end
