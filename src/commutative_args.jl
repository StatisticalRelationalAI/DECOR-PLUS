using DataStructures

@isdefined(buckets) || include(string(@__DIR__, "/buckets.jl"))

"""
	commutative_args_naive(f::DiscreteFactor)::Vector{DiscreteRV}

Return a maximal subset of `f`'s arguments such that `f` is commutative
with respect to that subset.
If no subset with size at least two exists, return an empty set.
The implementation naively tries all subsets of `f`'s arguments.
"""
function commutative_args_naive(f::DiscreteFactor)::Vector{DiscreteRV}
	# Note: Currently only for Boolean RVs

	subset_size = length(rvs(f))
	while subset_size > 1
		# Consider subsets of a specific size only
		for subset in powerset(rvs(f), subset_size, subset_size)
			is_commutative = true
			for b in values(buckets(f, subset))
				if length(unique(b)) > 1
					is_commutative = false
					break
				end
			end
			is_commutative && return collect(subset)
		end
		subset_size -= 1
	end

	return [] # No commutative arguments found
end

"""
	commutative_args_decor(f::DiscreteFactor)::Vector{DiscreteRV}

The original DECOR algorithm, which has no correctness guarantee.

## References
M. Luttermann, J. Machemer, and M. Gehrke.
Efficient Detection of Commutative Factors in Factor Graphs.
PGM, 2024.
"""
function commutative_args_decor(f::DiscreteFactor)::Vector{DiscreteRV}
	buckets_f, confs_f = buckets_ordered(f, false)
	candidates_list = [rvs(f)]

	for (bucket_key, bucket_values) in buckets_f
		# Skip if bucket contains only one item
		length(bucket_values) == 1 && continue

		groups = get_groups_from_bucket(bucket_values, confs_f[bucket_key])
		isempty(groups) && return Vector{DiscreteRV}()

		# Compute candidates for every group inside of the current bucket
		bucket_candidates_list = Vector{Vector{DiscreteRV}}()
		for (group_key, group_values) in groups
			group_candidates = compute_candidates(group_values, rvs(f))
			push!(bucket_candidates_list, group_candidates)
		end

		# Intersect each set of bucket candidates with each set of previous
		# candidates
		new_candidates_list = Vector{Vector{DiscreteRV}}()
		for last_candidates in candidates_list
			for bucket_candidates in bucket_candidates_list
				sect = intersect(last_candidates, bucket_candidates)
				if length(sect) > 1 && !in(sect, new_candidates_list)
					push!(new_candidates_list, sect)
				end
			end
		end

		# If no candidates are left, stop
		isempty(new_candidates_list) && return Vector{DiscreteRV}()
		# Update candidate list
		candidates_list = new_candidates_list
	end

	# Return the largest candidate set
	return argmax(length, candidates_list)
end

"""
	commutative_args_decorplus(f::DiscreteFactor, heuristic::Symbol = :none)::Vector{DiscreteRV}

Return a maximal subset of `f`'s arguments such that `f` is commutative
with respect to that subset.
If no subset with size at least two exists, return an empty set.
The implementation uses the DECOR+ algorithm.

The optional `heuristic` argument selects a bucket-ordering heuristic that
permutes the bucket processing order before the main loop runs. Supported
values are
* `:none` (default): keep the original bucket order,
* `:smallest_bucket`: sort buckets by `m_b` in ascending order,
* `:least_groups`: sort buckets by `g_b` in ascending order,
* `:smallest_candidate_set`: sort buckets by `|C'_b|` in ascending order, and
* `:smallest_minimal_candidate`: sort buckets by `min_{C_i in C'_b} |C_i|`
  in ascending order.

Internally, this is the composition of two phases that can also be measured
individually via `decorplus_candidates` and `decorplus_verify`.
"""
function commutative_args_decorplus(
	f::DiscreteFactor,
	heuristic::Symbol = :none
)::Vector{DiscreteRV}
	return decorplus_verify(f, decorplus_candidates(f, heuristic))
end

