# # Create a julia config startup file 
# touch ~/.julia/config/startup.jl

# # Add the contents of the julia config file to the startup.jl file
# cat /workspaces/MTR/.devcontainer/startup.jl >> ~/.julia/config/startup.jl

julia 'using Pkg; Pkg.Registry.add(RegistrySpec(url="https://github.com/damourchris/SysBioRegistry.jl.git"))'