@isdefined(DiscreteFactor)  || include(string(@__DIR__, "/discrete_factor.jl"))
@isdefined(nanos_to_millis) || include(string(@__DIR__, "/helper.jl"))

# Algorithms exercised by the evaluation. Mirrors `ALGOS` in `run_algo.jl`.
const EVAL_ALGOS = [
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
	run_eval(dir=string(@__DIR__, "/../data/"), outdir=string(@__DIR__, "/../results/"))

Run the experiments.
"""
function run_eval(
	dir=string(@__DIR__, "/../data/"),
	outdir=string(@__DIR__, "/../results/")
)
	!isdir(outdir) && mkdir(outdir)
	outfile = string(outdir, "results.csv")
	outfile_exists = isfile(outfile)

	open(outfile, "a") do io
		!outfile_exists && write(io, "instance,n,k,g,s,algo,time_candidates,time_verify,correct_result\n")
		for (root, dirs, files) in walkdir(dir)
			for f in files
				(!occursin(".DS_Store", f) && !occursin("README", f) &&
					!occursin(".gitkeep", f)) || continue

				fpath = string(root, endswith(root, "/") ? "" : "/", f)
				f_short = replace(f, ".ser" => "")
				_, check_res = load_from_file(fpath)
				n, k, g, s = parse_instance_params(f)

				@info "=> Processing file '$fpath'..."
				for algo in EVAL_ALGOS
					@info "Running algorithm '$algo'..."
					cmd = `julia run_algo.jl $fpath $algo`
					res = run_with_timeout(cmd)
					if !verify_result(res, check_res)
						estr = string(
							"Algo '$algo' returned wrong result for '$fpath':\n",
							"Expected: $check_res\n",
							"Actual: $(result_subset(res))"
						)
						@error estr
					end
					t_cands, t_verify = convert_result(res)
					write(io, join([
						f_short,
						n,
						k,
						g,
						s,
						algo,
						t_cands,
						t_verify,
						check_res,
					], ","), "\n")
					flush(io)
				end
			end
		end
	end
end

"""
	parse_instance_params(f::String)::Tuple{Int,Int,Int,Int}

Extract `(n, k, g, s)` from an instance filename. Two filename schemas are
supported:

* `n=NN-k=KK.ser` - single commutative subset of size `k` (then `g = 1`,
  `s = k`; or `g = s = 0` if `k = 0`).
* `n=NN-g=GG-s=SS.ser` - `g` disjoint commutative groups of size `s` each
  (then `k = g * s`, the total number of commutative arguments).
"""
function parse_instance_params(f::String)::Tuple{Int,Int,Int,Int}
	n = parse(Int, match(r"n=(\d+)", f)[1])
	g_match = match(r"g=(\d+)", f)
	if g_match !== nothing
		g = parse(Int, g_match[1])
		s = parse(Int, match(r"s=(\d+)", f)[1])
		return n, g * s, g, s
	end
	k = parse(Int, match(r"k=(\d+)", f)[1])
	g = k == 0 ? 0 : 1
	return n, k, g, k
end

"""
	run_with_timeout(command, timeout::Int = 300)

Run an external command with a timeout. If the command does not finish within
the specified timeout, the process is killed and `timeout` is returned.
"""
function run_with_timeout(command, timeout::Int = 300)
	out, err = Pipe(), Pipe()
	cmd = run(pipeline(command, stdout=out, stderr=err); wait=false)
	close(out.in)
	close(err.in)
	for _ in 1:timeout
		if !process_running(cmd)
			stdout_content = read(out, String)
			stderr_content = read(err, String)
			return string(stdout_content, stderr_content)
		end
		sleep(1)
	end
	kill(cmd)
	return "timeout"
end

"""
	result_subset(res::String)::String

Extract the result subset substring (`[R1,R2,...]`) from the algorithm
output. The output format produced by `run_algo.jl` is
`time_candidates;time_verify;result`, so the subset is the third
`;`-separated field.
"""
function result_subset(res::String)::String
	return String(split(res, ";")[3])
end

"""
	verify_result(res::String, check_res::String)::Bool

Verify the result of the algorithm. Every algorithm returns exactly one
maximum-size commutative subset, encoded as `[R1,R2,...]`. The ground-truth
`check_res` is encoded as `[R1,R2,...]` for instances with a single
commutative subset and as `[R1,R2]|[R3,R4]|...` for instances with several
disjoint commutative groups; the produced subset must coincide with one of
the listed ground-truth subsets.
"""
function verify_result(res::String, check_res::String)::Bool
	@debug "Verify result: '$res'"
	if contains(lowercase(res), "error")
		@error "Error during execution: $res"
		return false
	elseif contains(res, "timeout")
		return true # No verification possible
	end

	actual_str = result_subset(res)
	expected = Set(sort(s) for s in parse_subsets(check_res))
	actual_subsets = parse_subsets(actual_str)

	isempty(actual_subsets) && return isempty(expected)
	return sort(first(actual_subsets)) in expected
end

"""
	parse_subsets(s::AbstractString)::Vector{Vector{String}}

Parse a `|`-separated list of bracketed subsets (e.g., `[R1,R2]|[R3,R4]`)
into a list of subsets. A single bracketed subset like `[R1,R2,...]` is
returned as a one-element list. Empty subsets `[]` and an empty input
are returned as an empty list.
"""
function parse_subsets(s::AbstractString)::Vector{Vector{String}}
	s = strip(s)
	isempty(s) && return Vector{Vector{String}}()
	out = Vector{Vector{String}}()
	for part in split(s, "|")
		stripped = replace(replace(String(strip(part)), "[" => ""), "]" => "")
		isempty(stripped) && continue
		members = [String(strip(t)) for t in split(stripped, ",") if !isempty(strip(t))]
		isempty(members) || push!(out, members)
	end
	return out
end

"""
	convert_result(res::String)::Tuple{String,String}

Convert the result into the two phase measurements used by the evaluation.
The expected format of `res` is `time_candidates;time_verify;output`, where
both times are mean runtimes in nanoseconds and `output` is a list of
commutative arguments. The returned tuple contains the candidate-generation
and verification times in milliseconds (as strings). For timeouts, both
entries are `"timeout"`.
"""
function convert_result(res::String)::Tuple{String,String}
	contains(res, "timeout") && return ("timeout", "timeout")
	parts = split(res, ";")
	return (
		string(nanos_to_millis(parse(Float64, parts[1]))),
		string(nanos_to_millis(parse(Float64, parts[2]))),
	)
end


### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	run_eval()
end
