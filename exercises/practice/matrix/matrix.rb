=begin
Write your code for the 'Matrix' exercise in this file. Make the tests in
`matrix_test.rb` pass.

To get started with TDD, see the `README.md` file in your
`ruby/matrix` directory.
=end
class Matrix
  def initialize(matrix)
    @data = matrix.split("\n").map { |row| row.split.map(&:to_i) }
  end

  def row(n)
    @data[n - 1]
  end

  def column(n)
    @data.transpose[n - 1]
  end
end