"""
	decorplus_candidates(f::DiscreteFactor, heuristic::Symbol = :none)::Vector{Vector{DiscreteRV}}

Phase 1 of DECOR+: build the list of candidate subsets by intersecting
bucket-induced candidate sets in the order chosen by `heuristic`.
Returns the surviving `candidates_list` (a list of subsets, each of size
at least two) or an empty list if no candidate of size at least two
remains.
"""
function decorplus_candidates(
	f::DiscreteFactor,
	heuristic::Symbol = :none
)::Vector{Vector{DiscreteRV}}
	buckets_f, confs_f = buckets_ordered(f, false)
	rv_f = rvs(f)
	candidates_list = [rv_f]

	# Precompute, for every bucket with at least two potentials, the candidate
	# subset induced by each maximal group of identical potentials. This is
	# exactly the `bucket_candidates_list` consumed by the main loop below
	# and the input every group/`C'`-based heuristic needs, so we build it
	# once and share it across the heuristic and the main loop.
	# A bucket with no group of identical potentials immediately rules out
	# any commutative subset, so we return early in that case.
	bucket_cands = Dict{Any, Vector{Vector{DiscreteRV}}}()
	for (k, vs) in buckets_f
		length(vs) < 2 && continue
		groups = get_groups_from_bucket(vs, confs_f[k])
		isempty(groups) && return Vector{Vector{DiscreteRV}}()
		cands = Vector{Vector{DiscreteRV}}()
		for (_, gv) in groups
			push!(cands, compute_candidates(gv, rv_f))
		end
		bucket_cands[k] = cands
	end

	order = bucket_order(collect(keys(buckets_f)), buckets_f, bucket_cands, heuristic)

	for bucket_key in order
		haskey(bucket_cands, bucket_key) || continue
		bucket_candidates_list = bucket_cands[bucket_key]

		# Intersect each set of bucket candidates with each set of previous
		# candidates
		new_candidates_list = Vector{Vector{DiscreteRV}}()
		for last_candidates in candidates_list
			for bucket_candidates in bucket_candidates_list
				sect = intersect(last_candidates, bucket_candidates)
				if length(sect) > 1 && !in(sect, new_candidates_list)
					push!(new_candidates_list, sect)
				end
			end
		end

		# If no candidates are left, stop
		isempty(new_candidates_list) && return Vector{Vector{DiscreteRV}}()
		# Update candidate list
		candidates_list = new_candidates_list
	end

	return candidates_list
end

"""
	decorplus_verify(f::DiscreteFactor, candidates_list::Vector{Vector{DiscreteRV}})::Vector{DiscreteRV}

Phase 2 of DECOR+: verify the candidate subsets returned by
`decorplus_candidates` and return a maximal commutative subset.
Returns an empty vector if no candidate is commutative.
"""
function decorplus_verify(
	f::DiscreteFactor,
	candidates_list::Vector{Vector{DiscreteRV}}
)::Vector{DiscreteRV}
	# If there are >= 2 candidates, the loop should be modified such that
	# all candidates of the same size are verified before moving to a
	# smaller size, so that the first verified candidate is guaranteed to be
	# maximal. However, in our experiments, there is no instance with more
	# than one candidate surviving, so this implementation works equally well
	# (and also requires equally many iterations).
	for candidate in sort(candidates_list, by=c->length(c), rev=true)
		subset_size = length(candidate)
		while subset_size > 1
			# Consider subsets of a specific size only
			for subset in powerset(candidate, subset_size, subset_size)
				is_commutative = true
				for b in values(buckets(f, subset))
					if length(unique(b)) > 1
						is_commutative = false
						break
					end
				end
				is_commutative && return candidate
			end
			subset_size -= 1
		end
	end
	return Vector{DiscreteRV}()
end

