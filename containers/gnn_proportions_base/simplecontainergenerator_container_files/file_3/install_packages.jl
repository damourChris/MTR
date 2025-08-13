import Pkg
Pkg.add(Pkg.Types.PackageSpec[Pkg.PackageSpec(; name = "CSV", ), Pkg.PackageSpec(; name = "CategoricalArrays", ), Pkg.PackageSpec(; name = "Comonicon", ), Pkg.PackageSpec(; name = "DataFrames", ), Pkg.PackageSpec(; name = "DotEnv", ), Pkg.PackageSpec(; name = "EnumX", ), Pkg.PackageSpec(; name = "ExpressionData", ), Pkg.PackageSpec(; name = "Flux", ), Pkg.PackageSpec(; name = "GraphNeuralNetworks", ), Pkg.PackageSpec(; name = "GraphRecipes", ), Pkg.PackageSpec(; name = "Graphs", ), Pkg.PackageSpec(; name = "HTTP", ), Pkg.PackageSpec(; name = "JLD2", ), Pkg.PackageSpec(; name = "JSON", ), Pkg.PackageSpec(; name = "LightXML", ), Pkg.PackageSpec(; name = "MLUtils", ), Pkg.PackageSpec(; name = "MetaGraphs", ), Pkg.PackageSpec(; name = "OntologyLookup", ), Pkg.PackageSpec(; name = "OpenSSL", ), Pkg.PackageSpec(; name = "Plots", ), Pkg.PackageSpec(; name = "Preferences", ), Pkg.PackageSpec(; name = "ProgressMeter", ), Pkg.PackageSpec(; name = "RCall", ), Pkg.PackageSpec(; name = "RDatasets", ), Pkg.PackageSpec(; name = "Requires", ), Pkg.PackageSpec(; name = "STRINGdb", ), Pkg.PackageSpec(; name = "TSne", ), Pkg.PackageSpec(; name = "YAML", )])
for name in ["CSV", "CategoricalArrays", "Comonicon", "DataFrames", "DotEnv", "EnumX", "ExpressionData", "Flux", "GraphNeuralNetworks", "GraphRecipes", "Graphs", "HTTP", "JLD2", "JSON", "LightXML", "MLUtils", "MetaGraphs", "OntologyLookup", "OpenSSL", "Plots", "Preferences", "ProgressMeter", "RCall", "RDatasets", "Requires", "STRINGdb", "TSne", "YAML"] # pkg_names_to_test
Pkg.add(name)
Pkg.test(name)
end
Pkg.add(collect(values(Pkg.Types.stdlibs())))
for (uuid, info) in Pkg.dependencies()
Pkg.add(info.name)
end
for (uuid, info) in Pkg.dependencies()
if info.name in ["CSV", "CategoricalArrays", "Comonicon", "DataFrames", "DotEnv", "EnumX", "ExpressionData", "Flux", "GraphNeuralNetworks", "GraphRecipes", "Graphs", "HTTP", "JLD2", "JSON", "LightXML", "MLUtils", "MetaGraphs", "OntologyLookup", "OpenSSL", "Plots", "Preferences", "ProgressMeter", "RCall", "RDatasets", "Requires", "STRINGdb", "TSne", "YAML"]
project_file = joinpath(info.source, "Project.toml")
test_project_file = joinpath(info.source, "test", "Project.toml")
if ispath(project_file)
project = Pkg.TOML.parsefile(project_file)
if haskey(project, "deps")
project_deps = project["deps"]
for entry in keys(project_deps)
Pkg.add(entry)
end
end
if haskey(project, "extras")
project_extras = project["extras"]
for entry in keys(project_extras)
Pkg.add(entry)
end
end
end
if ispath(test_project_file)
test_project = Pkg.TOML.parsefile(test_project_file)
if haskey(test_project, "deps")
test_project_deps = project["deps"]
for entry in keys(test_project_deps)
Pkg.add(entry)
end
end
end
end
end
for (uuid, info) in Pkg.dependencies()
Pkg.add(info.name)
end

