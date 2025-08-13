using HypothesisTests
using HypothesisTests: pvalue
using StatsBase
using MultipleTesting
using MultipleTesting: adjust

"""
Statistical testing framework for comparing deconvolution methods
"""

struct ComparisonResult
    method1::String
    method2::String
    metric::String
    pvalue::Float64
    corrected_pvalue::Float64
    effect_size::Float64
    confidence_interval::Tuple{Float64,Float64}
    significant::Bool
end

function paired_t_test_comparison(results1::Vector, results2::Vector,
                                  method1::String, method2::String, metric::String)
    """
    Perform paired t-test comparing two methods on a specific metric
    """
    # Remove NaN values
    valid_indices = .!isnan.(results1) .& .!isnan.(results2)
    clean_results1 = results1[valid_indices]
    clean_results2 = results2[valid_indices]

    if length(clean_results1) < 2
        @warn "Insufficient valid data points for statistical testing"
        return nothing
    end

    # Perform paired t-test
    test = OneSampleTTest(clean_results1 - clean_results2)
    test_pvalue = pvalue(test)

    # Calculate effect size (Cohen's d for paired samples)
    differences = clean_results1 - clean_results2
    effect_size = mean(differences) / std(differences)

    # Bootstrap confidence interval for the difference
    n_bootstrap = 1000
    bootstrap_diffs = []
    for _ in 1:n_bootstrap
        indices = sample(1:length(differences), length(differences); replace=true)
        push!(bootstrap_diffs, mean(differences[indices]))
    end

    ci_lower = quantile(bootstrap_diffs, 0.025)
    ci_upper = quantile(bootstrap_diffs, 0.975)

    return ComparisonResult(method1, method2, metric, test_pvalue, test_pvalue,  # corrected_pvalue will be set later
                            effect_size, (ci_lower, ci_upper), false)
end

function compare_all_methods(all_results::Dict, metrics::Vector{String},
                             alpha::Float64=0.05, correction_method::String="bonferroni")
    """
    Compare all method pairs across all metrics with multiple testing correction
    """
    method_names = collect(keys(all_results))
    n_methods = length(method_names)
    comparisons = ComparisonResult[]

    # Perform all pairwise comparisons
    for i in 1:n_methods
        for j in (i + 1):n_methods
            method1, method2 = method_names[i], method_names[j]

            for metric in metrics
                if haskey(all_results[method1], metric) &&
                   haskey(all_results[method2], metric)
                    # Handle both scalar and vector metrics
                    results1 = all_results[method1][metric]
                    results2 = all_results[method2][metric]

                    # Convert to vectors if scalar
                    if isa(results1, Number)
                        results1 = [results1]
                        results2 = [results2]
                    end

                    comparison = paired_t_test_comparison(results1, results2, method1,
                                                          method2, metric)
                    if comparison !== nothing
                        push!(comparisons, comparison)
                    end
                end
            end
        end
    end

    # Apply multiple testing correction
    pvalues = [comp.pvalue for comp in comparisons]

    if correction_method == "bonferroni"
        corrected_pvalues = adjust(pvalues, Bonferroni())
    elseif correction_method == "fdr"
        corrected_pvalues = adjust(pvalues, BenjaminiHochberg())
    else
        corrected_pvalues = pvalues  # No correction
    end

    # Update results with corrected p-values and significance
    for (i, comp) in enumerate(comparisons)
        comparisons[i] = ComparisonResult(comp.method1, comp.method2, comp.metric,
                                          comp.pvalue, corrected_pvalues[i],
                                          comp.effect_size,
                                          comp.confidence_interval,
                                          corrected_pvalues[i] < alpha)
    end

    return comparisons
end

