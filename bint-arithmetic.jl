

import Base.+
import Base.-
import Base.*

@generated function +{R1,R2}( a1::BInt{R1}, a2::BInt{R2} )
        l1,u1 = get_range_bounds( R1 )
        l2,u2 = get_range_bounds( R2 )
        RangeOut = make_range( l1+l2, u1+u2 )
        Tout = default_int_type( RangeOut )
        # convert the args to Tout ensure no overflow
        return :(
                UncheckedBInt{ $RangeOut, $Tout }( $Tout(a1.n) + $Tout(a2.n) )
                )

end

@generated function -{R1,R2}( a1::BInt{R1}, a2::BInt{R2} )
        l1,u1 = get_range_bounds( R1 )
        l2,u2 = get_range_bounds( R2 )
        RangeOut = make_range( l1-u2, u1-l2 )
        Tout = default_int_type( RangeOut )

        @dd @show RangeOut Tout
        # convert the args to Tout ensure no overflow
        return :(
                UncheckedBInt{ $RangeOut, $Tout }( $Tout(a1.n) - $Tout(a2.n) )
                )

end

@generated function *{R1,R2}( a1::BInt{R1}, a2::BInt{R2} )
        l1,u1 = get_range_bounds( R1 )
        l2,u2 = get_range_bounds( R2 )

        corners = l1*l2, l1*u2, u1*l2, u1*u2
        lower = min( corners... )
        upper = max( corners... )

        @dd @show l1 u1 l2 u2 corners lower upper

        RangeOut = make_range( lower, upper )
        Tout = default_int_type( RangeOut )

        @dd @show RangeOut Tout
        # convert the args to Tout ensure no overflow
        return :(
                UncheckedBInt{ $RangeOut, $Tout }( $Tout(a1.n) * $Tout(a2.n) )
                )
end

import Base.<<
@generated function <<{R1,R2}( a1::BInt{R1}, a2::BInt{R2} )
        l1,u1 = get_range_bounds( R1 )
        l2,u2 = get_range_bounds( R2 )

        lower = signbit(u2) ? l1 >> -u2 : l1 << u2
        upper = signbit(u2) ? u1 >> -u2 : u1 << u2

        RangeOut = make_range( lower, upper )
        Tout = default_int_type( RangeOut )

        # be careful with the type used for the actual <<
        # operation.  a2 could always be negative
        # and the result type be smaller than the arg types
        # but need to do the shift with larger type
        # also note that 100 << -1 is 0 in julia....
        # 100 << -1 is 50 in Julia 0.5

        if l2 >= 0
                # always positive shift
                # working type is Tout
                return :(
                        UncheckedBInt{ $RangeOut, $Tout }( $Tout(a1.n) << a2.n )
                        )
        elseif u2 <= 0
                # always negative shift
                # working type is the input type
                # avoid corner case of RHS being Int8(-128) and then
                # being negated
                return :(
                        UncheckedBInt{ $RangeOut, $Tout }( $Tout( a1.n >> -Int(a2.n) ) )
                        )
        else
                # mixed sign shift
                # working type is Tout
                return :(
                        UncheckedBInt{ $RangeOut, $Tout }(
                                signbit( a2.n ) ? $Tout(a1.n) >> -Int(a2.n)
                                        : $Tout(a1.n) << a2.n
                                )
                        )
        end
end
function <<{R1}( a1::BInt{R1}, a2::Unsigned )
        return default_int_type(R1)(a1.n) << a2
end

@generated function Base.abs{R}( x::BInt{R} )
        l,u = get_range_bounds( R )

        lower = (l <= 0 && u >= 0) ? 0 : min( abs(l), abs(u) )
        upper = max( abs(l), abs(u) )

        RangeOut = make_range( lower, upper )
        Tout = default_int_type( RangeOut )

        return :( UncheckedBInt{ $RangeOut, $Tout }( Base.abs( $Tout(x) ) ) )
end

# abs2(x) just returns x*x - but the bounds can be tighter than just letting the
# default implementation do it
@generated function Base.abs2{R}( x::BInt{R} )
        l,u = get_range_bounds( R )

        lower = (l <= 0 && u >= 0) ? 0 : min( abs(l), abs(u) )
        upper1 = max( abs(l), abs(u) )
        upper = upper1 * upper1

        RangeOut = make_range( lower, upper )
        Tout = default_int_type( RangeOut )

        return :( UncheckedBInt{ $RangeOut, $Tout }( $Tout(x) * $Tout(x) ) )
end



# there are corner cases where this fails
# need a function that gives the union type of the input and
# output range, and uses this for the working type
# and probably as the result type too.

# consider x with range 0:( typemax(Int64)+1 )
# result range is then typemin(Int64):0
# so using just the output range would suggest that Int64 was suitable
# when it is not, because converting ( typemax(Int64)+1 ) from an Int128
# to a Int64 throws an exception

