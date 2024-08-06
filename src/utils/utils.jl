module Utils

include(joinpath(@__DIR__, "preprocessing.jl"))
export preprocess_data

include(joinpath(@__DIR__, "custom_conversion.jl"))
export
       ExpressionSet,
       fData,
       fData!,
       pData,
       pData!,
       add_pheno_column!,
       exprs,
       featureNames,
       sampleNames,
       save_to_r_eset,
       load_eset

end