function cross_validation_comparison(methods::Dict, data, n_folds::Int=5)
    """
    Perform cross-validation comparison of methods
    """
    n_samples = size(data["X"], 2)
    fold_size = div(n_samples, n_folds)

    cv_results = Dict()
    for method_name in keys(methods)
        cv_results[method_name] = Dict()
    end

    for fold in 1:n_folds
        # Define train/test split
        test_start = (fold - 1) * fold_size + 1
        test_end = fold == n_folds ? n_samples : fold * fold_size
        test_indices = test_start:test_end
        train_indices = setdiff(1:n_samples, test_indices)

        # Split data
        X_train = data["X"][:, train_indices]
        y_train = data["y"][:, train_indices]
        X_test = data["X"][:, test_indices]
        y_test = data["y"][:, test_indices]

        # Train and evaluate each method
        for (method_name, method_func) in methods
            try
                # Train method
                if method_name == "gnn_ontology" || method_name == "gnn_flat"
                    model = method_func(X_train, y_train, data["reference"])
                else
                    model = method_func(X_train, y_train)
                end

                # Predict
                y_pred = predict(model, X_test)

                # Evaluate
                fold_results = comprehensive_evaluation(y_pred, y_test)

                # Store results
                for (metric, value) in fold_results
                    if !haskey(cv_results[method_name], metric)
                        cv_results[method_name][metric] = []
                    end
                    push!(cv_results[method_name][metric], value)
                end

            catch e
                @warn "Method $method_name failed on fold $fold"
            end
        end
    end

    # Aggregate CV results
    aggregated_results = Dict()
    for method_name in keys(cv_results)
        aggregated_results[method_name] = Dict()
        for (metric, values) in cv_results[method_name]
            if isa(values[1], Vector)  # Per-cell-type metrics
                # Flatten and compute statistics
                all_values = vcat(values...)
                aggregated_results[method_name][metric * "_mean"] = mean(all_values)
                aggregated_results[method_name][metric * "_std"] = std(all_values)
            else  # Scalar metrics
                aggregated_results[method_name][metric * "_mean"] = mean(values)
                aggregated_results[method_name][metric * "_std"] = std(values)
            end
        end
    end

    return aggregated_results, cv_results
end

function generate_statistical_report(comparisons::Vector{ComparisonResult},
                                     output_file::String)
    """
    Generate a comprehensive statistical report
    """
    open(output_file, "w") do f
        write(f, "# Statistical Comparison Report\n\n")
        write(f, "## Significant Differences (α = 0.05 with correction)\n\n")

        significant_comparisons = filter(c -> c.significant, comparisons)

        if isempty(significant_comparisons)
            write(f, "No statistically significant differences found.\n\n")
        else
            write(f,
                  "| Method 1 | Method 2 | Metric | p-value | Corrected p-value | Effect Size | 95% CI |\n")
            write(f,
                  "|----------|----------|--------|---------|-------------------|-------------|--------|\n")

            for comp in significant_comparisons
                write(f, "| $(comp.method1) | $(comp.method2) | $(comp.metric) | ")
                write(f,
                      "$(round(comp.pvalue, digits=4)) | $(round(comp.corrected_pvalue, digits=4)) | ")
                write(f, "$(round(comp.effect_size, digits=3)) | ")
                write(f,
                      "($(round(comp.confidence_interval[1], digits=3)), $(round(comp.confidence_interval[2], digits=3))) |\n")
            end
        end

        write(f, "\n## All Comparisons\n\n")
        write(f,
              "| Method 1 | Method 2 | Metric | p-value | Corrected p-value | Effect Size | Significant |\n")
        write(f,
              "|----------|----------|--------|---------|-------------------|-------------|-------------|\n")

        for comp in comparisons
            write(f, "| $(comp.method1) | $(comp.method2) | $(comp.metric) | ")
            write(f,
                  "$(round(comp.pvalue, digits=4)) | $(round(comp.corrected_pvalue, digits=4)) | ")
            write(f,
                  "$(round(comp.effect_size, digits=3)) | $(comp.significant ? "✓" : "✗") |\n")
        end
    end

    return println("Statistical report saved to: $output_file")
end
