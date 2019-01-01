using Test

include("frames.jl")

const opts = Base.JLOptions()
const inline_flag = opts.can_inline == 1 ? `` : `--inline=no`
const cov_flag = (opts.code_coverage == 1) ? `--code-coverage=user` :
                 (opts.code_coverage == 2) ? `--code-coverage=all` :
                 ``

function run_test(script)
    srvrscript = joinpath(dirname(@__FILE__), script)
    srvrcmd = `$(joinpath(Sys.BINDIR, "julia")) $cov_flag $inline_flag $script`
    println("Running tests from ", script, "\n", "="^60)
    ret = run(srvrcmd)
    println("Finished ", script, "\n", "="^60)
    nothing
end

@async run_test("server.jl")
sleep(20)
run_test("client.jl")
