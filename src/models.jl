mutable struct Model
    # TODO
    B̂::Union{Nothing,Matrix{Float64}} # linear models, i.e. ols, ridge, lasso
    trait_names::Vector{String}
    feature_names::Vector{String}
end

function model_ols(; df_traits::DataFrame, df_features::DataFrame)
    # df_traits_full, df_features = extract_XY(simulate_data())
    # idx_training = sort(sample(collect(1:nrow(df_traits)), Int64(ceil(0.75*nrow(df_traits))), replace=false))
    # y_tmp::Vector{Union{Missing,Float64}} = repeat([missing], nrow(df_traits_full))
    # df_traits = DataFrame(id=df_traits_full.id, trait_1=y_tmp)
    # df_traits.trait_1[idx_training] = df_traits_full.trait_1[idx_training]
    if df_traits.id != df_features.id
        throw(ErrorException("The traits and features data frames have inconsistent ids."))
    end
    ids = deepcopy(df_traits.id)
    select!(df_traits, Not(:id))
    select!(df_features, Not(:id))
    trait_names = names(df_traits)
    features_names = names(df_features)
    F = Matrix(df_features)
    for trait in trait_names
        # trait = trait_names[1]
        y_tmp = df_traits[!, trait]
        idx_no_missing = findall(.!ismissing.(y_tmp))
        y = Float64.(y_tmp[idx_no_missing])
        X = Float64.(F[idx_no_missing, :])
        if length(y) < 3
            throw(ErrorException("Number of non-missing trait values is less than 3"))
        end
        n = length(y)
        b_hat = hcat(ones(n), X) \ y
        y_pred::Vector{Float64} = hcat(ones(n), X) * b_hat
        cor(y, y_pred)

        idx_validation = findall(ismissing.(y_tmp))
        y_validation = df_traits_full[!, trait][idx_validation]
        y_pred = hcat(ones(length(y_validation)), F[idx_validation, :]) * b_hat
        cor(y_validation, y_pred)

        fig = CairoMakie.plot(y, y_pred)
        CairoMakie.save("test.png", fig)
    end
    # TODO
    nothing
end

# using Turing, ReverseDiff
# Turing.@model function turing_bayesG(X, y)
#     # Set variance prior.
#     σ² ~ Distributions.Exponential(1.0 / std(y))
#     # σ² ~ truncated(Normal(init["σ²"], 1.0); lower=0)
#     # Set intercept prior.
#     intercept ~ Turing.Flat()
#     # intercept ~ Distributions.Normal(init["b0"], 1.0)
#     # Set the priors on our coefficients.
#     # p = size(X, 2)
#     coefficients ~ Distributions.MvNormal(zeros(size(X, 2)), I)
#     # Calculate all the mu terms.
#     mu = intercept .+ X * coefficients
#     # Return the distrbution of the response variable, from which the likelihood will be derived
#     return y ~ Distributions.MvNormal(mu, σ² * I)
# end

# df_traits, df_features = extract_XY(simulate_data())
# if df_traits.id != df_features.id
#     throw(ErrorException("The traits and features data frames have inconsistent ids."))
# end
# ids = deepcopy(df_traits.id)
# select!(df_traits, Not(:id))
# select!(df_features, Not(:id))
# trait_names = names(df_traits)
# features_names = names(df_features)
# y = Float64.(Matrix(df_traits)[:, 1])
# X = Float64.(Matrix(df_features))
# # Fit
# model = turing_bayesG(X, y)
# # We use compile=true in AutoReverseDiff() because we do not have any if-statements in our Turing model below
# rng::TaskLocalRNG = Random.seed!(123)
# niter::Int64 = 10_000
# nburnin::Int64 = 1_000
# @time chain = Turing.sample(rng, model, NUTS(nburnin, 0.65, max_depth=5, Δ_max=1000.0, init_ϵ=0.2; adtype=AutoReverseDiff(compile=true)), niter - nburnin, progress=true);
# # @time chain = Turing.sample(rng, model, HMC(0.05, 10; adtype=AutoReverseDiff(compile=true)), niter, progress=true);
# fig = CairoMakie.hist(chain[:σ²].data[:, 1])
# CairoMakie.save("test.png", fig)
# # Use the mean parameter values after 150 burn-in iterations
# params = Turing.get_params(chain[(nburnin+1):end, :, :]);
# b_hat = vcat(mean(params.intercept), mean(stack(params.coefficients, dims=1)[:, :, 1], dims=2)[:, 1]);
# fig = CairoMakie.hist(b_hat)
# CairoMakie.save("test.png", fig)

# # Assess prediction accuracy
# y_pred::Vector{Float64} = hcat(ones(size(X, 1)), X) * b_hat;
# cor(y, y_pred)
# y_pred::Vector{Float64} = hcat(ones(length(y_validation)), F[idx_validation, :]) * b_hat;
# cor(y_validation, y_pred)
# fig = CairoMakie.plot(y, y_pred)
# CairoMakie.save("test.png", fig)
