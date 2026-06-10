using BenchmarkTools

@isdefined(DiscreteFactor)         || include(string(@__DIR__, "/discrete_factor.jl"))
@isdefined(load_from_file)         || include(string(@__DIR__, "/helper.jl"))
@isdefined(commutative_args_naive) || include(string(@__DIR__, "/commutative_args.jl"))

"""
List of supported algorithm identifiers. The `decorplus_*` variants run
DECOR+ with the corresponding bucket-ordering heuristic; `decorplus`
alone runs the default `:none` heuristic.
"""
const ALGOS = [
	"naive",
	"decor",
	"decorplus",
	"decorplus_smallest_bucket",
	"decorplus_least_groups",
	"decorplus_smallest_candidate_set",
	"decorplus_smallest_minimal_candidate",
	"apriori",
	"cc",
]

"""
	algo_fn(algo::String)::Function

Resolve an algorithm identifier to the corresponding callable. Errors if the
identifier is unknown.
"""
function algo_fn(algo::String)::Function
	algo == "naive"                                && return commutative_args_naive
	algo == "decor"                                && return commutative_args_decor
	algo == "decorplus"                            && return f -> commutative_args_decorplus(f, :none)
	algo == "decorplus_smallest_bucket"            && return f -> commutative_args_decorplus(f, :smallest_bucket)
	algo == "decorplus_least_groups"               && return f -> commutative_args_decorplus(f, :least_groups)
	algo == "decorplus_smallest_candidate_set"     && return f -> commutative_args_decorplus(f, :smallest_candidate_set)
	algo == "decorplus_smallest_minimal_candidate" && return f -> commutative_args_decorplus(f, :smallest_minimal_candidate)
	algo == "apriori"                              && return f -> _pick_one(commutative_args_apriori(f))
	algo == "cc"                                   && return f -> _pick_one(commutative_args_cc(f))
	error("Unknown algorithm '$algo'.")
end

"""
	decorplus_heuristic(algo::String)::Union{Symbol,Nothing}

Map a DECOR+ algorithm identifier to its bucket-ordering heuristic. Returns
`nothing` for algorithms that are not a DECOR+ variant.
"""
function decorplus_heuristic(algo::String)::Union{Symbol,Nothing}
	algo == "decorplus"                            && return :none
	algo == "decorplus_smallest_bucket"            && return :smallest_bucket
	algo == "decorplus_least_groups"               && return :least_groups
	algo == "decorplus_smallest_candidate_set"     && return :smallest_candidate_set
	algo == "decorplus_smallest_minimal_candidate" && return :smallest_minimal_candidate
	return nothing
end

"""
	_pick_one(res::Vector{Vector{DiscreteRV}})::Vector{DiscreteRV}

Reduce a list of maximum-size commutative subsets (as returned by `apriori`
and `cc`) to a single subset, so that every algorithm in `ALGOS` returns one
`Vector{DiscreteRV}`. All subsets in `res` have the same maximum size, so the
choice is arbitrary; we take the first one. Returns an empty subset if no
commutative subset of size at least two exists.
"""
function _pick_one(res::Vector{Vector{DiscreteRV}})::Vector{DiscreteRV}
	return isempty(res) ? DiscreteRV[] : first(res)
end

"""
	format_result(res::Vector{DiscreteRV})::String

Encode a single commutative subset for serialisation as `[R1,R2,...]`.
"""
function format_result(res::Vector{DiscreteRV})::String
	return string("[", join(res, ","), "]")
end

"""
	run_benchmark(file::String, algo::String)

Run the benchmark for a given file and algorithm. The output format is
`time_candidates;time_verify;result`, where the two times are mean
runtimes in nanoseconds. For DECOR+ variants, the two phases are
benchmarked separately; for all other algorithms, the entire algorithm
is timed as `time_candidates` and `time_verify` is reported as `0`.
"""
function run_benchmark(file::String, algo::String)
	f, _ = load_from_file(file)
	try
		heuristic = decorplus_heuristic(algo)
		if heuristic === nothing
			fn = algo_fn(algo)
			result = @benchmark (global res = $fn($f))
			print(string(mean(result.times), ";", 0, ";", format_result(res)))
		else
			b_cands = @benchmark (global cands = decorplus_candidates($f, $heuristic))
			b_verify = @benchmark (global res = decorplus_verify($f, $cands))
			print(string(
				mean(b_cands.times), ";",
				mean(b_verify.times), ";",
				format_result(res),
			))
		end
	catch e
		print(string(typeof(e), ": ", e))
	end
end


### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	if length(ARGS) != 2 || !isfile(ARGS[1]) || !(ARGS[2] in ALGOS)
		@error string(
			"Run this file via 'julia $PROGRAM_FILE <path> <algo>' ",
			"with <path> being the path to a data file on which to run the ",
			"algorithm <algo> (one of $(join(ALGOS, ", ")))."
		)
		exit()
	end
	run_benchmark(ARGS[1], ARGS[2])
end
