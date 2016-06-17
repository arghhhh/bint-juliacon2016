
# two arg clamp:
# takes a Type arg, and uses typemin and typemax to get the limits
# AND ALSO converts to this type since after clamping, this is safe

# since I'm effectively adding to Base here, get warnings after reloading
# see https://github.com/JuliaLang/julia/issues/7860#issuecomment-51340412

import Base.clamp
clamp{T}( x, ::Type{T} ) = clamp( x, typemin(T), typemax(T) ) % T

# copied and modified from base/math.jl
# this makes two arg clamp work with arrays
clamp{T,T2}(x::AbstractArray{T,1}, ::Type{T2} ) = [clamp(xx, T2 ) for xx in x]
clamp{T,T2}(x::AbstractArray{T,2}, ::Type{T2}) =
    [clamp(x[i,j], T2) for i in 1:size(x,1), j in 1:size(x,2)]  # fixme (iter): change to `eachindex` when #15459 is ready
clamp{T,T2}(x::AbstractArray{T}, ::Type{T2}) =
    reshape([clamp(xx, T2) for xx in x], size(x))

function clamp!{T,T2}(x::AbstractArray{T}, ::Type{T2})
    @inbounds for i in eachindex(x)
        x[i] = clamp(x[i], T2 )
    end
    x
end


import Base.clamp
# make two arg clamp more efficient for BInt RHS
@generated function Base.clamp{Tx<:Integer,R}( x::Tx, ::Type{BInt{R}} )
        l = typemin(BInt{R})
        u = typemax(BInt{R})
        Tw = default_int_type( range_union( R, Tx ) )
        # converting x to Tw makes this work for Tx being either
        # an ordinary Int, or a Bint
        :( UncheckedBInt{R}( Base.clamp( x % $Tw, $l , $u ) ) )
end
@generated function Base.clamp{Tx<:Integer,R,T}( x::Tx, ::Type{BInt{R,T}} )
        l = typemin(BInt{R,T})
        u = typemax(BInt{R,T})
        Tw = default_int_type( range_union( R, Tx ) )
        :( UncheckedBInt{R,T}( Base.clamp( x % $Tw, $l , $u ) ) )
end

# this works for arrays
# clamp( BInt{Int16}[ 10, 2000, 30 ], BInt{Int8} )
# ideally by adding Base.clamp( n, T ) and associated Array code
