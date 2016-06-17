


immutable BInt{ R, T } <: Integer
        n::T
        function BInt( x::T , _ )
                new( x )
        end
end

# get BInt as a non-BInt integer in the simplest way:
int{R,T}( b::BInt{R,T} ) = b.n

Base.big{R,T}( b::BInt{R,T} ) = Base.big( b.n )

# ------------------------------------------------------------------------

immutable UncheckedBInt{R,T}
end

@generated function Base.call{R,T,T2}( ::Type{ UncheckedBInt{R,T} }, x::T2 )
        # check that the given type of T is suitable
        # BigInts are always suitable, but don't have typemin,typemax
        if T == BigInt
                return :( BInt{R,T}( T(x), 0 ) )
        else
                if !( range_within_range( R, T ) )
                        throw( InexactError() );
                end
                return :( BInt{R,T}( x % T, 0 ) )
        end
end

@generated function Base.call{R,T2}( ::Type{ UncheckedBInt{R} }, x::T2 )
        T = default_int_type(R)
        if T == BigInt
                :( BInt{R,$T}( $T(x), 0 ) )
        else
                :( BInt{R,$T}( x % $T, 0 ) )
        end
end

# ------------------------------------------------------------------------

# this is for constructing constants - where the range is
# just a single number (or a tuple in the case of very large numbers)
@generated function Base.call{R}( ::Type{ BInt{R} } )
#        v = from_type_constant(R)
        T = default_int_type(R)
        v = T( from_type_constant(R) )
        :( BInt{R,$T}( $v, 0 ) )
end

# construct BInt from any Integer type
# includes run-time check on bounds

@generated function Base.call{R,Tx<:Integer}( ::Type{ BInt{R} }, x::Tx )

        T = default_int_type( R )

        Tworking = default_int_type( range_union( R, Tx ) )

        l,u = get_range_bounds( R, Tworking )

        :(
                if ( $l <= $Tworking(x) );
                        if ( $Tworking(x) <= $u );
                                return BInt{R,$T}( x % $T, 0 );
                        end;
                end;
                throw( InexactError() );
        )
end


# making a BInt from a BInt only supported
# from narrow to an at-least-as-wide range
@generated function Base.call{R,Rx,Tx<:Integer}( ::Type{ BInt{R} }, x::BInt{Rx,Tx} )
        if !range_within_range( Rx, R )
                throw( InexactError() );
        end
        # know that R is wider than Rx
        # so no further need to check anything
        T = default_int_type( R )
        :(
                UncheckedBInt{R,$T}( x );
        )
end



# @code_llvm BInt{1:10 }( 5 )
# @code_llvm BInt{1:10 }( Int128(5) )
# @code_llvm BInt{1:10 }( Int16(5) )

@generated function Base.call{R,T,Tx<:Integer}( ::Type{ BInt{R,T} }, x::Tx )

        if !range_within_range( get_range_bounds( R )..., typemin(T), typemax(T) )
                throw( InexactError() );
        end

        Tworking = default_int_type( range_union( R, T ) )
        l,u = get_range_bounds( R, Tworking )

        :(
                if ( $Tworking(x) >= $l ) ;
                        if ( $Tworking(x) <= $u ) ;
                                return UncheckedBInt{R,T}( x )
                        end;
                end;
                throw( InexactError() );
        )
end
@generated function Base.call{R,T,Rx,Tx<:Integer}( ::Type{ BInt{R,T} }, x::BInt{Rx,Tx} )
        if !range_within_range( Rx, R )
                throw( InexactError() );
        end
        :(      #UncheckedBInt does the check that T is suitable for R
                UncheckedBInt{R,T}( x );
        )
end

# @code_llvm BInt{1:10,Int32 }( Int32(5) )
# @code_llvm BInt{1:10,Int32 }( Int16(5) )
# @code_llvm BInt{1:10,Int32 }( 5 )

 # ------------------------------------------------------------------------

