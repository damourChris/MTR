using Plots
using StatsPlots
using DataFrames
using Statistics

"""
Visualization utilities for experimental results
"""

function plot_method_comparison(aggregated_results, output_dir)
    """
    Create comprehensive visualization comparing all methods
    """

    # Extract method names and performance metrics
    methods = collect(keys(aggregated_results))

    # Metrics to plot
    metrics = ["mean_pearson", "overall_rmse", "overall_mae", "detection_accuracy"]
    metric_labels = ["Mean Pearson Correlation", "Overall RMSE", "Overall MAE",
                     "Detection Accuracy"]

    # Create subplot layout
    p = plot(; layout=(2, 2), size=(1200, 800))

    for (i, (metric, label)) in enumerate(zip(metrics, metric_labels))
        means = []
        stds = []
        method_names = []

        for method in methods
            if haskey(aggregated_results[method], metric * "_mean")
                push!(means, aggregated_results[method][metric * "_mean"])
                push!(stds, aggregated_results[method][metric * "_std"])
                push!(method_names, method)
            end
        end

        if !isempty(means)
            # Create bar plot with error bars
            bar!(p[i], method_names, means; yerror=stds,
                 title=label, xrotation=45, legend=false,
                 fillcolor=:lightblue, linecolor=:blue)
        end
    end

    plot!(p; plot_title="Method Comparison", titlefontsize=16)

    savefig(p, joinpath(output_dir, "method_comparison.png"))
    savefig(p, joinpath(output_dir, "method_comparison.pdf"))

    return p
end

function plot_correlation_heatmap(aggregated_results, output_dir)
    """
    Create heatmap showing per-cell-type correlations for each method
    """

    methods = collect(keys(aggregated_results))

    # Extract per-cell-type correlations
    correlation_data = Dict()
    for method in methods
        if haskey(aggregated_results[method], "pearson_correlations")
            correlation_data[method] = aggregated_results[method]["pearson_correlations"]
        end
    end

    if isempty(correlation_data)
        @warn "No per-cell-type correlation data found"
        return nothing
    end

    # Create heatmap
    n_cell_types = length(first(values(correlation_data)))
    cell_type_labels = ["Cell Type $i" for i in 1:n_cell_types]

    correlation_matrix = zeros(length(methods), n_cell_types)

    for (i, method) in enumerate(methods)
        if haskey(correlation_data, method)
            correlations = correlation_data[method]
            # Handle NaN values
            clean_correlations = [isnan(c) ? 0.0 : c for c in correlations]
            correlation_matrix[i, :] = clean_correlations
        end
    end

    p = heatmap(cell_type_labels, methods, correlation_matrix;
                title="Per-Cell-Type Pearson Correlations",
                xlabel="Cell Types", ylabel="Methods",
                color=:viridis, size=(800, 600))

    savefig(p, joinpath(output_dir, "correlation_heatmap.png"))
    savefig(p, joinpath(output_dir, "correlation_heatmap.pdf"))

    return p
end

function plot_statistical_significance(comparisons, output_dir)
    """
    Visualize statistical significance results
    """

    # Filter significant comparisons
    significant_comps = filter(c -> c.significant, comparisons)

    if isempty(significant_comps)
        @info "No statistically significant differences found"
        return nothing
    end

    # Extract data for plotting
    comparison_labels = ["$(c.method1) vs $(c.method2)" for c in significant_comps]
    effect_sizes = [c.effect_size for c in significant_comps]
    pvalues = [c.corrected_pvalue for c in significant_comps]

    # Effect size plot
    p1 = bar(comparison_labels, effect_sizes;
             title="Effect Sizes (Significant Comparisons)",
             xrotation=45, ylabel="Cohen's d",
             legend=false, fillcolor=:orange)

    # P-value plot
    p2 = bar(comparison_labels, -log10.(pvalues);
             title="Statistical Significance",
             xrotation=45, ylabel="-log10(corrected p-value)",
             legend=false, fillcolor=:red)

    # Add significance threshold line
    hline!(p2, [-log10(0.05)]; linestyle=:dash, linecolor=:black,
           label="α = 0.05", legend=true)

    # Combine plots
    p = plot(p1, p2; layout=(2, 1), size=(1000, 800))

    savefig(p, joinpath(output_dir, "statistical_significance.png"))
    savefig(p, joinpath(output_dir, "statistical_significance.pdf"))

    return p
end

