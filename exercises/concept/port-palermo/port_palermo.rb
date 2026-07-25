module Port
  IDENTIFIER = :PALE

  def self.get_identifier(city)
    city.slice(0..3).upcase.to_sym
  end

  def self.get_terminal(ship_identifier)
    cargo = ship_identifier[0..2].to_s
    if cargo == "OIL" or cargo == "GAS"
      :A
    else
      :B
    end
  end
end
