module Utils

function run_r_script(script_path::String; verbose::Bool=false)
    # Assuming Rscript is in the system PATH
    rscript_command = "Rscript"

    if verbose
        println("Running R script: $script_path")
    end

    # Execute the R script using the system's Rscript command
    # Redirect the output to a log file
    run(`$rscript_command $script_path `)
end

function run_preprocessing(dataset::String; base_path::String="data/preprocessing", verbose::Bool=false)
    r_script_path = joinpath(base_path, dataset, "main.R")
    run_r_script(r_script_path)
end

export run_preprocessing, run_r_script

end # module