function plot_cross_validation_stability(all_cv_results, output_dir)
    """
    Plot cross-validation stability across folds
    """

    methods = collect(keys(all_cv_results))

    # Create boxplots showing variation across CV folds
    plots = []

    for metric in ["mean_pearson", "overall_rmse", "overall_mae"]
        data_for_plotting = []
        method_labels = []

        for method in methods
            cv_results = all_cv_results[method]
            if !isempty(cv_results)
                metric_values = []
                for result in cv_results
                    if haskey(result, metric) && !isnan(result[metric])
                        push!(metric_values, result[metric])
                    end
                end

                if !isempty(metric_values)
                    append!(data_for_plotting, metric_values)
                    append!(method_labels, repeat([method], length(metric_values)))
                end
            end
        end

        if !isempty(data_for_plotting)
            p = boxplot(method_labels, data_for_plotting;
                        title="$metric (Cross-Validation)",
                        xrotation=45, legend=false)
            push!(plots, p)
        end
    end

    if !isempty(plots)
        combined_plot = plot(plots...; layout=(length(plots), 1), size=(800, 1200))
        savefig(combined_plot, joinpath(output_dir, "cv_stability.png"))
        savefig(combined_plot, joinpath(output_dir, "cv_stability.pdf"))
        return combined_plot
    end

    return nothing
end

function create_performance_radar_chart(aggregated_results, output_dir)
    """
    Create radar chart comparing methods across multiple metrics
    """

    methods = collect(keys(aggregated_results))
    metrics = ["mean_pearson_mean", "detection_accuracy_mean"]

    # Normalize metrics to 0-1 scale for radar chart
    metric_values = Dict()
    for metric in metrics
        values = []
        for method in methods
            if haskey(aggregated_results[method], metric)
                push!(values, aggregated_results[method][metric])
            else
                push!(values, 0.0)
            end
        end
        metric_values[metric] = values
    end

    # For RMSE and MAE, invert values (lower is better)
    if haskey(metric_values, "overall_rmse_mean")
        max_rmse = maximum(metric_values["overall_rmse_mean"])
        metric_values["overall_rmse_mean"] = 1.0 .- (metric_values["overall_rmse_mean"] ./
                                                     max_rmse)
    end

    if haskey(metric_values, "overall_mae_mean")
        max_mae = maximum(metric_values["overall_mae_mean"])
        metric_values["overall_mae_mean"] = 1.0 .-
                                            (metric_values["overall_mae_mean"] ./ max_mae)
    end

    # Create radar chart (simplified version)
    θ = range(0, 2π; length=length(metrics) + 1)[1:(end - 1)]

    p = plot(; proj=:polar, size=(600, 600))

    colors = [:blue, :red, :green, :orange, :purple]

    for (i, method) in enumerate(methods)
        values = [metric_values[metric][i] for metric in metrics]
        push!(values, values[1])  # Close the polygon

        plot!(p, [θ; θ[1]], values;
              label=method, linewidth=2, color=colors[mod(i - 1, length(colors)) + 1])
    end

    plot!(p; title="Method Performance Comparison (Radar Chart)")

    savefig(p, joinpath(output_dir, "performance_radar.png"))
    savefig(p, joinpath(output_dir, "performance_radar.pdf"))

    return p
end

function generate_all_visualizations(aggregated_results, all_cv_results, comparisons,
                                     output_dir)
    """
    Generate all visualization plots
    """

    @info "Generating visualizations..."

    # Create visualization directory
    viz_dir = joinpath(output_dir, "visualizations")
    if !isdir(viz_dir)
        mkdir(viz_dir)
    end

    plots_generated = []

    try
        p1 = plot_method_comparison(aggregated_results, viz_dir)
        push!(plots_generated, "method_comparison")
    catch e
        @warn "Failed to generate method comparison plot: $e"
    end

    try
        p2 = plot_correlation_heatmap(aggregated_results, viz_dir)
        if p2 !== nothing
            push!(plots_generated, "correlation_heatmap")
        end
    catch e
        @warn "Failed to generate correlation heatmap: $e"
    end

    try
        p3 = plot_statistical_significance(comparisons, viz_dir)
        if p3 !== nothing
            push!(plots_generated, "statistical_significance")
        end
    catch e
        @warn "Failed to generate statistical significance plot: $e"
    end

    try
        p4 = plot_cross_validation_stability(all_cv_results, viz_dir)
        if p4 !== nothing
            push!(plots_generated, "cv_stability")
        end
    catch e
        @warn "Failed to generate CV stability plot: $e"
    end

    try
        p5 = create_performance_radar_chart(aggregated_results, viz_dir)
        push!(plots_generated, "performance_radar")
    catch e
        @warn "Failed to generate performance radar chart: $e"
    end

    @info "Generated $(length(plots_generated)) visualization plots:"
    for plot_name in plots_generated
        @info "  - $plot_name"
    end

    return plots_generated
end
