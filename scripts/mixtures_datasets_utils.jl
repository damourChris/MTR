# Writing a YAML file to descibe the dataset 
# Format:
# DATASET_NAME:
#   title: Synthetic dataset of N samples. Derived from BASE_ESET_ID
#   id: BASE_PREFIX_DATASET_NUMBER
#   series:
#    - id: RUN_PREFIX_RUN_NUMBER
#      platform: GENERATION_METHOD
#      type: mixture
function generate_descriptor_file(samples::Int,
                                  base_eset_id::AbstractString,
                                  base_prefix::AbstractString,
                                  run_prefix::AbstractString,
                                  last_dataset_number::Int,
                                  num_datasets::Int)
    dataset_name = "Synthetic dataset of $samples samples. Derived from $base_eset_id"
    dataset_id = "$base_prefix$(lpad(last_dataset_number, 3, '0'))"
    series = Vector{Dict{AbstractString,AbstractString}}()
    for run_number in 1:num_datasets
        run_id = "$run_prefix$(lpad(run_number, 4, '0'))"
        push!(series, Dict("id" => run_id,
                           "platform" => "synthetic",
                           "type" => "mixture"))
    end

    descriptor = Dict(dataset_id => Dict("title" => dataset_name,
                                         "id" => dataset_id,
                                         "series" => series))

    return descriptor
end

function generate_synthethic_mixture_eset(base_eset::ExpressionSet;
                                          expression_method=:mean)::ExpressionSet

    # Check if the the required variables are defined
    @isdefined(cell_type_column) || error("cell_type_column is not defined")
    @isdefined(proportions_column) || error("proportions_column is not defined")
    @isdefined(decimals) || error("decimals is not defined")
    @isdefined(sample_id_prefix) || error("sample_id_prefix is not defined")
    @isdefined(cell_separator) || error("cell_separator is not defined")
    @isdefined(value_separator) || error("value_separator is not defined")
    @isdefined(samples) || error("samples is not defined")

    ref_cell_type_indices = Dict{String,Vector{Int}}()
    for cell_type in unique(phenotype_data(base_eset)[!, cell_type_column])
        # Find all the samples indicces for the cell type 
        ref_cell_type_indices[cell_type] = findall(==(cell_type),
                                                   phenotype_data(base_eset)[!,
                                                                             cell_type_column])
        if isempty(ref_cell_type_indices[cell_type])
            @warn "No samples found for cell type: $cell_type"
        end
    end

    cells_types = keys(ref_cell_type_indices)
    classes = length(cells_types)

    proportions = generate_proportions(classes; samples, decimals,
                                       id_prefix=sample_id_prefix)

    gxData = expression_values(Matrix, base_eset)

    # The newExpression will be the same as gxData but with fewer samples
    newExpression = zeros(size(gxData, 1), samples)
    # Initialize a array of strings that will hold the cell type and the proportion
    proportions_columns = Array{String}(undef, samples)

    # To get the new expression, lets reduce the original expression based on the deried methods
    # and the target proportions
    reduced_gxData = [calculate_gene_expressions(gxData[:,
                                                        ref_cell_type_indices[cell_type]],
                                                 expression_method)
                      for cell_type in cells_types]
    reduced_gxData = hcat(reduced_gxData...)

    # Now we can generate the new expression set
    for (sample_index, row) in enumerate(eachrow(proportions))
        for (cell_type_index, cell_type) in enumerate(cells_types)
            target_proportion = proportions[!, sample][cell_type_index]

            cell_type_indices = ref_cell_type_indices[cell_type]

            if length(cell_type_indices) > 1
                gene_exprs = reduced_gxData[:, cell_type_index]
                gx_ = vec(gene_exprs) .* target_proportion
                newExpression[:, sample_index] += gx_
            end
        end

        # Create the proporiton label 
        proportions_columns[sample_index] = create_proportion_label(proportions[!, sample],
                                                                    cells_types)
    end

    # 
    new_pData = DataFrame(; sample_names=names(proportions),
                          cell_type_proportion=proportions_columns)

    synthetic_eset = ExpressionSet(newExpression, new_pData, phenotype_data(base_eset),
                                   experiment_data(base_eset), annotation(base_eset))

    return synthetic_eset
end

function generate_numbers(N::Int, decimals::Int=8)
    # Generate N random numbers between 0 and 1
    random_numbers = rand(N)

    # Calculate the sum of these numbers
    total_sum = sum(random_numbers)

    # Scale the numbers so their sum equals 100
    scaled_numbers = (random_numbers ./ total_sum)

    # Round the numbers to the specified number of decimal places
    return round.(scaled_numbers, digits=decimals)
end

function generate_proportions(numclasses::Int;
                              samples::Int=100,
                              decimals::Int=8,
                              id_prefix="proportion_")
    # Generate random proportions for each class
    proportions = [generate_numbers(classes, decimals) for _ in 1:samples]
    proportions = mapreduce(permutedims, vcat, proportions)

    columns = [Symbol("$(id_prefix)$i") for i in 1:numclasses]

    return DataFrame(proportions, columns)
end

function create_proportion_label(proportions::Vector{Float64},
                                 cell_types)
    cell_type_proportions = []
    for (cell_type_index, cell_type) in enumerate(cell_types)
        target_proportion = proportions[cell_type_index]

        push!(cell_type_proportions,
              "$cell_type$value_separator$target_proportion$value_unit")
    end
    return join(cell_type_proportions, cell_separator)
end

function calculate_gene_expressions(cell_data, method::Symbol)
    if method == :sum
        return sum(cell_data; dims=2)
    elseif method == :mean
        return mean(cell_data; dims=2)
    else
        throw(ArgumentError("Unknown expression method: $method"))
    end
end

function save_synthetic_eset(eset::ExpressionSet, filename::AbstractString)
    return save(joinpath(output_dir, filename), Dict("eset" => eset))
end