@generated function -{R}( x::BInt{R} )
        l,u = get_range_bounds( R )

        lower = -u
        upper = -l

        RangeOut = make_range( lower, upper )
        Tout = default_int_type( range_union( R, RangeOut ) )

        return :( UncheckedBInt{ $RangeOut, $Tout }( -( $Tout(x) ) ) )
end

import Base.~
@generated function ~{R}( x::BInt{R} )
        l,u = get_range_bounds( R )

        lower = ~u
        upper = ~l

        RangeOut = make_range( lower, upper )
        Tout = default_int_type( range_union( R, RangeOut ) )

        return :( UncheckedBInt{ $RangeOut, $Tout }( ~( $Tout(x) ) ) )
end

Base.rand{R}(rng::AbstractRNG, ::Type{ BInt{R} } ) = UncheckedBInt{R}( rand(rng, R ) )
Base.rand{R,T}(rng::AbstractRNG, ::Type{ BInt{R,T} } ) = UncheckedBInt{R,T}( rand(rng, R ) )


import Base.<
import Base.<=
import Base.>
import Base.>=
import Base.==
import Base.!=

 <{   T1<:Integer,R2,T2<:Integer}( x::T1         , y::BInt{R2,T2} ) = x   < y.n
 <{R1,T1<:Integer,   T2<:Integer}( x::BInt{R1,T1}, y::T2          ) = x.n < y
 <{R1,T1<:Integer,R2,T2<:Integer}( x::BInt{R1,T1}, y::BInt{R2,T2} ) = x.n < y.n

<={   T1<:Integer,R2,T2<:Integer}( x::T1         , y::BInt{R2,T2} ) = x   <= y.n
<={R1,T1<:Integer,   T2<:Integer}( x::BInt{R1,T1}, y::T2          ) = x.n <= y
<={R1,T1<:Integer,R2,T2<:Integer}( x::BInt{R1,T1}, y::BInt{R2,T2} ) = x.n <= y.n

 >{   T1<:Integer,R2,T2<:Integer}( x::T1         , y::BInt{R2,T2} ) = x   > y.n
 >{R1,T1<:Integer,   T2<:Integer}( x::BInt{R1,T1}, y::T2          ) = x.n > y
 >{R1,T1<:Integer,R2,T2<:Integer}( x::BInt{R1,T1}, y::BInt{R2,T2} ) = x.n > y.n

>={   T1<:Integer,R2,T2<:Integer}( x::T1         , y::BInt{R2,T2} ) = x   >= y.n
>={R1,T1<:Integer,   T2<:Integer}( x::BInt{R1,T1}, y::T2          ) = x.n >= y
>={R1,T1<:Integer,R2,T2<:Integer}( x::BInt{R1,T1}, y::BInt{R2,T2} ) = x.n >= y.n

=={   T1<:Integer,R2,T2<:Integer}( x::T1         , y::BInt{R2,T2} ) = x   == y.n
=={R1,T1<:Integer,   T2<:Integer}( x::BInt{R1,T1}, y::T2          ) = x.n == y
=={R1,T1<:Integer,R2,T2<:Integer}( x::BInt{R1,T1}, y::BInt{R2,T2} ) = x.n == y.n

!={   T1<:Integer,R2,T2<:Integer}( x::T1         , y::BInt{R2,T2} ) = x   != y.n
!={R1,T1<:Integer,   T2<:Integer}( x::BInt{R1,T1}, y::T2          ) = x.n != y
!={R1,T1<:Integer,R2,T2<:Integer}( x::BInt{R1,T1}, y::BInt{R2,T2} ) = x.n != y.n

# sign is supposed to return the same type as the arg
# so interpret this as returning a BInt
@generated function Base.sign{R}( x::BInt{R} )
        l,u = get_range_bounds( R )

        l1 = Base.sign(l)
        u1 = Base.sign(u)

        RangeOut = make_range( l1, u1 )
        Tout = default_int_type( range_union( R, RangeOut ) )

        return :( UncheckedBInt{ $RangeOut, $Tout }( $Tout( sign(x.n ) ) ) )
end

Base.signbit( x::BInt ) = Base.signbit( x.n )
Base.ispow2( x::BInt ) = Base.ispow2( x.n )

@generated function Base.nextpow2{R}( x::BInt{R} )
        l,u = get_range_bounds( R )

        l1 = Base.nextpow2(l)
        u1 = Base.nextpow2(u)

        RangeOut = make_range( l1, u1 )
        Tout = default_int_type( range_union( R, RangeOut ) )

        return :( UncheckedBInt{ $RangeOut, $Tout }( $Tout( nextpow2(x.n ) ) ) )
end

@generated function Base.prevpow2{R}( x::BInt{R} )
        l,u = get_range_bounds( R )

        l1 = Base.prevpow2(l)
        u1 = Base.prevpow2(u)

        RangeOut = make_range( l1, u1 )
        Tout = default_int_type( range_union( R, RangeOut ) )

        return :( UncheckedBInt{ $RangeOut, $Tout }( $Tout( prevpow2(x.n ) ) ) )
end

# could do subset of round, trunc etc