"""
	commutative_args_apriori(f::DiscreteFactor)::Vector{Vector{DiscreteRV}}

Return the set of all subsets of `f`'s arguments of maximum size such
that `f` is commutative with respect to each subset.
If no commutative subset of size at least two exists, return an empty
vector.

The implementation uses an Apriori-style algorithm that enumerates
commutative subsets level-by-level, exploiting both the downward
closure and the transitivity of pairwise commutativity: a candidate
of size `k+1` is admitted whenever every newly introduced pair is
contained in `L_2`, so no explicit commutativity check beyond level
two is required. `L_2` is stored as a symmetric adjacency matrix for
`O(1)` pair lookups, and subsets are represented as sorted index
vectors (referring to positions in `rvs(f)`) so that hash-based
deduplication of generated candidates is cheap.
"""
function commutative_args_apriori(f::DiscreteFactor)::Vector{Vector{DiscreteRV}}
	args = rvs(f)
	n = length(args)

	function is_commutative_pair(i::Int, j::Int)::Bool
		for b in values(buckets(f, [args[i], args[j]]))
			length(unique(b)) > 1 && return false
		end
		return true
	end

	# L_2: symmetric adjacency matrix for O(1) pair-membership tests
	L_2_adj = falses(n, n)
	L_k = Vector{Vector{Int}}()
	for i in 1:n-1, j in i+1:n
		if is_commutative_pair(i, j)
			L_2_adj[i, j] = true
			L_2_adj[j, i] = true
			push!(L_k, [i, j])
		end
	end

	isempty(L_k) && return Vector{Vector{DiscreteRV}}()

	# L tracks the most recent non-empty layer, i.e., the commutative
	# subsets of largest size discovered so far.
	L = L_k

	while !isempty(L_k)
		L_k_next = Vector{Vector{Int}}()
		seen = Set{Vector{Int}}()
		for C in L_k
			for i in 1:n
				i in C && continue
				# Pair-based pruning by transitivity: every newly introduced
				# pair {R_i, R_j} with R_j in C must be in L_2.
				ok = true
				for j in C
					if !L_2_adj[i, j]
						ok = false
						break
					end
				end
				ok || continue
				C_prime = sort!(push!(copy(C), i))
				if !(C_prime in seen)
					push!(seen, C_prime)
					push!(L_k_next, C_prime)
				end
			end
		end
		if !isempty(L_k_next)
			L = L_k_next
		end
		L_k = L_k_next
	end

	return [args[idx] for idx in L]
end

"""
	commutative_args_cc(f::DiscreteFactor)::Vector{Vector{DiscreteRV}}

Return the set of all subsets of `f`'s arguments of maximum size such
that `f` is commutative with respect to each subset.
If no commutative subset of size at least two exists, return an empty
vector.

The implementation first computes `L_2`, the set of all commutative
pairs of arguments, and then merges overlapping subsets via a
union-find data structure (with path compression and union by rank):
every commutative pair `{R_i, R_j}` triggers a `union(R_i, R_j)`,
and the connected components of the resulting partition are
returned. By the overlap property of commutative subsets, every
connected component of size at least two is itself a commutative
subset of arguments, and the maximum-sized components coincide with
the maximum-sized commutative subsets.
"""
function commutative_args_cc(f::DiscreteFactor)::Vector{Vector{DiscreteRV}}
	args = rvs(f)
	n = length(args)

	function is_commutative_pair(i::Int, j::Int)::Bool
		for b in values(buckets(f, [args[i], args[j]]))
			length(unique(b)) > 1 && return false
		end
		return true
	end

	# Union-find on {1, ..., n} with path compression and union by rank
	uf = IntDisjointSets(n)

	# Compute L_2 and union every commutative pair in a single pass
	for i in 1:n-1, j in i+1:n
		is_commutative_pair(i, j) && union!(uf, i, j)
	end

	# Group argument indices by their union-find root
	groups = Dict{Int, Vector{Int}}()
	for i in 1:n
		r = find_root!(uf, i)
		push!(get!(groups, r, Int[]), i)
	end

	# Keep components of size >= 2 (singletons are not commutative subsets)
	components = [g for g in values(groups) if length(g) >= 2]

	isempty(components) && return Vector{Vector{DiscreteRV}}()

	max_size = maximum(length, components)
	return [args[g] for g in components if length(g) == max_size]
end

