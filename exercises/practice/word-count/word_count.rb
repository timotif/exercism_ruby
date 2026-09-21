=begin
Write your code for the 'Word Count' exercise in this file. Make the tests in
`word_count_test.rb` pass.

To get started with TDD, see the `README.md` file in your
`ruby/word-count` directory.
=end
class Phrase
  def initialize(phrase)
    # @data = phrase.scan(/(?:\w|(?<=\w)'(?=\w))+/).map(&:downcase)
    @data = phrase.scan(/\b[\w']+\b/).map(&:downcase)
#      - \b: Start of a word boundary.
#      - [\w']+: Match one or more characters that are either a word character
#        (\w) OR a literal apostrophe (').
#      - \b: End of a word boundary.
  end

  def word_count
    @data.tally
  end
end
