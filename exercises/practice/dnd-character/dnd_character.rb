=begin
Write your code for the 'D&D Character' exercise in this file. Make the tests in
`dnd_character_test.rb` pass.

To get started with TDD, see the `README.md` file in your
`ruby/dnd-character` directory.
=end

class DndCharacter
  ATTR = %i[constitution strength dexterity intelligence wisdom charisma]
  attr_reader *ATTR, :hitpoints

  def self.modifier(constitution)
    # Your code here
  ((constitution - 10) / 2).floor 
  end

  def roll
  4.times.map { rand(1..6) }.max(3).sum
  end

  def initialize
    ATTR.map { |stat| self.instance_variable_set("@#{stat}", self.roll) }
    @hitpoints = 10 + DndCharacter.modifier(@constitution)
  end
end