# The % operator:
# The converts any Integer (including BInts ) to a BInt by truncating MSBS
# Should be very quick because no run-time range checks are required

@inline function sign_extend_from( n::Integer, b )
        sgn = ( n >> b ) & 1 == 1
        msbs = sgn ? ~zero(n) << b : ~( ~zero(n)<<b )

        return sgn ? n | msbs : n & msbs
end

import Base.%

# conversion from BInt to any Integer:
function %{Tres <: Integer,R,T}( n::BInt{R,T}, ::Type{Tres} )
        return n.n % Tres
end

@generated function %{Rn,Tn,R}( n::BInt{Rn,Tn}, ::Type{BInt{R}} )
        Td = default_int_type(R)
        l,u = get_range_bounds(R)
#        ln,un = get_range_bounds(Tn)

        if range_within_range( Rn, R )
                # the target range R includes all of the source range Rn
                # just convert - no modulo required
                return :( UncheckedBInt{R,$Td}( $Td(n.n) ) )
        end
        if is_unsigned_binary_range( l, u )
                nbits = number_of_bits_unsigned(u)
                mask = Td( ( big(1)<<nbits ) - 1 )
                return :( UncheckedBInt{R,$Td}( $Td(n.n) & $mask ) )
        elseif is_signed_2sComplement_range( l, u )
                b = number_of_bits_signed(u) -1
                msbs1 = ~zero(Tn) << b;
                msbs0 = ~( ~zero(Tn)<<b );
                :(
                        # nn = sign_extend_from( n, $nbits );
                        # ideally would exploit llvm sext instruction...
                        sgn = ( n.n >> $b ) & 1 == 1;
                        nn = sgn ? n.n | $msbs1 : n.n & $msbs0;
                        UncheckedBInt{R,$Td}( nn )
                        )
        else
                error( "Type range not supported for % operator" )
        end
end

@generated function %{Tn<:Integer, R}( n::Tn, ::Type{ BInt{R} } )
        Td = default_int_type(R)
        l,u = get_range_bounds(R)
#        ln,un = get_range_bounds(Tn)

        if range_within_range( Tn, R )
                # just convert - no modulo required
                return :( UncheckedBInt{$R,$Td}( $Td(n) ) )
        end
        if is_unsigned_binary_range( l, u )
                nbits = number_of_bits_unsigned(u)
                mask = Td( ( big(1)<<nbits ) - 1 )
                return :( UncheckedBInt{$R,$Td}( $Td(n) & $mask ) )
        elseif is_signed_2sComplement_range( l, u )
                b = number_of_bits_signed(u) -1
                msbs1 = ~zero(n) << b;
                msbs0 = ~( ~zero(n)<<b );
                return :(
                        # nn = sign_extend_from( n, $nbits );
                        # ideally would exploit llvm sext instruction...
                        sgn = ( n >> $b ) & 1 == 1;
                        nn = sgn ? n | $msbs1 : n & $msbs0;
                        UncheckedBInt{$R,$Td}( nn )
                        )
        else
                error( "Type range not supported for % operator" )
        end
end
@generated function %{Tn <: Integer,R,T}( n::Tn, ::Type{ BInt{R,T} } )
        l,u = get_range_bounds(R)

        if is_unsigned_binary_range( l, u )
                nbits = number_of_bits_unsigned(u)
                mask = T( ( big(1)<<nbits ) - 1 )
                return :( UncheckedBInt{$R,$T}( $T(n) & $mask ) )
        elseif is_signed_2sComplement_range( l, u )
                nbits = number_of_bits_signed(u) -1
                return :(
                        # nn = sign_extend_from( n, $nbits );
                        b = $nbits;
                        sgn = ( n >> b ) & 1 == 1;
                        msbs = sgn ? ~zero(n) << b : ~( ~zero(n)<<b );

                        nn = sgn ? n | msbs : n & msbs;
                        UncheckedBInt{$R,$T}( nn )
                        )
        else
                error( "Type range not supported for % operator\nRHS BInt needs power of two range" )
        end
end
