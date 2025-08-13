include("../../src/MTR.jl")
include("../../src/graphs/ontology_tree.jl")

using .MTR
using JLD2

### TIME FOR GRAPH NEURAL NETWORKS ###
using GraphNeuralNetworks
using MLUtils
using LightXML

include("gnn_converrsion.jl")
include("gnn_utils.jl")

using Flux
using Flux: onecold, onehotbatch, logitcrossentropy, jacobian
using Plots

using TSne
using Random
using Statistics

Random.seed!(42) # for reproducibility

data_path = ENV["DATA_DIR"]

sample_onto_trees_dir = joinpath(data_path, "sample_onto_trees")
sample_onto_trees_files = readdir(sample_onto_trees_dir; join=true)
sample_onto_trees = merge([Dict(split(basename(file), "_onto_tree.")[1] => load(file)["onto_tree"])
                           for file in sample_onto_trees_files]...)

graphs_keys = filter(collect(keys(sample_onto_trees))) do x
    return contains(x, "GSE22886-GPL96_GSE65136-GPL10558")
end

graphs = to_hetero_gnn.(values([graph
                                for (key, graph) in sample_onto_trees if key in graphs_keys]))

y = [Float64.(filter(g.ndata[:cell].proportion) do x
                  return !ismissing(x)
              end) for g in graphs]

function replace_missing!(x::AbstractVector; value=0.0)
    for i in eachindex(x)
        if ismissing(x[i])
            x[i] = value
        end
    end
    return x
end

y_1_flat = reduce(hcat, y)

length(graphs)

train_data, test_data = getobs(splitobs((graphs, y_1_flat); at=0.8, shuffle=true))

train_loader = DataLoader(train_data; shuffle=true, collate=true)
test_loader = DataLoader(test_data; shuffle=false, collate=true)

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

test_g = first(graphs)
test_g
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
    @info y
    break
end

function eval_loss_accuracy(model, data_loader, device)
    loss = 0.0
    acc = 0.0
    ntot = 0
    for (g, y) in data_loader
        # g, y = device(MLUtils.batch(g)), device(y)
        n = length(y)
        # y_ = (;
        #       cell=transpose(Float32.(vcat([repeat([0.0], g.num_nodes[:cell] - 1),
        #                                     100.0]...))),
        #       gene=transpose(Float32.(hcat(g.ndata[:gene][:exprs]))))
        ŷ = model(g)

        loss += logitcrossentropy(ŷ, y) * n
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
    opt = Flux.setup(Adam(1e-3), model)

    function report(epoch)
        train = eval_loss_accuracy(model, train_loader, device)
        test = eval_loss_accuracy(model, test_loader, device)
        @info (; epoch, train, test)
    end

    report(0)
    for epoch in 1:epochs
        for (g, y) in train_loader
            # g, y = device(MLUtils.batch(g)), device(y)
            grad = Flux.gradient(model) do model
                ŷ = model(g)
                return logitcrossentropy(ŷ, y)
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

    function HeteroCellGNN(hidden_channels; drop_rate=0.5)
        layers = (hidden=HeteroGraphConv((:gene, :to, :cell) => GraphConv(1 => hidden_channels),
                                         (:cell, :to, :cell) => GraphConv(1 => hidden_channels)),
                  #   drop=Dropout(drop_rate),
                  output=Dense(hidden_channels, 1))
        return HeteroCellGNN(layers)
    end

    function (model::HeteroCellGNN)(g::GNNHeteroGraph)
        l = model.layers
        x_data = (;
                  cell=transpose(Float32.(hcat(g.ndata[:cell][:proportion]))),
                  gene=transpose(Float32.(hcat(g.ndata[:gene][:exprs]))))
        x = l.hidden(g, x_data)
        # x = l.drop(x[:cell])
        x = l.output(x[:cell])
        x = softmax(permutedims(x))
        return x
    end
end

begin
    mdl = HeteroCellGNN(20)
    train!(mdl; epochs=200)
end

y[1]

logitcrossentropy(mdl(test_g), y[1])

y_test = mdl(test_g)

unique(y)

model = HeteroCellGNN(10)
