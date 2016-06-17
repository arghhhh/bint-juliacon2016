
macro dshow( args... )
        local d = esc( :debug_print )
        return :( if $d ; @show( debug_print ) ;  @show( $(args...) ); end )
end

macro dprint( args... )
        local d = esc( :debug_print )
        return :( if $d ; print( $(args...) ); end )
end


macro dd( args... )
        if isdefined( :implement_debug_print ) && implement_debug_print
                local d = esc( :debug_print )
                return :( if $d ; $(args...) ; end )
        else
                return :()
        end
end
