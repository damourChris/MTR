include("../../src/graphs/ontology_tree.jl")

using JLD2

### TIME FOR GRAPH NEURAL NETWORKS ###
using GraphNeuralNetworks
using MLUtils
using LightXML

include("./gnn_converrsion.jl")
include("./gnn_utils.jl")

using Flux
using Flux: onecold, onehotbatch, logitcrossentropy, jacobian
using Plots

using TSne
using Random
using Statistics

Random.seed!(17) # for reproducibility

# data_path = "/home/damourchris/MTR/experiments/v2/data/"
data_path = "/workspaces/MTR/experiments/v2/data"

sample_onto_trees_dir = joinpath(data_path, "mixture_graphs")
sample_onto_trees_files = readdir(sample_onto_trees_dir; join=true)

using OntologyTrees

# Read the sample_onto_trees with multiple threads
sample_onto_trees = Dict{String,OntologyTree}()
lock_obj = ReentrantLock()

function load_tree(file::String)
    data = load(file)["graph"]

    tree_key = split(split(basename(file), "proportion_")[2], ".jld2")[1]

    lock(lock_obj)
    try
        return sample_onto_trees[tree_key] = data
    finally
        unlock(lock_obj)
    end
end

# Spawn tasks to load files concurrently and load them in sample_onto_trees
tasks = [Threads.@spawn load_tree(file) for file in sample_onto_trees_files]

f_tree_file = sample_onto_trees_files[1]
graph_da = jldopen(f_tree_file, "r"; typemap=Dict("Main.OntologyTree" => OntologyTree))["graph"]
convert(OntologyTree, data["graph"])

methods(OntologyTree)

typeof(graph_da)

OntologyTree(graph_da.graph, graph_da.max_parent_limit, graph_da.required_terms,
             graph_da.root)
fieldnames(OntologyTree)
# Wait for all tasks to finish  
for task in tasks
    res = fetch(task)

    if res isa Exception
        @error res
    end

    if res isa OntologyTree
        @info "Loaded tree"
        sample_onto_trees[res.key] = res
    end
end

# Convert the OntologyTree to a GNNHeteroGrap

graphs_keys = keys(sample_onto_trees)

graphs = to_hetero_gnn.(values([graph
                                for (key, graph) in sample_onto_trees if key in graphs_keys]))

# Replace all the cell data in the graph with the initial proportion (100 at end and rest is 0)              
newgraphs = Vector{GNNHeteroGraph}()

for g in graphs
    new_data = [:cell => DataStore(;
                                   proportion=transpose(Float32.(vcat([repeat([0.0],
                                                                              g.num_nodes[:cell] -
                                                                              1),
                                                                       0.0]...)))),
                :gene => DataStore(;
                                   exprs=transpose(Float32.(hcat(g.ndata[:gene][:exprs]))))]
    newgraph = GNNHeteroGraph(g.graph;
                              ndata=new_data)
    push!(newgraphs, newgraph)
end

function replace_missing!(x::AbstractVector; value=0.0)
    for i in eachindex(x)
        if ismissing(x[i])
            x[i] = value
        end
    end
    return x
end

y = [Float32.(filter(g.ndata[:cell].proportion) do x
                  return !ismissing(x)
              end) * 100 for g in graphs]

y_1_flat = reduce(hcat, y)

length(graphs)

train_data, test_data = getobs(splitobs((newgraphs, y_1_flat); at=0.8, shuffle=true))

train_loader = DataLoader(train_data; shuffle=true, collate=true)
test_loader = DataLoader(test_data; shuffle=false, collate=true)
first(test_loader)[1].ndata[:cell][:proportion]
first(test_loader)[2]

function create_model(nin, nh, nout)
    return GNNChain(HeteroGraphConv((:gene, :to, :cell) => GraphConv(1 => 1, relu),
                                    (:cell, :to, :cell) => GraphConv(1 => 1, relu)),
                    GlobalPool(mean),
                    Dropout(0.5),
                    Dense(nh, nout))
    # return GNNChain(GCNConv(nin => nh, relu),
    #                 GCNConv(nh => nh, relu),
    #                 GCNConv(nh => nh),
    #                 GlobalPool(mean),
    #                 Dropout(0.5),
    #                 Dense(nh, nout))
end

test_g = first(newgraphs)
test_g.ndata[:gene]
test_g_y = (;
            cell=transpose(Float32.(vcat([repeat([0.0], test_g.num_nodes[:cell] - 1),
                                          100.0]...))),
            gene=transpose(Float32.(hcat(test_g.ndata[:gene][:exprs]))))

size(test_g_y[:cell], ndims(test_g_y[:cell]))

test_g_y[:cell]

layer = HeteroGraphConv((:gene, :to, :cell) => GATConv(1 => 1, relu),
                        (:cell, :to, :cell) => GATConv(1 => 1, relu));

