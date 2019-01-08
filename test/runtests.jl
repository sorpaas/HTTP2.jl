using Test

include("frames.jl")

const opts = Base.JLOptions()
const inline_flag = opts.can_inline == 1 ? `` : `--inline=no`
const cov_flag = (opts.code_coverage == 1) ? `--code-coverage=user` :
                 (opts.code_coverage == 2) ? `--code-coverage=all` :
                 ``

function run_test(script, args...)
    srvrscript = joinpath(dirname(@__FILE__), script)
    if isempty(args)
        srvrcmd = `$(joinpath(Sys.BINDIR, "julia")) $cov_flag $inline_flag $script`
    elseif length(args) == 2
        srvrcmd = `$(joinpath(Sys.BINDIR, "julia")) $cov_flag $inline_flag $script $(args[1]) $(args[2])`
    elseif length(args) == 1
        srvrcmd = `$(joinpath(Sys.BINDIR, "julia")) $cov_flag $inline_flag $script $(args[1])`
    end
    println("Running tests from ", script, "\n", "="^60)
    ret = run(srvrcmd)
    println("Finished ", script, "\n", "="^60)
    nothing
end

@async run_test("server.jl")
sleep(20)
run_test("client.jl")
sleep(20)

GENKEYSCRIPT = joinpath(dirname(@__FILE__), "genkey.sh")
run(`$GENKEYSCRIPT`)

keyfile = joinpath(dirname(@__FILE__), "www.example.com.key")
certfile = joinpath(dirname(@__FILE__), "www.example.com.cert")
@async run_test("server.jl", certfile, keyfile)
sleep(20)
run_test("client.jl", "www.example.com")
sleep(20)
