const libkallisto=joinpath(Pkg.dir("FASTQDemultiplexerKallisto","deps"),"libkallisto_align.so")

type Kallisto
    ka::Ptr{Void}
    isopen::Bool
end

function Kallisto(index::AbstractString)
    if !isfile(index)
        error("Could not locate index at $index")
    end
    ka = ccall((:kallisto_lib_init,libkallisto),
               Ptr{Void},())
    ccall((:kallisto_lib_loadIndex,libkallisto),
          Void,
          (Ptr{Void},Cstring),
          ka,index)
    Kallisto(ka,true)
end

function align(k::Kallisto,ir::InterpretedRecord)
    seq = String(ir.output.data[ir.output.sequence])
    if k.isopen
        ccall((:kallisto_lib_alignRead,libkallisto),
              Int32,
              (Ptr{Void},Ptr{Cchar},UInt32),
              k.ka,seq,length(seq))
    else
        error("Trying to aling with a closed kallisto")
    end
end

function Base.close(k::Kallisto)
    if k.isopen
        info("Closing kallisto")
        ccall((:kallisto_lib_destroy,libkallisto),
              Void,
              (Ptr{Void},),
              k.ka)
        k.isopen = false
    end
end
