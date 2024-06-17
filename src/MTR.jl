module MTR

include("./utils/utils.jl")
using .Utils

include("./preprocessing/main.jl")
using .Preprocessing

function __init__()
    using Requires
    @requires DotEnv = "4dc1fcf4-5e3b-5448-94ab-0c38ec0385c1" begin
        @info "Loading environment variables from .env file"
        using DotEnv
        DotEnv.load!()
    end

end

end