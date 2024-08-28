using DataFrames
using RCall
import RCall.rcopy

# Julia equivalent of the R ExpressionSet class from the Biobase package
struct ExpressionSet
    exprs::Matrix{Float64}
    phenoData::DataFrame
    featureData::DataFrame
    # experimentData::DataFrame # Experiment details
end

function fData(eset::ExpressionSet)::DataFrame
    return eset.featureData
end

function fData!(eset::ExpressionSet, df::DataFrame)::ExpressionSet
    eset.featureData = df
    return eset
end

function pData(eset::ExpressionSet)::DataFrame
    return eset.phenoData
end

"""
    pData!(eset::ExpressionSet, df::DataFrame)::ExpressionSet

Set the phenoData of an ExpressionSet object to the given DataFrame.

# Arguments
- `eset::ExpressionSet`: The ExpressionSet object to modify.
- `df::DataFrame`: The DataFrame containing the phenoData.

# Returns
- `eset::ExpressionSet`: The modified ExpressionSet object.

"""
function pData!(eset::ExpressionSet, df::DataFrame)::ExpressionSet
    eset.phenoData = df
    return eset
end

# A function to add a new column to the phenoData of an ExpressionSet object
function add_pheno_column!(eset::ExpressionSet, col_name::AbstractString,
                           col_data)::ExpressionSet
    eset.phenoData[!, col_name] = col_data
    return eset
end

function exprs(eset::ExpressionSet)::DataFrame
    df = DataFrame(eset.exprs, sampleNames(eset))
    df[!, :feature_names] = featureNames(eset)

    # Put feature_names as the first column
    select!(df, circshift(names(df), 1))
    return df
end

function exprs(::Type{Matrix}, eset::ExpressionSet)::Matrix
    return eset.exprs
end

function featureNames(eset::ExpressionSet)::Vector{AbstractString}
    data = fData(eset)
    return data[!, :feature_names]
end

function sampleNames(eset::ExpressionSet)::Vector{AbstractString}
    data = pData(eset)
    return data[!, :sample_names]
end

function rcopy(::Type{ExpressionSet}, s::Ptr{S4Sxp})
    exprs = rcopy(Matrix{Float64}, s[:assayData][:exprs])

    phenoData = rcopy(DataFrame, s[:phenoData][:data])

    R"sample_names <- Biobase::sampleNames($s) "

    sample_names = @rget sample_names
    phenoData[!, :sample_names] = sample_names

    featureData = rcopy(DataFrame, s[:featureData][:data])
    R"feature_names <- Biobase::featureNames($s) "
    feature_names = @rget feature_names
    featureData[!, :feature_names] = feature_names

    # experimentData = rcopy(DataFrame, s[:experimentData]) 
    return ExpressionSet(exprs, phenoData, featureData)
end