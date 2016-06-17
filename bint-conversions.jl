

# need conversions for things like:
# a = BInt{1:10,Int8}[ 1, 2, 3, 4 ]
# a = BInt{1:10}[ 1, 2, 3, 4 ]
# a[2] = 4

@generated function Base.convert{R}( ::Type{ Bool }, x::BInt{R} )
        l,u = get_range_bounds( R )
        if l > 0 || u < 0
                # range does not include 0 - so must be true
                return true
        elseif l == u == 0
                return false
        else
                return :( Bool(x.n) )
        end
end

# conversion from Integer to BInt:
@generated function Base.convert{R,T1<:Integer}( ::Type{ BInt{R} }, x::T1 )
        T = default_int_type( R )
        Tworking = default_int_type( range_union( T, T1 ) )
        l,u = get_range_bounds( R, Tworking )
        return :(
                if ( $Tworking(x) >= $l ) ;
                        if ( $Tworking(x) <= $u ) ;
                                return UncheckedBInt{R,$T}( x )
                        end;
                end;
                throw( InexactError() );
        )
end



@generated function Base.convert{R,T,T1<:Integer}( ::Type{ BInt{R,T} }, x::T1 )
        l,u = get_range_bounds( R, T )
        return :(
                if ( $T(x) >= $l ) ;
                        if ( $T(x) <= $u ) ;
                                return UncheckedBInt{R,T}( x )
                        end;
                end;
                throw( InexactError() );
        )
end

# conversion from BInt to Integer:
Base.convert{R1,T1,T<:Integer}( ::Type{ T }, x::BInt{R1,T1} ) = T( x.n )

# for conversion from BInt to BInt, only allow narrower ranges to
# be assigned to wider ranges
@generated function Base.convert{R1,R2,T2}( ::Type{ BInt{R2} }, x::BInt{R1,T2} )
        if !range_within_range( R1, R2 )
                throw( InexactError() );
        end
        :( UncheckedBInt{ R2 }( x.n ) )
end
@generated function Base.convert{R1,T1,R2,T2}( ::Type{ BInt{R2,T2} }, x::BInt{R1,T1} )
        if !range_within_range( R1, R2 )
                throw( InexactError() );
        end
        :( UncheckedBInt{ R2, T2 }( x.n ) )
end

# converting from a BInt to a narrower range BInt
# is a special case - want to make the runtime check
# be explicit
# so allow
#           Int -> BInt conversion
#           BInt -> wider BInt conversion
#           BInt -> narrower BInt - only with explicit tighten_range fn.

@generated function tighten_range{R,R2,T2}( ::Type{BInt{R}}, x::BInt{R2,T2} )
        T = default_int_type( R )
        l,u = get_range_bounds( R, T )

        :(
                if ( $T(x.n) < $l ) ; throw( InexactError() ); end;
                if ( $T(x.n) > $u ) ; throw( InexactError() ); end;
                BInt{R,$T}( $T(x.n), 0 )
        )
end

# this is a little lazy - there are corner cases where it will fail
# but Bint * Int * Int cannot be protected from overflow, so its a lost
# cause - stay within the BInt type, or else risk overflow

# this is because of things like promote_type( Int64, UInt64 ) which
# gives a UInt64.  While it is true that an Int64 can be losslessly converted
# to a UInt64 and back again, it doesn't mean that arithmetic will work
Base.promote_rule{R1,T1,T2<:Integer }(::Type{BInt{R1,T1}}, ::Type{T2} ) = promote_type( T1,T2)

Base.promote_rule{R1,R2}(::Type{ BInt{R1} },::Type{ BInt{R2} } ) = begin
        R = range_union( R1, R2 )
        T = default_int_type( R )
        return BInt{R,T}
end
Base.promote_rule{R1,T1,R2}(::Type{ BInt{R1,T1} },::Type{ BInt{R2} } ) = begin
        R = range_union( R1, R2 )
        T = default_int_type( R )
        return BInt{R,T}
end
Base.promote_rule{R1,T1,R2,T2}(::Type{ BInt{R1,T1} },::Type{ BInt{R2,T2} } ) = begin
        R = range_union( R1, R2 )
        T = default_int_type( R )
        return BInt{R,T}
end
