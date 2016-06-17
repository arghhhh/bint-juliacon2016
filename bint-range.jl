
# only want to automatically determine the type for holding data T
# when it is not given.
# But do want to assert at compile time that the given type has suitable
# typemin and typemax to hold the range expected

# the use case is making an array of BInt{ 1:10, UInt8 }
# rather than the default BInt{ 1:10, Int64 }

# needs to a Number for promotions to work:
# immutable BInt{ R, T } <: Number

function range_within_range( xl, xu, range_l, range_u )
        range_l <= xl <= range_u && range_l <= xu <= range_u
end

function range_within_range( r1, r2 )
        l1,u1 = get_range_bounds( r1 )
        l2,u2 = get_range_bounds( r2 )
        range_within_range( l1, u1, l2, u2 )
end

function range_union( r1, r2 )
        l1,u1 = get_range_bounds( r1 )
        l2,u2 = get_range_bounds( r2 )
        return make_range( min(l1,l2), max(u1,u2) )
end

function default_int_type( range )
         l,u = get_range_bounds( range )
         T = if range_within_range( l,u, typemin( Int64 ), typemax( Int64 ) )
                 Int64
         elseif range_within_range( l,u, typemin( Int128 ), typemax( Int128 ) )
                 Int128
         else
                 BigInt
         end
         T
end

 # make constructors for above that take a range - and does the
 # number of bits calculation

 function is_signed_2sComplement_range( lo, hi )
         if lo != -hi-1
                 return false
         end
         p = nextpow2( hi )
         p_lo = -p
         p_hi = p-1
         return lo == p_lo && hi == p_hi
 end
 function is_unsigned_binary_range( lo, hi )
         if lo != 0
                 return false
         end
         p = nextpow2( hi )
         p_hi = p-1
         return hi == p_hi
 end

 number_of_bits_unsigned(x::Integer) = x<=0 ? 0 : ndigits(x,2)
 number_of_bits_signed(x::Integer)   = x==0 ? 0 : 1 + (x<0 ? number_of_bits_unsigned(-x-1) : number_of_bits_unsigned(x) )

 function signed_2sComplement_range( lo, hi )
         p1 = lo < 0 ? nextpow2( -lo ) : 0
         p2 = nextpow2( hi )
         p = max( p1, p2 )
         return SignedN(p)
 end

 function unsigned_binary_range( lo, hi )
         assert( lo >= 0 )
         p2 = nextpow2( hi )
         p = max( p1, p2 )
         return UnsignedN(p)
 end

immutable UnsignedN
        n::Int
        UnsignedN( n::Int ) = new(n)
end
immutable SignedN
        n::Int
        SignedN( n::Int ) = new(n)
end

# # Note the difference between the following
# Might need to change this if this is confusing...
# julia> SignedN( 50 )
# SignedN(50)
#
# julia> SignedN( 50:50 )
# SignedN(7)

function UnsignedN( r )
        l,u = get_range_bounds( r )
        UnsignedN( max( number_of_bits_unsigned(l), number_of_bits_unsigned(u) ) )
end

function SignedN( r )
        l,u = get_range_bounds( r )
        SignedN( max( number_of_bits_signed(l), number_of_bits_signed(u) ) )
end


immutable BigRange{ Lower, Upper }
end


get_range_bounds( n::UnsignedN ) = big( 0 ), big(1)<<n.n - 1
get_range_bounds( n::SignedN ) = -big(1)<<(n.n - 1), big(1)<<(n.n - 1) -1
get_range_bounds{ L, U }( r::BigRange{ L, U } ) = big( from_type_constant( L ) ), big( from_type_constant( U ) )
get_range_bounds( n::UnitRange ) = big( n.start ), big( n.stop )
get_range_bounds( n::Integer ) = big( n ), big( n )
get_range_bounds( n::DataType ) = big( typemin(n) ), big( typemax(n) )
get_range_bounds( n::Tuple ) = big( from_type_constant( n ) ), big( from_type_constant( n ) )


function get_range_bounds{T}( r, ::Type{T} )
        l,u = get_range_bounds( r )
        return T(l), T(u)
end

@generated function Base.typemin{R,T}( ::Type{ BInt{R,T} } )
        l,u = get_range_bounds( R )
        return T(l)
end
@generated function Base.typemax{R,T}( ::Type{ BInt{R,T} } )
        l,u = get_range_bounds( R )
        return T(u)
end
@generated function Base.typemin{R}( ::Type{ BInt{R} } )
        T = default_int_type(R)
        l,u = get_range_bounds( R )
        return T( l )
end
@generated function Base.typemax{R}( ::Type{ BInt{R} } )
        T = default_int_type(R)
        l,u = get_range_bounds( R )
        return T( u )
end


 # want this to make a UnitRange if the range values allow
 # else make a BigRange
 # either way - it must be a bitstype
 # so UnitRange{ BigInt } won't work
 function make_range( lower::Integer, upper::Integer )
        if     range_within_range( lower, upper, typemin(Int64 ), typemax(Int64 ) )
                return Int64( lower):Int64( upper)
        elseif range_within_range( lower, upper, typemin(Int128), typemax(Int128) )
                return Int128(lower):Int128(upper)
        else
                return BigRange{ to_type_constant(lower), to_type_constant( upper ) }()
        end
 end

# Is this used?
# # a range specified by a single number is just a constant
# # - can only take on a single value
#  function make_range( n::Integer )
#          return to_type_constant(n)
#  end
