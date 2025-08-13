using Dates
using EnumX
using Logging

@enumx ExperimentStatus begin
    PENDING
    STARTED
    RUNNING
    COMPLETED
    FAILED
end

@enumx StageType begin
    DATA_PREPROCESSING
    GRAPH_CREATION
    MODEL_TRAINING
    MODEL_EVALUATION
    POST_PROCESSING
end

@enumx DatasetType begin
    REFERENCE
    MIXTURE
end

struct Parameter
    name::String
    value::String
    description::String
end

struct Stage{T<:StageType}
    stage_name::String
    description::String
    stage_functions::Vector{Function}
    type::T
end

struct Result
    result_name::String
    description::String
    filename::String
end

struct Log
    message::String
    level::LogLevel
    timestamp::DateTime
end

struct Dataset{T<:DatasetType}
    name::String
    description::String
    filename::String
    type::T
    synthetic::Bool
end

struct Experiment
    name::String
    description::String
    date_started::DateTime
    last_updated::DateTime
    raw_data_location::String
    datasets::Vector{Datasets}
    parameters::Vector{Parameter}
    stages::Vector{Stage}
    results::Vector{Result}
    notes::Vector{String}
    logs::Vector{Log}
    status::ExperimentStatus
end

function run!(exp::Experiment)::Experiment
    update_status!(exp, STARTED)
    write_log!(exp, "Experiment started")

    for stage in exp.stages
        write_log!(exp, "Running stage: $(stage.stage_name)")
        # Run the stage
        if stage.type == DATA_PREPROCESSING
            run!(exp, stage)
        end
    end
end

function run(stage::Stage{DATA_PREPROCESSING}, raw_data::Any)::Any
    for func in stage.stage_functions
        raw_data = func(raw_data)
    end
    return raw_data
end

function run(stage::Stage{GRAPH_CREATION}, data)::Any
    write_log!(stage, "Running stage: $(stage.stage_name)")
    for func in stage.stage_functions
        data = func(data)
    end
    return data
end

function get_datasets_ids(exp::Experiment)::Any
    raw_data = load_data(exp.raw_data_location)
    return keys(raw_data)
end

function run!(exp::Experiment, stage::Stage{DATA_PREPROCESSING})::Nothing
    write_log!(stage, "Running stage: $(stage.stage_name)")

    # Load the raw data 
    raw_data = load_data(exp.raw_data_location)

    write_log!(stage, "Using datasets: $(keys(raw_data))")

    # Execute the stage
    # Update the logs
    # Update the status

    return nothing
end

function update_status!(exp::Experiment, status::ExperimentStatus)::Nothing
    return exp.status = status
end

function write_logs!(exp::Experiment, logs::Vector{Log})::Nothing
    for log in logs
        push!(exp.logs, log)
    end
end

function write_log!(exp::Experiment, message::String;
                    level::LogLevel=LogLevel.DEBUG)::Nothing
    log = Log(message, level, now())
    return push!(exp.logs, log)
end