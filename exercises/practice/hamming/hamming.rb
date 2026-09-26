=begin
Write your code for the 'Hamming' exercise in this file. Make the tests in
`hamming_test.rb` pass.

To get started with TDD, see the `README.md` file in your
`ruby/hamming` directory.
=end
class Hamming
  def self.compute(s1, s2)
    if s1.length != s2.length
      raise ArgumentError
    end
    # Naif approach:
    # counter = 0
    # s1.chars.each_with_index {
    #   |c, i| if c != s2[i] then counter +=1
    #   end 
    # }
    # counter
    # end
    s1.chars.zip(s2.chars).count { |c1, c2| c1 != c2 }
  end
end

