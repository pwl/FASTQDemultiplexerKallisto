const libkallisto=joinpath(Pkg.dir("FASTQDemultiplexerKallisto","deps"),"libkallisto_align.so")
const libkallisto2=joinpath(Pkg.dir("FASTQDemultiplexerKallisto","deps"),"libkallisto_align2.so")

@generated function idtolib(val,lib)
    if lib == Type{Val{1}}
        return :((val,libkallisto))
    elseif lib == Type{Val{2}}
        return :((val,libkallisto2))
    end
end

type Kallisto{lib}
    ka::Ptr{Void}
    isopen::Bool
end


const kallisto = Dict{String,Kallisto}()


function (::Type{Kallisto{lib}}){lib}(index::AbstractString)

    if !isfile(index)
        error("Could not locate index at $index")
    end

    k = get!(kallisto,index) do
        ka = ccall(idtolib(:kallisto_lib_init,Val{lib}),
                   Ptr{Void},())
        ccall(idtolib(:kallisto_lib_loadIndex,Val{lib}),
              Void,
              (Ptr{Void},Cstring),
              ka,index)
        Kallisto{lib}(ka,true)
    end

    return k

end

function align{lib}(k::Kallisto{lib},ir::InterpretedRecord)
    seq = String(ir.output.data[ir.output.sequence])
    if k.isopen
        ccall(idtolib(:kallisto_lib_alignRead,Val{lib}),
              Int32,
              (Ptr{Void},Ptr{Cchar},UInt32),
              k.ka,seq,length(seq))
    else
        error("Trying to aling with a closed kallisto")
    end
end

function Base.close{lib}(k::Kallisto{lib})
    if k.isopen
        info("Closing kallisto")
        ccall(idtolib(:kallisto_lib_destroy,Val{lib}),
              Void,
              (Ptr{Void},),
              k.ka)
        k.isopen = false
    end
end
