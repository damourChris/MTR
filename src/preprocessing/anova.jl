# using DataFrames
# using Statistics
# using MultipleTesting

# const ANOVA_PVALUE_THRESHOLD = 0.001

# function identify_marker_genes(expression_matrix::Matrix{Float64},
#                                cell_types::Vector{String})::Dict{String,Set{Int}}
#     marker_genes = Dict(ct => Set{Int}() for ct in unique(cell_types))

#     # Collect ANOVA results for p-value adjustment
#     anova_pvalues = Float64[]

#     for gene in 1:size(expression_matrix, 1)
#         gene_expression = expression_matrix[gene, :]

#         gene

#         # Perform one-way ANOVA and collect p-values
#         formula = @eval @formula(cell_type ~ $(gene))

#         if pvalue(anova_result) < ANOVA_PVALUE_THRESHOLD
#             tukey_result = TukeyHSD(gene_expression, cell_types)

#             for (i, ct) in enumerate(unique(cell_types))
#                 if all(tukey_result.pvalues[i, :] .< 0.001) &&
#                    all(tukey_result.pvalues[:, i] .< 0.001)
#                     push!(marker_genes[ct], gene)
#                     break
#                 end
#             end
#         end
#     end

#     # Adjust p-values for multiple testing
#     adjusted_pvalues = adjust(anova_pvalues, BenjaminiHochberg())

#     # Filter marker genes based on adjusted p-values
#     filtered_marker_genes = Dict(ct => Set{Int}() for ct in keys(marker_genes))
#     for (ct, genes) in marker_genes
#         for gene in genes
#             if adjusted_pvalues[gene] < 0.001
#                 push!(filtered_marker_genes[ct], gene)
#             end
#         end
#     end

#     # Ensure disjoint sets
#     all_markers = union(values(filtered_marker_genes)...)
#     for (ct, genes) in filtered_marker_genes
#         filtered_marker_genes[ct] = setdiff(genes, setdiff(all_markers, genes))
#     end

#     return filtered_marker_genes
# end

# identify_marker_genes(rand(100, 10), ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"])