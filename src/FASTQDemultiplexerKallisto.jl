module FASTQDemultiplexerKallisto

import FASTQDemultiplexer:
    Output, Protocol, InterpretedRecord,
    mergeoutput
using DataFrames
using Weave


include("kallisto.jl")


abstract OutputKallisto <: Output


type OutputKallistoSingle <: OutputKallisto
    kallisto::Kallisto{1}
    results::DataFrame
end


type OutputKallistoDouble <: OutputKallisto
    kallisto::Kallisto{1}
    kallisto2::Kallisto{2}
    results::DataFrame
end

issingle(::OutputKallistoSingle) = true
issingle(::OutputKallistoDouble) = false


function OutputKallisto(protocol::Protocol;
                        index::String = "",
                        index2::String = "",
                        kwargs...)

    results = DataFrame(cellid = UInt[],
                        umiid = UInt[],
                        groupname = PooledDataArray(String,UInt8,0),
                        alignment = Int[])

    k = Kallisto{1}(index)

    if !isempty(index2)
        k2 = Kallisto{2}(index2)
        return OutputKallistoDouble(
            k,k2,vcat(results,DataFrame(alignment2 = Int[])))
    else
        return OutputKallistoSingle(k,results)
    end
end


function Base.write(o::OutputKallisto,
                    ir::InterpretedRecord)
    if ir.groupid >= 0
        alignment = align(o.kallisto,ir)
        if issingle(o)
            push!(o.results,(ir.cellid,ir.umiid,ir.groupname,alignment))
        else
            alignment2 = align(o.kallisto2,ir)
            push!(o.results,(ir.cellid,ir.umiid,ir.groupname,alignment,alignment2))
        end
    end
end


function mergeoutput{OK<:OutputKallisto}(outputs::Vector{OK};
                                         outputdir::String=".",
                                         writealignment = true,
                                         writereport = true,
                                         index::String = "",
                                         index2::String = "",
                                         name::String = basename(index),
                                         name2::String = basename(index2),
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
        report(results, outputdir, [name,name2])
    end
end

function report(results, outputdir, names)
    args = Dict{String,Any}()
    args[:results] = results
    args[:indexnames] = names

    weave(Pkg.dir("FASTQDemultiplexerKallisto",
                  "src","weave","alignment.jmd"),
          args = args,
          out_path = outputdir)
end

end
