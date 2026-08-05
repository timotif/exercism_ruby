=begin
Write your code for the 'Resistor Color Duo' exercise in this file. Make the tests in
`resistor_color_duo_test.rb` pass.

To get started with TDD, see the `README.md` file in your
`ruby/resistor-color-duo` directory.
=end
VALUES = {
  black: 0,
  brown: 1,
  red: 2,
  orange: 3,
  yellow: 4,
  green: 5,
  blue: 6,
  violet: 7,
  grey: 8,
  white: 9,
}

module ResistorColorDuo
  def self.value(colors)
    res = 0
    colors[..1].reverse.each_with_index { |color, exponent| res += VALUES[color.to_sym] * 10**exponent } 
    res
  end
end

# ResistorColorDuo.value(%w[grey white])
