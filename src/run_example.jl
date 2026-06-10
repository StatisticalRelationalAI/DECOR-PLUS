@isdefined(DiscreteFactor)         || include(string(@__DIR__, "/discrete_factor.jl"))
@isdefined(buckets)                || include(string(@__DIR__, "/buckets.jl"))
@isdefined(load_from_file)         || include(string(@__DIR__, "/helper.jl"))
@isdefined(commutative_args_naive) || include(string(@__DIR__, "/commutative_args.jl"))

f1 = DiscreteFactor(
	"f1",
	[DiscreteRV("R1"), DiscreteRV("R2"), DiscreteRV("R3")],
	[
		([true,  true,  true],  1.0),
		([true,  true,  false], 2.0),
		([true,  false, true],  2.0),
		([true,  false, false], 3.0),
		([false, true,  true],  4.0),
		([false, true,  false], 5.0),
		([false, false, true],  5.0),
		([false, false, false], 6.0),
	]
)

f2 = DiscreteFactor(
	"f2",
	[DiscreteRV("R4"), DiscreteRV("R5"), DiscreteRV("R6")],
	[
		([true,  true,  true],  1.0),
		([true,  true,  false], 2.0),
		([true,  false, true],  2.0),
		([true,  false, false], 5.0),
		([false, true,  true],  4.0),
		([false, true,  false], 5.0),
		([false, false, true],  3.0),
		([false, false, false], 6.0),
	]
)

f3 = DiscreteFactor(
	"f3",
	[DiscreteRV("R1"), DiscreteRV("R2"), DiscreteRV("R3"), DiscreteRV("R4")],
	[
		([true,  true,  true,  true],  1.0),
		([true,  true,  true,  false], 2.0),
		([true,  true,  false, true],  3.0),
		([true,  true,  false, false], 4.0),
		([true,  false, true,  true],  3.0),
		([true,  false, true,  false], 5.0),
		([true,  false, false, true],  6.0),
		([true,  false, false, false], 8.0),
		([false, true,  true,  true],  3.0),
		([false, true,  true,  false], 5.0),
		([false, true,  false, true],  6.0),
		([false, true,  false, false], 8.0),
		([false, false, true,  true],  7.0),
		([false, false, true,  false], 8.0),
		([false, false, false, true],  9.0),
		([false, false, false, false], 10.0),
	]
)


### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	"debug" in ARGS && (ENV["JULIA_DEBUG"] = "all")
	println("=> f1 (expected output: {R2, R3}):")
	println(string("Naive: ", commutative_args_naive(f1)))
	println(string("DECOR: ", commutative_args_decor(f1)))

	println("=> f2 (expected output: {}):")
	println(string("Naive: ", commutative_args_naive(f2)))
	println(string("DECOR: ", commutative_args_decor(f2)))
end