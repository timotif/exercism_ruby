class SimpleCalculator
  ALLOWED_OPERATIONS = ['+', '/', '*'].freeze

  class UnsupportedOperation < StandardError
  end

  def self.calculate(first_operand, second_operand, operation)
    if not ALLOWED_OPERATIONS.include?(operation)
      raise UnsupportedOperation.new("Operation not supported")
    end
    if not first_operand.is_a?(Integer) or not second_operand.is_a?(Integer)
      raise ArgumentError.new("Wrong argument")
    end
    case operation
    when '+'
      result = first_operand + second_operand
    when '/'
      begin
        result = first_operand / second_operand
      rescue ZeroDivisionError 
        return "Division by zero is not allowed."
      end
    when '*'
      result = first_operand * second_operand
    end
    "#{first_operand} #{operation} #{second_operand} = #{result}"
  end
end
