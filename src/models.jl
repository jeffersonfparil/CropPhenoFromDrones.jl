mutable struct Model
    trait_name::String
    y::Vector{Union{Missing,Float64}}
    feature_names::Vector{String}
    X::Matrix{Float64}
    idx_training::Vector{Int64}
    idx_validation::Vector{Int64}
    β::Union{Nothing,Vector{Float64},Matrix{Float64}} # add types for when we have non-linear models
    ŷ_training::Union{Nothing,Vector{Float64}}
    R²_training::Union{Nothing,Float64}
    ρ_training::Union{Nothing,Float64}
    ŷ_validation::Union{Nothing,Vector{Float64}}
    R²_validation::Union{Nothing,Float64}
    ρ_validation::Union{Nothing,Float64}
    function Model(data::Data; trait_name::Union{Nothing,String}=nothing, cor_max::Float64=0.95)::Model
        # data = simulate_data(); trait_name = nothing; cor_max::Float64=0.95
        df_traits, df_features = extract_XY(data, cor_max=cor_max)
        trait_name = if isnothing(trait_name)
            names(df_traits)[2] # we are sure we have at least 1 trait because we perform check_dimensions(data) within extract_XY(data)
        else
            trait_name
        end
        y::Vector{Union{Missing,Float64}} = if trait_name ∉ names(df_traits)
            throw(ErrorException("Trait \"$trait_name\" is absent in df_traits ($(names(df_traits))))"))
        else
            select(df_traits, trait_name)[:, 1]
        end
        new(
            trait_name,
            y,
            names(select(df_features, Not(:id))),
            Matrix{Float64}(select(df_features, Not(:id))),
            findall(.!ismissing.(y)),
            findall(ismissing.(y)),
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
            nothing,
        )
    end
end

function check_model(model::Model)::Nothing
    if length(model.idx_training) < 3
        throw(ErrorException("We cannot proceed with less than 3 observations for training"))
    end
    if (minimum(model.idx_training) < 1) || (maximum(model.idx_training) > length(model.y))
        throw(ErrorException("Training set out-of-bounds: min=$(minimum(model.idx_training)), max=$(maximum(model.idx_training)); with n=$(length(model.y))"))
    end
    idx_training_missing_y = findall([ismissing(model.y[x]) for x in model.idx_training])
    if length(idx_training_missing_y) > 0
        throw(ErrorException("Missing trait values in training set, see the folowing indices: $idx_training_missing_y"))
    end
    if length(model.idx_validation) > 0
        if (minimum(model.idx_validation) < 1) || (maximum(model.idx_validation) > length(model.y))
            throw(ErrorException("Validation set out-of-bounds: min=$(minimum(model.idx_validation)), max=$(maximum(model.idx_validation)); with n=$(length(model.y))"))
        end
    end
    nothing
end

