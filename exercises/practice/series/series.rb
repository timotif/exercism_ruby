=begin
Write your code for the 'Series' exercise in this file. Make the tests in
`series_test.rb` pass.

To get started with TDD, see the `README.md` file in your
`ruby/series` directory.
=end
class Series
  def initialize(serie)
    raise ArgumentError if serie.empty?
    @serie = serie
  end

  def slices(n)
    raise ArgumentError if n <= 0 or n > @serie.length
    # SOLUTION 1: naive
    # start = 0
    # ret = []
    # while @serie.length >= start + n
    #   ret.push(@serie[start...start + n])
    #   start += 1
    # end
    # ret
    # SOLUTION 2: more idiomatic using each_cons
    # ret = []
    # @serie.chars.each_cons(n) { |element| ret.push(element.join) }
    # ret
    # SOLUTION 3: proper Ruby
    @serie.chars.each_cons(n).map(&:join)
  end
end
