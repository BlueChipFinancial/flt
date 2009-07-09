require 'flt/num'

module Flt

class BinNum < Num

  class << self
    # Numerical base.
    def radix
      2
    end

    # Integral power of the base: radix**n for integer n; returns an integer.
    def int_radix_power(n)
      (n < 0) ? (2**n) : (1<<n)
    end

    # Multiply by an integral power of the base: x*(radix**n) for x,n integer;
    # returns an integer.
    def int_mult_radix_power(x,n)
      x * ((n < 0) ? (2**n) : (1<<n))
    end

    # Divide by an integral power of the base: x/(radix**n) for x,n integer;
    # returns an integer.
    def int_div_radix_power(x,n)
      x / ((n < 0) ? (2**n) : (1<<n))
    end
  end

  # This is the Context class for Flt::BinNum.
  #
  # The context defines the arithmetic context: rounding mode, precision,...
  #
  # BinNum.context is the current (thread-local) context for DecNum numbers.
  class Context < Num::ContextBase

    # See Flt::Num::ContextBase#new() for the valid options
    #
    # See also the context constructor method Flt::Num.Context().
    def initialize(*options)
      super(BinNum, *options)
    end

    # The special values are normalized for binary floats: this keeps the context precision in the values
    # which will be used in conversion to decimal text to yield more natural results.

    # Normalized epsilon; see Num::Context.epsilon()
    def epsilon(sign=+1)
      super.normalize
    end

    # Normalized strict epsilon; see Num::Context.epsilon()
    def strict_epsilon(sign=+1)
      super.normalize
    end

    # Normalized strict epsilon; see Num::Context.epsilon()
    def half_epsilon(sign=+1)
      super.normalize

    end

  end # BinNum::Context

  class <<self # BinNum class methods

    def base_coercible_types
      unless defined? @base_coercible_types
        @base_coercible_types = super.merge(
          Float=>lambda{|x, context|
            if x.nan?
              BinNum.nan
            elsif x.infinite?
              BinNum.infinity(x<0 ? -1 : +1)
            elsif x.zero?
              BinNum.zero((x.to_s[0,1].strip=="-") ? -1 : +1)
            else
              coeff, exp = Math.frexp(x)
              coeff = Math.ldexp(coeff, Float::MANT_DIG).to_i
              exp -= Float::MANT_DIG
              if coeff < 0
                sign = -1
                coeff = -coeff
              else
                sign = +1
              end
              Num(sign, coeff, exp)
            end
          }
        )
      end
      @base_coercible_types
    end

  end

  # the DefaultContext is the base for new contexts; it can be changed.
  # DefaultContext = BinNum::Context.new(
  #                            :precision=>113,
  #                            :emin=> -16382, :emax=>+16383,
  #                            :rounding=>:half_even,
  #                            :flags=>[],
  #                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
  #                            :ignored_flags=>[],
  #                            :capitals=>true,
  #                            :clamp=>true)
  DefaultContext = BinNum::Context.new(
                             :exact=>false, :precision=>53, :rounding=>:half_even,
                             :emin=> -1025, :emax=>+1023,                             :flags=>[],
                             :traps=>[DivisionByZero, Overflow, InvalidOperation],
                             :ignored_flags=>[],
                             :capitals=>true,
                             :clamp=>true)

  ExtendedContext = BinNum::Context.new(DefaultContext,
                             :traps=>[], :flags=>[], :clamp=>false)

  IEEEHalfContext = BinNum::Context.new(
                            :precision=>1,
                            :emin=> -14, :emax=>+15,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEESingleContext = BinNum::Context.new(
                            :precision=>24,
                            :emin=> -126, :emax=>+127,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEEDoubleContext = BinNum::Context.new(
                            :precision=>53,
                            :emin=> -1022, :emax=>+1023,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEEQuadContext = BinNum::Context.new(
                            :precision=>113,
                            :emin=> -16382, :emax=>+16383,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  IEEEExtendedContext = BinNum::Context.new(
                            :precision=>64,
                            :emin=> -16382, :emax=>+16383,
                            :rounding=>:half_even,
                            :flags=>[],
                            :traps=>[DivisionByZero, Overflow, InvalidOperation],
                            :ignored_flags=>[],
                            :capitals=>true,
                            :clamp=>true)

  if Float::RADIX==2
    FloatContext = BinNum::Context.new(
                               :precision=>Float::MANT_DIG,
                               :rounding=>Support::AuxiliarFunctions.detect_float_rounding,
                               :emin=>Float::MIN_EXP-1, :emax=>Float::MAX_EXP+1,
                               :flags=>[],
                               :traps=>[DivisionByZero, Overflow, InvalidOperation],
                               :ignored_flags=>[],
                               :capitals=>true,
                               :clamp=>true)
  end


  # A BinNum value can be defined by:
  # * A String containing a decimal text representation of the number
  # * An Integer
  # * A Rational
  # * A Float
  # * Another BinNum value.
  # * A sign, coefficient and exponent (either as separate arguments, as an array or as a Hash with symbolic keys).
  #   This is the internal representation of DecNum, as returned by DecNum#split.
  #   The sign is +1 for plus and -1 for minus; the coefficient and exponent are
  #   integers, except for special values which are defined by :inf, :nan or :snan for the exponent.
  # * Any other type for which custom conversion is defined in the context.
  #
  # An optional Context can be passed as the last argument to override the current context; also a hash can be passed
  # to override specific context parameters.
  #
  # Except for custome defined conversions and text (String) input, BinNums are constructed with the precision
  # specified by the input parameters (i.e. with the exact value specified by the parameters)
  # and the context precision is ignored. If the BinNum is defined by a decimal text numeral, it is converted
  # to a binary BinNum using the context precision.
  #
  # The Flt.BinNum() constructor admits the same parameters and can be used as a shortcut for DecNum creation.
  def initialize(*args)
    super(*args)
  end

  def number_of_digits
    @coeff.is_a?(Integer) ? _nbits(@coeff) : 0
  end

  # Convert to a text literal in the specified base (10 by default).
  #
  # If the output base is 2, the rendered value is the exact value of the BinNum;
  # showing also trailing zeros, just as for DecNum.
  #
  # With bases different from 2, like the default 10, the BinNum number is treated
  # as an approximation with a precision of number_of_digits. The conversioin renders
  # that aproximation in other base without introducing additional precision.
  #
  # The resulting text numeral is such that it has as few digits as possible while
  # preserving the original while if converted back to BinNum with
  # the same context precision that the original number had (number_of_digits).
  #
  # To render teh exact value of the BinNum in decimal this can be used instead:
  #   x.to_decimal_exact.to_s
  #
  # Options:
  # :base output base, 10 by default
  #
  # :any_rounding if true he text literal will have enough digits to be
  # converted back to self in any rounding mode. Otherwise only enough
  # digits for conversion in the rounding mode specified by the context
  # are produced.
  #
  # :all_digits if true all significant digits are shown. A digit
  # is considered as significant here if when used on input, cannot
  # arbitrarily change its value and preserve the parsed value of the
  # floating point number.
  def to_s(*args)
    eng=false
    context=nil

    # admit legacy arguments eng, context in that order
    if [true,false].include?(args.first)
      eng = args.shift
    end
    if args.first.is_a?(BinNum::Context)
      context = args.shift
    end
    # admit also :eng to specify the eng mode
    if args.first == :eng
      eng = true
      args.shift
    end
    raise TypeError, "Invalid arguments to BinNum#to_s" if args.size>1 || (args.size==1 && !args.first.is_a?(Hash))
    # an admit arguments through a final parameters Hash
    options = args.first || {}
    context = options.delete(:context) if options.has_key?(:context)
    eng = options.delete(:eng) if options.has_key?(:eng)

    format(context, options.merge(:eng=>eng))
  end

  # Specific to_f conversion TODO: check if it represents an optimization
  if Float::RADIX==2
    def to_f
      if special?
        super
      else
        Math.ldexp(@sign*@coeff, @exp)
      end
    end
  end

  # Exact BinNum to DecNum conversion: preserve BinNum value.
  #
  # The current DecNum.context determines the valid range and the precision
  # (if its is not :exact the result will be rounded)
  def to_decimal_exact()
    if special?
      if nan?
        DecNum.nan
      else # infinite?
        DecNum.infinite(self.sign)
      end
    elsif zero?
      DecNum.zero(self.sign)
    else
      Flt.DecNum(@sign*@coeff)*Flt.DecNum(2)**@exp
    end
  end

  # Approximate BinNum to DecNum conversion.
  #
  # Convert to decimal so that if the decimal is converted to a BinNum of the same precision
  # and with same rounding (i.e. BinNum.from_decimal(x, context)) the value of the BinNum
  # is preserved, but use as few decimal digits as possible.
  def to_decimal(binfloat_context=nil, any_rounding=false)
    if special?
      if nan?
        DecNum.nan
      else # infinite?
        DecNum.infinite(self.sign)
      end
    elsif zero?
      DecNum.zero(self.sign)
    else
      context = define_context(binfloat_context)
      Flt.DecNum(format(context, :base=>10, :all_digits=>false, :any_rounding=>any_rounding))
    end
  end

  # Approximate BinNum to DecNum conversion apt for conversion back to BinNum with any rounding mode.
  #
  # Convert to decimal so that if the decimal is converted to a BinNum of the same precision
  # and with any rounding the value of the BinNum is preserved, but use as few decimal digits
  # as possible.
  def to_decimal_any_rounding(binfloat_context=nil)
    to_decimal(binfloat_context, true)
  end

  # DecNum to BinNum conversion.
  def BinNum.from_decimal(x, binfloat_context=nil)
    Flt.BinNum(x.to_s, binfloat_context)
  end

  # Unit in the last place: see Flt::Num#ulp()
  #
  # For BinNum the result is normalized
  def ulp(context=nil, mode=:low)
    super(context, mode).normalize(context)
  end

  private

  # Convert to a text literal in the specified base. If the result is
  # converted to BinNum with the specified context rounding and the
  # same precision that self has (self.number_of_digits), the same
  # number will be produced.
  #
  # Options:
  # :base output base, 10 by default
  #
  # :any_rounding if true he text literal will have enough digits to be
  # converted back to self in any rounding mode. Otherwise only enough
  # digits for conversion in the rounding mode specified by the context
  # are produced.
  #
  # :all_digits if true all significant digits are shown. A digit
  # is considere as significant here if when used on input, cannot
  # arbitrarily change its value and preserve the parsed value of the
  # floating point number.
  #
  # Note that when :base=>10 (the default) we're regarding the binary number x
  # as an approximation with x.number_of_digits precision and showing that
  # inexact value in decimal without introducing additional precision.
  # If the exact value of the number expressed in decimal is desired (we consider
  # the BinNum an exact number), this can be done with BinNum.to_decimal_exact(x).to_s
  def format(binfloat_context, options={})
    output_radix = options[:base] || 10
    all_digits = options[:all_digits]
    any_rounding = options[:any_rounding]
    eng = options[:eng]

    sgn = sign<0 ? '-' : ''
    if special?
      if @exp==:inf
        return "#{sgn}Infinity"
      elsif @exp==:nan
        return "#{sgn}NaN#{@coeff}"
      else # exp==:snan
        return "#{sgn}sNaN#{@coeff}"
      end
    end

    context = define_context(binfloat_context)
    inexact = true
    rounding = context.rounding unless any_rounding
    if @sign == -1
      if rounding == :ceiling
        rounding = :floor
      elsif rounding == :floor
        rounding = :ceiling
      end
    end
    x = self.abs # .to_f

    p = self.number_of_digits

    dec_pos,round_needed,*digits = Support::BurgerDybvig.float_to_digits(x,@coeff,@exp,rounding,
                                           context.etiny,p,num_class.radix,output_radix, all_digits)
    dec_pos, digits = Support::BurgerDybvig.adjust(dec_pos, round_needed, digits, output_radix)

    ds = digits.map{|d| d.to_s(output_radix)}.join
    sgn = ((sign==-1) ? '-' : '')
    n_ds = ds.size
    exp = dec_pos - n_ds
    leftdigits = dec_pos

    # TODO: DRY (this code is duplicated in DecNum#to_s)
    if exp<=0 && leftdigits>-6
      dotplace = leftdigits
    elsif !eng
      dotplace = 1
    elsif @coeff==0
      dotplace = (leftdigits+1)%3 - 1
    else
      dotplace = (leftdigits-1)%3 + 1
    end

    if dotplace <=0
      intpart = '0'
      fracpart = '.' + '0'*(-dotplace) + ds
    elsif dotplace >= n_ds
      intpart = ds + '0'*(dotplace - n_ds)
      fracpart = ''
    else
      intpart = ds[0...dotplace]
      fracpart = '.' + ds[dotplace..-1]
    end

    if leftdigits == dotplace
      e = ''
    else
      e = (context.capitals ? 'E' : 'e') + "%+d"%(leftdigits-dotplace)
    end

    sgn + intpart + fracpart + e

  end

end

module_function
def BinNum(*args)
  BinNum.Num(*args)
end


end # Flt