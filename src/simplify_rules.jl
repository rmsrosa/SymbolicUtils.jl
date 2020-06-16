using .Rewriters

let
    PLUS_RULES = [
        @rule(+(~~x::isnotflat(+)) => flatten_term(+, ~~x))
        @rule(+(~~x::!(issortedₑ)) => sort_args(+, ~~x))
        @acrule(~a::isnumber + ~b::isnumber => ~a + ~b)

        @acrule(*(~~x) + *(~β, ~~x) => *(1 + ~β, (~~x)...))
        @acrule(*(~α, ~~x) + *(~β, ~~x) => *(~α + ~β, (~~x)...))
        @acrule(*(~~x, ~α) + *(~~x, ~β) => *(~α + ~β, (~~x)...))

        @acrule(~x + *(~β, ~x) => *(1 + ~β, ~x))
        @acrule(*(~α::isnumber, ~x) + ~x => *(~α + 1, ~x))
        @rule(+(~~x::hasrepeats) => +(merge_repeats(*, ~~x)...))

        @acrule((~z::_iszero + ~x) => ~x)
        @rule(+(~x) => ~x)
    ]

    TIMES_RULES = [
        @rule(*(~~x::isnotflat(*)) => flatten_term(*, ~~x))
        @rule(*(~~x::!(issortedₑ)) => sort_args(*, ~~x))

        @acrule(~a::isnumber * ~b::isnumber => ~a * ~b)
        @rule(*(~~x::hasrepeats) => *(merge_repeats(^, ~~x)...))

        @acrule((~y)^(~n) * ~y => (~y)^(~n+1))
        @acrule((~x)^(~n) * (~x)^(~m) => (~x)^(~n + ~m))

        @acrule((~z::_isone  * ~x) => ~x)
        @acrule((~z::_iszero *  ~x) => ~z)
        @rule(*(~x) => ~x)
    ]


    POW_RULES = [
        @rule(^(*(~~x), ~y::isliteral(Integer)) => *(map(a->pow(a, ~y), ~~x)...))
        @rule((((~x)^(~p::isliteral(Integer)))^(~q::isliteral(Integer))) => (~x)^((~p)*(~q)))
        @rule(^(~x, ~z::_iszero) => 1)
        @rule(^(~x, ~z::_isone) => ~x)
    ]

    ASSORTED_RULES = [
        @rule(identity(~x) => ~x)
        @rule(-(~x) => -1*~x)
        @rule(-(~x, ~y) => ~x + -1(~y))
        @rule(~x / ~y => ~x * pow(~y, -1))
        @rule(one(~x) => one(symtype(~x)))
        @rule(zero(~x) => zero(symtype(~x)))
        @rule(cond(~x::isnumber, ~y, ~z) => ~x ? ~y : ~z)
    ]

    TRIG_RULES = [
        @acrule(sin(~x)^2 + cos(~x)^2 => one(~x))
        @acrule(sin(~x)^2 + -1        => cos(~x)^2)
        @acrule(cos(~x)^2 + -1        => sin(~x)^2)

        @acrule(tan(~x)^2 + -1*sec(~x)^2 => one(~x))
        @acrule(tan(~x)^2 +  1 => sec(~x)^2)
        @acrule(sec(~x)^2 + -1 => tan(~x)^2)

        @acrule(cot(~x)^2 + -1*csc(~x)^2 => one(~x))
        @acrule(cot(~x)^2 +  1 => csc(~x)^2)
        @acrule(csc(~x)^2 + -1 => cot(~x)^2)
    ]

    BOOLEAN_RULES = [
        @rule((true | (~x)) => true)
        @rule(((~x) | true) => true)
        @rule((false | (~x)) => ~x)
        @rule(((~x) | false) => ~x)
        @rule((true & (~x)) => ~x)
        @rule(((~x) & true) => ~x)
        @rule((false & (~x)) => false)
        @rule(((~x) & false) => false)

        @rule(!(~x) & ~x => false)
        @rule(~x & !(~x) => false)
        @rule(!(~x) | ~x => true)
        @rule(~x | !(~x) => true)
        @rule(xor(~x, !(~x)) => true)
        @rule(xor(~x, ~x) => false)

        @rule(~x == ~x => true)
        @rule(~x != ~x => false)
        @rule(~x < ~x => false)
        @rule(~x > ~x => false)

        # simplify terms with no symbolic arguments
        # e.g. this simplifies term(isodd, 3, type=Bool)
        # or term(!, false)
        @rule((~f)(~x::isnumber) => (~f)(~x))
        # and this simplifies any binary comparison operator
        @rule((~f)(~x::isnumber, ~y::isnumber) => (~f)(~x, ~y))
    ]

    function number_simplifier()
        rule_tree = [If(istree, Chain(ASSORTED_RULES)),
                     If(is_operation(+),
                        Chain(PLUS_RULES)),
                     If(is_operation(*),
                        Chain(TIMES_RULES)),
                     If(is_operation(^),
                        Chain(POW_RULES))] |> RestartedChain

        rule_tree
    end

    trig_simplifier(;kw...) = Chain(TRIG_RULES)

    bool_simplifier() = Chain(BOOLEAN_RULES)

    global default_simplifier
    global serial_simplifier
    global threaded_simplifier
    global serial_simplifier
    global serial_polynormal_simplifier

    function default_simplifier(; kw...)
        IfElse(has_trig,
               Postwalk(IfElse(x->symtype(x) <: Number,
                               Chain((number_simplifier(),
                                      trig_simplifier())),
                               If(x->symtype(x) <: Bool,
                                  bool_simplifier()))
                        ; kw...),
               Postwalk(Chain((If(x->symtype(x) <: Number,
                                  number_simplifier()),
                               If(x->symtype(x) <: Bool,
                                  bool_simplifier())))
                        ; kw...))
    end

    # reduce overhead of simplify by defining these as constant
    serial_simplifier = If(istree, Fixpoint(default_simplifier()))

    threaded_simplifier(cutoff) = Fixpoint(default_simplifier(threaded=true,
                                                              thread_cutoff=cutoff))

    serial_polynormal_simplifier = If(istree,
                                      Fixpoint(Chain((polynormalize,
                                                      Fixpoint(default_simplifier())))))

end
