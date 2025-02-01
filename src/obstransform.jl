
# mapobs

struct MappedData{batched, F, D} <: AbstractDataContainer
    f::F
    data::D
end

function Base.show(io::IO, data::MappedData{batched}) where {batched}
    print(io, "mapobs(")
    print(IOContext(io, :compact=>true), data.f)
    print(io, ", ")
    print(IOContext(io, :compact=>true), data.data)
    print(io, "; batched=:$(batched))")
end

Base.length(data::MappedData) = numobs(data.data)
Base.getindex(data::MappedData, ::Colon) = data[1:length(data)]

Base.getindex(data::MappedData{:auto}, idx::Int) = data.f(getobs(data.data, idx))
Base.getindex(data::MappedData{:auto}, idxs::AbstractVector) = data.f(getobs(data.data, idxs))

Base.getindex(data::MappedData{:never}, idx::Int) = data.f(getobs(data.data, idx))
Base.getindex(data::MappedData{:never}, idxs::AbstractVector) = [data.f(getobs(data.data, idx)) for idx in idxs]

Base.getindex(data::MappedData{:always}, idx::Int) = getobs(data.f(getobs(data.data, [idx])), 1)
Base.getindex(data::MappedData{:always}, idxs::AbstractVector) = data.f(getobs(data.data, idxs))


"""
    mapobs(f, data; batched=:auto)

Lazily map `f` over the observations in a data container `data`.
Returns a new data container `mdata` that can be indexed and has a length.
Indexing triggers the transformation `f`.

The batched keyword argument controls the behavior of `mdata[idx]` and `mdata[idxs]` 
where `idx` is an integer and `idxs` is a vector of integers:
- `batched=:auto` (default). Let `f` handle the two cases. 
   Calls `f(getobs(data, idx))` and `f(getobs(data, idxs))`.
- `batched=:never`. The function `f` is always called on a single observation. 
   Calls `f(getobs(data, idx))` and `[f(getobs(data, idx)) for idx in idxs]`.
- `batched=:always`. The function `f` is always called on a batch of observations.
    Calls `getobs(f(getobs(data, [idx])), 1)` and `f(getobs(data, idxs))`.

# Examples

```julia
julia> data = (a=[1,2,3], b=[1,2,3]);

julia> mdata = mapobs(data) do x
         (c = x.a .+ x.b,  d = x.a .- x.b)
       end
mapobs(#25, (a = [1, 2, 3], b = [1, 2, 3]); batched=:auto))

julia> mdata[1]
(c = 2, d = 0)

julia> mdata[1:2]
(c = [2, 4], d = [0, 0])
```
"""
mapobs(f::F, data::D; batched=:auto) where {F,D} = MappedData{batched, F, D}(f, data)

"""
    mapobs(fs, data)

Lazily map each function in tuple `fs` over the observations in data container `data`.
Returns a tuple of transformed data containers.
"""
mapobs(fs::Tuple, data) = Tuple(mapobs(f, data) for f in fs)


struct NamedTupleData{TData,F} <: AbstractDataContainer
    data::TData
    namedfs::NamedTuple{F}
end

Base.length(data::NamedTupleData) = numobs(getfield(data, :data))

function Base.getindex(data::NamedTupleData{TData,F}, idx::Int) where {TData,F}
    obs = getobs(getfield(data, :data), idx)
    namedfs = getfield(data, :namedfs)
    return NamedTuple{F}(f(obs) for f in namedfs)
end

Base.getproperty(data::NamedTupleData, field::Symbol) =
    mapobs(getproperty(getfield(data, :namedfs), field), getfield(data, :data))

Base.show(io::IO, data::NamedTupleData) =
    print(io, "mapobs($(getfield(data, :namedfs)), $(getfield(data, :data)))")

"""
    mapobs(namedfs::NamedTuple, data)

Map a `NamedTuple` of functions over `data`, turning it into a data container
of `NamedTuple`s. Field syntax can be used to select a column of the resulting
data container.

```julia
data = 1:10
nameddata = mapobs((x = sqrt, y = log), data)
getobs(nameddata, 10) == (x = sqrt(10), y = log(10))
getobs(nameddata.x, 10) == sqrt(10)
```
"""
function mapobs(namedfs::NamedTuple, data)
    return NamedTupleData(data, namedfs)
end

# filterobs

"""
    filterobs(f, data)

Return a subset of data container `data` including all indices `i` for
which `f(getobs(data, i)) === true`.

```julia
data = 1:10
numobs(data) == 10
fdata = filterobs(>(5), data)
numobs(fdata) == 5
```
"""
function filterobs(f, data; iterfn = _iterobs)
    return obsview(data, [i for (i, obs) in enumerate(iterfn(data)) if f(obs)])
end

_iterobs(data) = [getobs(data, i) for i = 1:numobs(data)]


# groupobs

"""
    groupobs(f, data)

Split data container data `data` into different data containers, grouping
observations by `f(obs)`.

```julia
data = -10:10
datas = groupobs(>(0), data)
length(datas) == 2
```
"""
function groupobs(f, data)
    groups = Dict{Any,Vector{Int}}()
    for i = 1:numobs(data)
        group = f(getobs(data, i))
        if !haskey(groups, group)
            groups[group] = [i]
        else
            push!(groups[group], i)
        end
    end
    return Dict(group => obsview(data, idxs) for (group, idxs) in groups)
end

# joinumobs

struct JoinedData{T<:Tuple,N} <: AbstractDataContainer
    datas::T
    ns::NTuple{N,Int}
end

JoinedData(datas::Tuple) = JoinedData(datas, numobs.(datas))

Base.length(data::JoinedData) = sum(data.ns)

function Base.getindex(data::JoinedData, idx::Integer)
    @assert 1 <= idx <= length(data)
    for (i, n) in enumerate(data.ns)
        if idx <= n
            return getobs(data.datas[i], idx)
        else
            idx -= n
        end
    end
end

function Base.getindex(data::JoinedData, idx::AbstractVector{<:Integer})
    return [data[i] for i in idx]
end

"""
    joinobs(datas...)

Concatenate data containers `datas`.

```julia
data1, data2 = 1:10, 11:20
jdata = joinumobs(data1, data2)
getobs(jdata, 15) == 15
```
"""
joinobs(datas...) = JoinedData(cleanjoin(datas...))

cleanjoin(x::JoinedData, ys...) = (x.datas..., cleanjoin(ys...)...)
cleanjoin(x, ys...) = (x, cleanjoin(ys...)...)
cleanjoin() = ()


"""
    shuffleobs([rng], data)

Return a version of the dataset `data` that contains all the
origin observations in a random reordering.

The values of `data` itself are not copied. Instead only the
indices are shuffled. This function calls [`obsview`](@ref) to
accomplish that, which means that the return value is likely of a
different type than `data`.

Optionally, a random number generator `rng` can be passed as the
first argument.

The optional parameter `rng` allows one to specify the
random number generator used for shuffling. This is useful when
reproducible results are desired.

For this function to work, the type of `data` must implement
[`numobs`](@ref) and [`getobs`](@ref). 

See also [`obsview`](@ref).

# Examples

```julia
# For Arrays the subset will be of type SubArray
@assert typeof(shuffleobs(rand(4,10))) <: SubArray

# Iterate through all observations in random order
for x in eachobs(shuffleobs(X))
    ...
end
```
"""
shuffleobs(data) = shuffleobs(Random.default_rng(), data)

function shuffleobs(rng::AbstractRNG, data)
    return obsview(data, randperm(rng, numobs(data)))
end
