using Statistics

"""
	_parse_time(s::AbstractString)::Float64

Parse a time entry from `results.csv`. Returns `NaN` for `"timeout"`.
"""
function _parse_time(s::AbstractString)::Float64
	s == "timeout" && return NaN
	return parse(Float64, s)
end

"""
	prepare_times_main(file::String)

Build averages over multiple runs and write the results into a new `.csv` file
that is used for plotting in the main paper. Reports candidate-generation
time, verification time, and total time (their sum) as separate columns.
"""
function prepare_times_main(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared-main.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	# averages[algo][n] = (Vector{Float64}, Vector{Float64}) for (candidates, verify)
	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			n = cols[2]
			algo = cols[6]
			t_cand = _parse_time(cols[7])
			t_ver = _parse_time(cols[8])
			haskey(averages, algo) || (averages[algo] = Dict())
			haskey(averages[algo], n) || (averages[algo][n] = (Float64[], Float64[]))
			push!(averages[algo][n][1], t_cand)
			push!(averages[algo][n][2], t_ver)
		end
	end

	open(new_file, "a") do io
		write(io, "n,algo,min_t,max_t,mean_t,median_t,std,mean_t_candidates,mean_t_verify\n")
		for (algo, ns) in averages
			for (n, (cands, verifs)) in ns
				# Average with timeouts does not work
				(any(isnan, cands) || any(isnan, verifs)) && continue
				totals = cands .+ verifs
				write(io, string(
					parse(Int, n), ",",
					algo, ",",
					minimum(totals), ",",
					maximum(totals), ",",
					mean(totals), ",",
					median(totals), ",",
					std(totals), ",",
					mean(cands), ",",
					mean(verifs), "\n"
				))
			end
		end
	end
end

"""
	prepare_times_appendix(file::String)

Build averages over multiple runs and write the results into a new `.csv` file
that is used for plotting in the appendix. Reports candidate-generation
time, verification time, and total time (their sum) as separate columns.
"""
function prepare_times_appendix(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared-appendix.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	# averages[(algo, n, k, g, s)] = (Vector{Float64}, Vector{Float64}) for (candidates, verify)
	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			n = cols[2]
			k = cols[3]
			g = cols[4]
			s = cols[5]
			algo = cols[6]
			t_cand = _parse_time(cols[7])
			t_ver = _parse_time(cols[8])
			key = (algo, n, k, g, s)
			haskey(averages, key) || (averages[key] = (Float64[], Float64[]))
			push!(averages[key][1], t_cand)
			push!(averages[key][2], t_ver)
		end
	end

	open(new_file, "a") do io
		write(io, "n,k,g,s,algo,min_t,max_t,mean_t,median_t,std,mean_t_candidates,mean_t_verify\n")
		for ((algo, n, k, g, s), (cands, verifs)) in averages
			# Average with timeouts does not work
			(any(isnan, cands) || any(isnan, verifs)) && continue
			totals = cands .+ verifs
			write(io, string(
				parse(Int, n), ",",
				parse(Int, k), ",",
				parse(Int, g), ",",
				parse(Int, s), ",",
				algo, ",",
				minimum(totals), ",",
				maximum(totals), ",",
				mean(totals), ",",
				median(totals), ",",
				std(totals), ",",
				mean(cands), ",",
				mean(verifs), "\n"
			))
		end
	end
end


### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	prepare_times_main(string(@__DIR__, "/results.csv"))
	prepare_times_appendix(string(@__DIR__, "/results.csv"))
end