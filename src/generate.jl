using Random
using StatsBase

@isdefined(DiscreteFactor) || include(string(@__DIR__, "/discrete_factor.jl"))
@isdefined(save_to_file)   || include(string(@__DIR__, "/helper.jl"))

"""
	gen_commutative_randpots(rs::Array, comm_indices::Vector{Int}, seed::Int=123)::Vector{Tuple{Vector, Float64}}

Generate random commutative potentials for a given array of ranges.
The second parameter `comm_indices` specifies the indices of the ranges
that should be commutative.
If no indices should be commutative, set `comm_indices` to an empty list.
"""
function gen_commutative_randpots(
	rs::Array,
	comm_indices::Vector{Int},
	seed::Int=123
)::Vector{Tuple{Vector, Float64}}
	@assert all(idx -> 1 <= idx <= length(rs), comm_indices)
	@assert all(idx -> rs[idx] == rs[comm_indices[1]], comm_indices)

	isempty(comm_indices) && return gen_asc_pots(rs)

	Random.seed!(seed)
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	com_range = rs[comm_indices[1]]
	non_comm_pos = [idx for idx in 1:length(rs) if !(idx in comm_indices)]
	vals = Dict()
	next_val = 1
	potentials = []
	for conf in Iterators.product(rs...)
		key_parts = Vector{Int}(undef, length(com_range))
		nom_com_vals = [val for (idx, val) in enumerate(conf) if idx in non_comm_pos]
		for (idx, range_val) in enumerate(com_range)
			com_vals = [val for (idx, val) in enumerate(conf) if idx in comm_indices]
			key_parts[idx] = count(x -> x == range_val, com_vals)
		end
		key = string(join(key_parts, "-"), "--", join(nom_com_vals, "-"))
		!haskey(vals, key) && (vals[key] = next_val)
		push!(potentials, ([conf...], vals[key]))
		next_val += 1
	end

	return potentials
end

"""
	gen_commutative_randpots_groups(rs::Array, comm_groups::Vector{Vector{Int}}, seed::Int=123)::Vector{Tuple{Vector, Float64}}

Generate random potentials for a given array of ranges such that the resulting
factor is commutative with respect to each group of indices in `comm_groups`
*independently*. The groups must be pairwise disjoint and every group must
contain at least two indices that share the same range; different groups may
have different ranges.

The construction assigns the same potential value to two configurations iff
they agree on every non-commutative position and induce the same per-group
count signature for each group separately. Hence permutations within a single
group preserve the potential, while permutations that mix arguments across
groups generally do not (unless they happen to leave every per-group count
signature unchanged, e.g., a swap of two arguments holding identical values).

If `comm_groups` is empty, this falls back to `gen_asc_pots(rs)`.
"""
function gen_commutative_randpots_groups(
	rs::Array,
	comm_groups::Vector{Vector{Int}},
	seed::Int=123
)::Vector{Tuple{Vector, Float64}}
	all_indices = Int[]
	for grp in comm_groups
		@assert length(grp) >= 2 "Each commutative group must contain at least two indices"
		@assert all(idx -> 1 <= idx <= length(rs), grp)
		@assert all(idx -> rs[idx] == rs[grp[1]], grp) "All indices in a group must share the same range"
		append!(all_indices, grp)
	end
	@assert length(unique(all_indices)) == length(all_indices) "Commutative groups must be pairwise disjoint"

	isempty(comm_groups) && return gen_asc_pots(rs)

	Random.seed!(seed)
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	non_comm_pos = [idx for idx in 1:length(rs) if !(idx in all_indices)]
	vals = Dict()
	next_val = 1
	potentials = []
	for conf in Iterators.product(rs...)
		non_comm_vals = [val for (idx, val) in enumerate(conf) if idx in non_comm_pos]
		group_keys = Vector{String}(undef, length(comm_groups))
		for (g_idx, grp) in enumerate(comm_groups)
			grp_range = rs[grp[1]]
			grp_vals = [conf[idx] for idx in grp]
			counts = [count(x -> x == range_val, grp_vals) for range_val in grp_range]
			group_keys[g_idx] = join(counts, "-")
		end
		key = string(join(group_keys, "|"), "--", join(non_comm_vals, "-"))
		!haskey(vals, key) && (vals[key] = next_val)
		push!(potentials, ([conf...], vals[key]))
		next_val += 1
	end

	return potentials
end

"""
	gen_asc_pots(rs::Array, start::Int=1)::Vector{Tuple{Vector, Float64}}

Generate ascending potentials for a given array of ranges, starting at `start`.
"""
function gen_asc_pots(rs::Array, start::Int=1)::Vector{Tuple{Vector, Float64}}
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	potentials = []
	i = start
	for conf in Iterators.product(rs...)
		push!(potentials, ([conf...], i))
		i += 1
	end

	return potentials
end

### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	Random.seed!(123)
	dir = string(@__DIR__, "/../data/")
	!isdir(dir) && mkdir(dir)
	for n in [2, 4, 6, 8, 10, 12, 14, 16]
		nstr = lpad(n, 2, "0")
		for k in unique([0, 2, floor(log2(n)), floor(n/2), n-1, n])
			k == 1 && continue
			k = Int(floor(k))
			kstr = lpad(k, 2, "0")
			indices = StatsBase.sample(1:n, k, replace=false)
			randvars = [DiscreteRV("R$i") for i in 1:n]
			p = gen_commutative_randpots([range(rv) for rv in randvars], indices)
			f = DiscreteFactor("f", randvars, p)
			res = sort([string("R", i) for i in indices])
			save_to_file(
				(f, string("[", join(res, ","), "]")),
				string(dir, "n=$nstr-k=$kstr.ser")
			)
		end
	end

	# Instances with varying numbers of disjoint commutative groups. For each
	# `n`, we partition `n` arguments into `g` disjoint groups of equal size
	# `s = n / g` (with `s >= 2`). The check result lists the groups separated
	# by `|`, e.g. `[R1,R2]|[R3,R4]` for two disjoint pairs.
	for n in [4, 6, 8, 10, 12, 14, 16]
		nstr = lpad(n, 2, "0")
		for g in 2:Int(floor(n/2))
			n % g == 0 || continue
			s = Int(n / g)
			gstr = lpad(g, 2, "0")
			sstr = lpad(s, 2, "0")
			perm = StatsBase.sample(1:n, n, replace=false)
			groups = [sort(perm[(i-1)*s+1 : i*s]) for i in 1:g]
			randvars = [DiscreteRV("R$i") for i in 1:n]
			p = gen_commutative_randpots_groups(
				[range(rv) for rv in randvars], groups
			)
			f = DiscreteFactor("f", randvars, p)
			group_strs = [string("[", join(["R$i" for i in grp], ","), "]")
				for grp in groups]
			save_to_file(
				(f, join(group_strs, "|")),
				string(dir, "n=$nstr-g=$gstr-s=$sstr.ser")
			)
		end
	end
end