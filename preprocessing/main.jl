module Preprocessing

function __init__()
    # Check if the required environment variables are set
    required_envs_vars = ["CONDA_PREFIX", "R_DIR", "DATA_PATH"]

    for env in required_envs_vars
        if !haskey(ENV, env)
            throw(ErrorException("Environment variable $env is not set. Please read the README.md file for more information."))
        end
    end

end


end # module