"""
	c_prime_from_cands(cands::Vector{Vector{DiscreteRV}})::Vector{Vector{DiscreteRV}}

Apply the subsumption check to a list of candidate subsets (one per maximal
group of identical potentials in some bucket) and return the resulting
set `C'`.
"""
function c_prime_from_cands(
	cands::Vector{Vector{DiscreteRV}}
)::Vector{Vector{DiscreteRV}}
	c_prime = Vector{Vector{DiscreteRV}}()
	for c_i in cands
		any(c_j -> issubset(c_i, c_j), c_prime) && continue
		push!(c_prime, c_i)
	end
	return c_prime
end

"""
	bucket_order(keys_f::Vector, buckets_f::OrderedDict, bucket_cands::Dict, heuristic::Symbol)::Vector

Return the order in which the buckets in `buckets_f` should be processed by
DECOR+ given the specified `heuristic`. The `bucket_cands` argument maps every
bucket key with at least two potentials to its precomputed list of candidate
subsets (one per maximal group of identical potentials, no subsumption
removal); this is consumed directly so no group computation is repeated here.

Supported heuristics:
* `:none`: keep the original bucket order in `buckets_f`,
* `:smallest_bucket`: sort by bucket size in ascending order,
* `:least_groups`: sort by number of maximal groups of identical
  potentials of size at least two in ascending order,
* `:smallest_candidate_set`: sort by `|C'_b|` (after subsumption removal) in
  ascending order, and
* `:smallest_minimal_candidate`: sort by the size of the smallest candidate
  subset in `C'_b` in ascending order.

Buckets with fewer than two potentials are skipped by the main DECOR+ loop
and are placed at the end of the returned order for sorting heuristics that
target group-/`C'`-based metrics.
"""
function bucket_order(
	keys_f::Vector,
	buckets_f::OrderedDict,
	bucket_cands::Dict,
	heuristic::Symbol
)::Vector
	if heuristic == :none
		return keys_f
	elseif heuristic == :smallest_bucket
		return sort(keys_f, by = k -> length(buckets_f[k]))
	elseif heuristic == :least_groups
		return sort(
			keys_f,
			by = k -> haskey(bucket_cands, k) ? length(bucket_cands[k]) : 0,
		)
	elseif heuristic == :smallest_candidate_set
		c_prime_sizes = Dict(
			k => length(c_prime_from_cands(bucket_cands[k]))
			for k in keys(bucket_cands)
		)
		return sort(keys_f, by = k -> get(c_prime_sizes, k, typemax(Int)))
	elseif heuristic == :smallest_minimal_candidate
		min_sizes = Dict(
			k => isempty(bucket_cands[k]) ?
				typemax(Int) : minimum(length, bucket_cands[k])
			for k in keys(bucket_cands)
		)
		return sort(keys_f, by = k -> get(min_sizes, k, typemax(Int)))
	else
		error("Unknown heuristic: $heuristic")
	end
end

"""
	get_groups_from_bucket(bucket_values::Vector, bucket_confs::Vector)::Dict

	Return the groups inside of a bucket with size larger than 1.
"""
function get_groups_from_bucket(bucket_values::Vector, bucket_confs::Vector)::Dict
	groups = Dict()

	for (index, item) in enumerate(bucket_values)
		if !haskey(groups, item)
			cnt = count(x -> x == item, bucket_values)
			cnt < 2 && continue
			groups[item] = []
			push!(groups[item], bucket_confs[index])
		else
			push!(groups[item], bucket_confs[index])
		end
	end

	return groups
end

"""
	compute_candidates(group::Vector, rv_f::Vector)::Vector{DiscreteRV}

Return the candidates for the given group.
"""
function compute_candidates(group::Vector, rv_f::Vector)::Vector{DiscreteRV}
	candidates = Vector{DiscreteRV}()

	for (index, rv) in enumerate(rv_f)
		isallequal = true
		last = group[1][index]
		for i in 2:length(group)
			group[i][index] != last && (isallequal = false)
			last = group[i][index]
		end

		!isallequal && push!(candidates, rv)
	end

	return candidates
end