chain = HeteroGraphConv((:gene, :to, :cell) => GraphConv(1 => 1, relu),
                        (:cell, :to, :cell) => GraphConv(1 => 1, relu))

test_model_fn = layers(test_g)

test_g_y[:cell]
test_model_fn[:cell]

for (g, y) in train_loader
    @info "Graph and target"
    @info g
    @info vec(y)
    break
end

function eval_loss_accuracy(model, data_loader, device)
    loss = 0.0
    acc = 0.0
    ntot = 0
    for (g, y) in data_loader
        # g, y = device(MLUtils.batch(g)), device(y)
        n = length(y)
        x_data = NamedTuple([k => v[sym]
                             for ((k, v), sym) in
                                 zip(g.ndata, [:exprs, :proportion])])
        ŷ = model(g, x_data)

        loss += Flux.crossentropy(ŷ, y) * n
        acc += mean((ŷ .> 0) .== y) * n
        ntot += n
    end
    return (loss=round(loss / ntot; digits=4),
            acc=round(acc * 100 / ntot; digits=2))
end

function train!(model; epochs=200, η=1e-2, infotime=10)
    # device = Flux.gpu # uncomment this for GPU training
    device = Flux.cpu
    model = device(model)
    opt = Flux.setup(Adam(η), model)

    function report(epoch)
        train = eval_loss_accuracy(model, train_loader, device)
        test = eval_loss_accuracy(model, test_loader, device)
        @info (; epoch, train, test)
    end

    report(0)
    for epoch in 1:epochs
        for (g, y) in train_loader
            # g, y = device(MLUtils.batch(g)), device(y)
            x_data = NamedTuple([k => v[sym]
                                 for ((k, v), sym) in
                                     zip(g.ndata, [:exprs, :proportion])])
            grad = Flux.gradient(model) do model
                ŷ = model(g, x_data)
                return Flux.crossentropy(ŷ, y)
            end

            Flux.update!(opt, model, grad[1])
        end
        epoch % infotime == 0 && report(epoch)
    end
end

begin
    struct HeteroCellGNN
        layers::NamedTuple
    end

    Flux.@layer :expand HeteroCellGNN

    function HeteroCellGNN(hidden_channels::Int)
        hidden1 = HeteroGraphConv((:gene, :to, :cell) => SAGEConv(1 => hidden_channels,
                                                                  tanh;
                                                                  bias=false),
                                  (:cell, :to, :cell) => SAGEConv(1 => hidden_channels,
                                                                  tanh;
                                                                  bias=false))
        hidden2 = HeteroGraphConv((:cell, :to, :cell) => SAGEConv(hidden_channels => hidden_channels,
                                                                  tanh;
                                                                  bias=false))
        output = Dense(hidden_channels, 1, relu; bias=false)
        return HeteroCellGNN((; hidden1, hidden2, output))
    end

    function (model::HeteroCellGNN)(g::GNNHeteroGraph, x_data)
        l = model.layers

        x = l.hidden1(g, x_data)
        x = l.hidden2(g, (; cell=x[:cell]))
        # @info size(x[:cell])
        # @info size(x_data[:cell])

        x = l.output(x[:cell])
        # x = permutedims(relu(x))
        x = relu(x)
        return x
    end
end

begin
    mdl = HeteroCellGNN(25)
    train!(mdl; epochs=2000, η=1e-4)
end

# A function to find the vertice with more than one edeg
function get_vertices_with_more_than_one_edge(graph::MetaDiGraph)
    vertices = Set{Int}()
    record = Dict{Int,Int}()
    # Make a record of all ocurrence of each vertex in the graph
    for edge in edges(graph)
        (s, d) = src(edge), dst(edge)

        if haskey(record, s)
            record[s] += 1
        else
            record[s] = 1
        end
        if haskey(record, d)
            record[d] += 1
        else
            record[d] = 1
        end
    end

    # Find the vertices with more than one edge
    for (k, v) in record
        if v > 2
            push!(vertices, k)
        end
    end
    return vertices
end

indices_to_test_weird_thing = get_vertices_with_more_than_one_edge(first(sample_onto_trees)[2].graph)

using Plots
y[1]
y_test = mdl(test_g, test_x_data)
vec(y_test)[collect(indices_to_test_weird_thing)]

plot(y[1]; seriestype=:scatter, markersize=2, label="Predicted vs True", marker=:square)
plot!(y_test; seriestype=:scatter, markersize=2, label="Predicted vs True", marker=:circle)
test_x_data = NamedTuple([k => v[sym]
                          for ((k, v), sym) in
                              zip(test_g.ndata, [:exprs, :proportion])])

logitcrossentropy(mdl(test_g), y[1])

unique(y_test)

model = HeteroCellGNN(10)
