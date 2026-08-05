=begin
Write your code for the 'Acronym' exercise in this file. Make the tests in
`acronym_test.rb` pass.

To get started with TDD, see the `README.md` file in your
`ruby/acronym` directory.
=end
module Acronym
#  def self.abbreviate(words)
#    words.split(/[ -]/)
#      .each
#      .map { |word| 
#        word.chars.find { |char|
#          char.match(/[a-zA-Z]/) }
#      }
#      .join
#      .upcase
#  end
  def self.abbreviate(words)
    words
      .gsub(/[^a-zA-Z0-9\s\-]/, "")  # delete everything but alphanum, spaces and -
      .scan(/\w+/)                   # split into words (returns array)
      .map { |word| word[0].upcase } # extract first char (illegal ones were already stripped) and capitalize
      .join                          # combine into final acronym
  end
end
