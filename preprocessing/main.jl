using Pkg
Pkg.activate(@__DIR__)

using DotEnv
DotEnv.load!()

required_envs = ["DATA_DIR", "R_SCRIPTS_PATH"]

for env in required_envs
    if !haskey(ENV, env)
        throw(ErrorException("Environment variable $env is not set."))
    end
end

@enum VerbosityLevel LevelOff = 0 LevelInfo = 1 LevelDebug = 2
verbosity_level = LevelInfo

# Read the data directory and list all the dataset to preprocessing
datasets = readdir(ENV["DATA_DIR"])
