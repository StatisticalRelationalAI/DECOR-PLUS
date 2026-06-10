using OrderedCollections

@isdefined(DiscreteRV) || include(string(@__DIR__, "/discrete_rv.jl"))

"""
	DiscreteFactor

Struct for discrete factors.

## Examples
```jldoctest
julia> f = DiscreteFactor("f", [DiscreteRV("A")], [([false], 0.5), ([true], 0.5)])
f
```
"""
mutable struct DiscreteFactor
	name::String
	rvs::Vector{DiscreteRV}
	potentials::OrderedDict{String, AbstractFloat}
	DiscreteFactor(
		name::String,
		rvs::Vector{DiscreteRV},
		ps::Array # Vector{Tuple{Vector, AbstractFloat}}
	) = new(
		name,
		rvs,
		OrderedDict(join(tuple[1], ",") => tuple[2] for tuple in ps)
	)
end

"""
	name(f::DiscreteFactor)::String

Return the name of the factor `f`.

## Examples
```jldoctest
julia> f = DiscreteFactor("f", [DiscreteRV("A")], [([false], 0.5), ([true], 0.5)])
f
julia> name(f)
"f"
```
"""
function name(f::DiscreteFactor)::String
	return f.name
end

"""
	rvs(f::DiscreteFactor)::Vector{RandVar}

Return all random variables participating in the given factor `f`.

## Examples
```jldoctest
julia> f = DiscreteFactor("f", [DiscreteRV("A")], [([false], 0.5), ([true], 0.5)])
f
julia> rvs(f)
1-element Vector{RandVar}:
 A
```
"""
function rvs(f::DiscreteFactor)::Vector{RandVar}
	return f.rvs
end

"""
	rvs(f::DiscreteFactor)::Vector{DiscreteRV}

Return all random variables participating in the given factor `f`.

## Examples
```jldoctest
julia> f = DiscreteFactor("f", [DiscreteRV("A")], [([false], 0.5), ([true], 0.5)])
f
julia> rvs(f)
1-element Vector{DiscreteRV}:
 A
```
"""
function rvs(f::DiscreteFactor)::Vector{DiscreteRV}
	return f.rvs
end

"""
	rvpos(f::DiscreteFactor, rv::DiscreteRV)::Int

Return the position of random variable `rv` in factor `f`.

## Examples
```jldoctest
julia> a = DiscreteRV("A")
A
julia> f = DiscreteFactor("f", [a], [([false], 0.5), ([true], 0.5)])
f
julia> rvpos(f, a)
1
```
"""
function rvpos(f::DiscreteFactor, rv::DiscreteRV)::Int
	return_value = findfirst(x -> x == rv, rvs(f))
	return !isnothing(return_value) ? return_value : -1
end

"""
	potentials(f::DiscreteFactor)::Vector{AbstractFloat}

Return the potentials of the given factor `f`.

## Examples
```jldoctest
julia> f = DiscreteFactor("f", [DiscreteRV("A")], [([false], 0.5), ([true], 0.5)])
f
julia> potentials(f)
2-element Vector{Tuple{Vector{SubString{String}}, Float64}}:
 (["true"], 0.5)
 (["false"], 0.5)
```
"""
function potentials(f::DiscreteFactor)::Array
	return [(split(c, ","), p) for (c, p) in f.potentials]
end

"""
	potential(f::DiscreteFactor, conf::Vector)::AbstractFloat

Return the potential of the factor `f` with the evidence (configuration)
`conf`.

## Examples
```jldoctest
julia> f = DiscreteFactor("f", [DiscreteRV("A")], [([false], 0.2), ([true], 0.8)])
f
julia> potential(f, [true])
0.8
```
"""
function potential(f::DiscreteFactor, conf::Vector)::AbstractFloat
	return get(f.potentials, join(conf, ","), NaN)
end

"""
	is_valid(f::DiscreteFactor)::Bool

Check whether the factor `f` is valid (i.e., all potentials are specified).

## Examples
```jldoctest
julia> f = DiscreteFactor("f", [DiscreteRV("A")], [([false], 0.2), ([true], 0.8)])
f
julia> is_valid(f)
true
julia> f2 = DiscreteFactor("f2", [DiscreteRV("A")], [])
f2
julia> is_valid(f2)
false
```
"""
function is_valid(f::DiscreteFactor)::Bool
	for c in collect(Base.Iterators.product(map(x -> range(x), f.rvs)...))
		isnan(potential(f, [i for i in c])) && return false
	end
	return true
end

"""
	print_potentials(f::DiscreteFactor, io::IO = stdout)

Print the potentials of a factor `f` on the given output stream `io`.
"""
function print_potentials(f::DiscreteFactor, io::IO = stdout)
	if isempty(f.potentials)
		println(io, "Potentials for factor $(name(f)) are missing.")
		return
	end

	pad_size = 12
	h = string("| ", join(map(x -> lpad(name(x), pad_size), rvs(f)), " | "))
	h = string(h, " | ", lpad(name(f), pad_size), " |")
	println(io, h)
	println(io, string("|", repeat("-", length(h) - 2), "|"))
	for c in sort(collect(keys(f.potentials)), rev=true)
		p = f.potentials[c]
		print(io, string("| ", join(map(x -> lpad(x, pad_size), split(c, ",")), " | ")))
		print(io, string(" | ",lpad(p, pad_size), " |", "\n"))
	end
	print(io, "\n")
end

"""
	Base.deepcopy(f::DiscreteFactor)::DiscreteFactor

Create a deep copy of `f`.
"""
function Base.deepcopy(f::DiscreteFactor)::DiscreteFactor
	return DiscreteFactor(name(f), deepcopy(rvs(f)), deepcopy(potentials(f)))
end

"""
	Base.:(==)(f1::DiscreteFactor, f2::DiscreteFactor)::Bool

Check whether two factors `f1` and `f2` are identical.
"""
function Base.:(==)(f1::DiscreteFactor, f2::DiscreteFactor)::Bool
	return f1.name == f2.name && f1.rvs == f2.rvs &&
		f1.potentials == f2.potentials
end

"""
	Base.show(io::IO, f::DiscreteFactor)

Show the factor `f` in the given output stream `io`.
"""
function Base.show(io::IO, f::DiscreteFactor)
	print(io, name(f))
end