# model = Model(simulate_data()); n = length(model.y); idx = sample(1:n, n, replace=false); model.idx_training = idx[1:Int64(round(0.75*n))]; model.idx_validation = idx[(Int64(round(0.75*n))+1):end]
# @assert isnothing(model.R²_training) && isnothing(model.R²_validation)
# @assert isnothing(model.ρ_training) && isnothing(model.ρ_validation)
# @assert isnothing(model.ŷ_training) && isnothing(model.ŷ_validation)
# model_ols!(model)
# @assert model.R²_training >= model.R²_validation
# @assert model.ρ_training >= model.ρ_validation
# @assert length(model.ŷ_training) > 0 && length(model.ŷ_validation) > 0
function model_ols!(model::Model)::Nothing
    # model = Model(simulate_data()); n = length(model.y); model.idx_training = collect(1:2:n); model.idx_validation = collect(2:2:n)
    check_model(model)
    n_training = length(model.idx_training)
    X_training = Float64.(hcat(ones(n_training), model.X[model.idx_training, :]))
    y_training = Float64.(model.y[model.idx_training])
    model.β = pinv(X_training' * X_training) * X_training' * y_training
    # model.β = X_training \ y_training
    model.ŷ_training = X_training * model.β
    model.R²_training = 1.00 - (sum((y_training - model.ŷ_training) .^ 2) / sum((y_training .- mean(y_training)) .^ 2))
    model.ρ_training = cor(y_training, model.ŷ_training)
    if length(model.idx_validation) > 0
        n_validation = length(model.idx_validation)
        X_validation = Float64.(hcat(ones(n_validation), model.X[model.idx_validation, :]))
        model.ŷ_validation = X_validation * model.β
        idx_validation_not_missing_y = findall([!ismissing(model.y[x]) for x in model.idx_validation])
        if length(idx_validation_not_missing_y) > 0
            y_validation = Float64.(model.y[idx_validation_not_missing_y])
            model.R²_validation = 1.00 - (sum((y_validation - model.ŷ_validation) .^ 2) / sum((y_validation .- mean(y_validation)) .^ 2))
            model.ρ_validation = cor(y_validation, model.ŷ_validation)
        end
    end
    nothing
end

# model = Model(simulate_data()); n = length(model.y); idx = sample(1:n, n, replace=false); model.idx_training = idx[1:Int64(round(0.75*n))]; model.idx_validation = idx[(Int64(round(0.75*n))+1):end]
# @assert isnothing(model.R²_training) && isnothing(model.R²_validation)
# @assert isnothing(model.ρ_training) && isnothing(model.ρ_validation)
# @assert isnothing(model.ŷ_training) && isnothing(model.ŷ_validation)
# model_ridge!(model)
# @assert model.R²_training >= model.R²_validation
# @assert model.ρ_training >= model.ρ_validation
# @assert length(model.ŷ_training) > 0 && length(model.ŷ_validation) > 0
function model_ridge!(model::Model; n_reps_2fcv::Int64=10, seed::Int64=42)::Nothing
    # model = Model(simulate_data()); n = length(model.y); model.idx_training = collect(1:2:n); model.idx_validation = collect(2:2:n); n_reps_2fcv::Int64=10; seed::Int64=42
    check_model(model)
    Random.seed!(seed)
    n_training = length(model.idx_training)
    X_training = Float64.(hcat(ones(n_training), model.X[model.idx_training, :]))
    y_training = Float64.(model.y[model.idx_training])
    λs::Vector{Float64} = [10^x for x in -2.0:0.1:2.0]
    Cs::Vector{Float64} = []
    for λ in λs
        # λ = λs[end]
        vλ = repeat([λ], size(X_training, 2))
        vλ[1] = 0.0 # No shrinkage for the intercept
        C_tmp::Vector{Float64} = []
        for r in 1:n_reps_2fcv
            idx1, idx2 = let
                idx = sample(1:n_training, n_training, replace=false)
                m = Int64(round(n_training / 2))
                (idx[1:m], idx[(m+1):end])
            end
            X1 = X_training[idx1, :]
            y1 = y_training[idx1]
            X2 = X_training[idx2, :]
            y2 = y_training[idx2]
            b = pinv((X1' * X1) .+ vλ) * X1' * y1
            C = sum((y2 .- (X2 * b)) .^ 2) + (λ * (b' * b)) # L2 cost
            push!(C_tmp, C)
        end
        push!(Cs, mean(C_tmp))
    end
    λ = λs[argmin(Cs)]
    # fig = CairoMakie.plot(λs, Cs); CairoMakie.save("test.png", fig)
    model.β = let
        vλ = repeat([λ], size(X_training, 2))
        vλ[1] = 0.0 # No shrinkage for the intercept
        pinv((X_training' * X_training) .+ vλ) * X_training' * y_training
    end
    model.ŷ_training = X_training * model.β
    model.R²_training = 1.00 - (sum((y_training - model.ŷ_training) .^ 2) / sum((y_training .- mean(y_training)) .^ 2))
    model.ρ_training = cor(y_training, model.ŷ_training)
    if length(model.idx_validation) > 0
        n_validation = length(model.idx_validation)
        X_validation = Float64.(hcat(ones(n_validation), model.X[model.idx_validation, :]))
        model.ŷ_validation = X_validation * model.β
        idx_validation_not_missing_y = findall([!ismissing(model.y[x]) for x in model.idx_validation])
        if length(idx_validation_not_missing_y) > 0
            y_validation = Float64.(model.y[idx_validation_not_missing_y])
            model.R²_validation = 1.00 - (sum((y_validation - model.ŷ_validation) .^ 2) / sum((y_validation .- mean(y_validation)) .^ 2))
            model.ρ_validation = cor(y_validation, model.ŷ_validation)
        end
    end
    nothing
end

# model = Model(simulate_data()); n = length(model.y); idx = sample(1:n, n, replace=false); model.idx_training = idx[1:Int64(round(0.75*n))]; model.idx_validation = idx[(Int64(round(0.75*n))+1):end]
# @assert isnothing(model.R²_training) && isnothing(model.R²_validation)
# @assert isnothing(model.ρ_training) && isnothing(model.ρ_validation)
# @assert isnothing(model.ŷ_training) && isnothing(model.ŷ_validation)
# model_bayesg!(model)
# @assert model.R²_training >= model.R²_validation
# @assert model.ρ_training >= model.ρ_validation
# @assert length(model.ŷ_training) > 0 && length(model.ŷ_validation) > 0
function model_bayesg!(
    model::Model;
    n_iterations::Int64=10_000,
    n_burnin::Int64=1_000,
    verbose::Bool=false,
    seed::Int64=42,
)::Nothing
    # model = Model(simulate_data()); n = length(model.y); model.idx_training = collect(1:2:n); model.idx_validation = collect(2:2:n); n_iterations::Int64 = 10_000; n_burnin::Int64 = 1_000; verbose::Bool=false; seed::Int64=42
    check_model(model)
    rng::TaskLocalRNG = Random.seed!(seed)
    Turing.@model function turing_bayesG(X_no_int, y)
        # Set variance prior.
        σ² ~ Distributions.Exponential(1.0 / std(y))
        # σ² ~ truncated(Normal(init["σ²"], 1.0); lower=0)
        # Set intercept prior.
        intercept ~ Turing.Flat()
        # intercept ~ Distributions.Normal(init["b0"], 1.0)
        # Set the priors on our coefficients.
        # p = size(X_no_int, 2)
        coefficients ~ Distributions.MvNormal(zeros(size(X_no_int, 2)), I)
        # Calculate all the mu terms.
        mu = intercept .+ X_no_int * coefficients
        # Return the distrbution of the response variable, from which the likelihood will be derived
        return y ~ Distributions.MvNormal(mu, σ² * I)
    end
    X_training = Float64.(model.X[model.idx_training, :])
    y_training = Float64.(model.y[model.idx_training])
    turing_model = turing_bayesG(X_training, y_training)
    # We use compile=true in AutoReverseDiff() because we do not have any if-statements in our Turing turing_model below
    chain = Turing.sample(
        rng,
        turing_model,
        NUTS(
            n_burnin,
            0.65,
            max_depth=5,
            Δ_max=1000.0,
            init_ϵ=0.2;
            adtype=AutoReverseDiff(compile=true)
        ),
        n_iterations,
        progress=verbose,
    )
    # Use the mean parameter values after 150 burn-in iterations
    θ = Turing.get_params(chain[(n_burnin+1):end, :, :])
    model.β = vcat(mean(θ.intercept), mean(stack(θ.coefficients, dims=1)[:, :, 1], dims=2)[:, 1])
    model.ŷ_training = model.β[1] .+ X_training * model.β[2:end]
    model.R²_training = 1.00 - (sum((y_training - model.ŷ_training) .^ 2) / sum((y_training .- mean(y_training)) .^ 2))
    model.ρ_training = cor(y_training, model.ŷ_training)
    if length(model.idx_validation) > 0
        X_validation = Float64.(model.X[model.idx_validation, :])
        model.ŷ_validation = model.β[1] .+ X_validation * model.β[2:end]
        idx_validation_not_missing_y = findall([!ismissing(model.y[x]) for x in model.idx_validation])
        if length(idx_validation_not_missing_y) > 0
            y_validation = Float64.(model.y[idx_validation_not_missing_y])
            model.R²_validation = 1.00 - (sum((y_validation - model.ŷ_validation) .^ 2) / sum((y_validation .- mean(y_validation)) .^ 2))
            model.ρ_validation = cor(y_validation, model.ŷ_validation)
        end
    end
    nothing
end