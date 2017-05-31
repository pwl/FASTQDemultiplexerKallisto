module FASTQDemultiplexerKallisto

import FASTQDemultiplexer:
    Output, Protocol, InterpretedRecord,
    mergeoutput
using DataFrames
using Weave


include("kallisto.jl")


const kallisto = Dict{String,Kallisto}()


type OutputKallisto <: Output
    kallisto::Kallisto
    results::DataFrame
end


function OutputKallisto(protocol::Protocol;
                        index::String = "",
                        kwargs...)

    k = get!(kallisto,index) do
        Kallisto(index)
    end

    results = DataFrame(cellid = UInt[],
                        umiid = UInt[],
                        groupname = PooledDataArray(String,UInt8,0),
                        alignment = Int[])

    return OutputKallisto(k,results)
end


function Base.write(o::OutputKallisto,
                    ir::InterpretedRecord)
    if ir.groupid >= 0
        alignment = align(o.kallisto,ir)
        push!(o.results,(ir.cellid,ir.umiid,ir.groupname,alignment))
    end
end


function mergeoutput(outputs::Vector{OutputKallisto};
                     outputdir::String=".",
                     writealignment = true,
                     writereport = true,
                     kwargs...)
    if length(outputs) > 1
        results = vcat((o.results for o in outputs)...)
    else
        results = outputs[1].results
    end

    if writealignment
        mkpath(outputdir)
        writetable(joinpath(outputdir,"alignment.tsv"),results)
    end

    if writereport
        mkpath(outputdir)
        report(results, outputdir)
    end
end

function report(results, outputdir)
    args = Dict{String,Any}()
    args["results"] = results

    weave(Pkg.dir("FASTQDemultiplexerKallisto",
                  "src","weave","alignment.jmd"),
          args = args,
          out_path = outputdir)
end

end
