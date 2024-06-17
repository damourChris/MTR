# Execute the R script to preprocess the data
function get_preprocessing_env()
    conda_prefix = ENV["CONDA_PREFIX"]
    return "$conda_prefix/envs/preprocessing/"
end

function get_preprocessing_script()
    r_dir = ENV["R_DIR"]
    return "$r_dir/preprocessing.R"
end
