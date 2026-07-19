class AssemblyLine
  def initialize(speed)
    @speed = speed
  end

  CARS_PER_HOUR = 221
  def production_rate_per_hour
    @success_rate = 1
    if @speed >= 5 && @speed <= 8
      @success_rate = 0.9
    elsif @speed == 9
      @success_rate = 0.8
    elsif @speed == 10
      @success_rate = 0.77
    end
    (CARS_PER_HOUR * @speed * @success_rate)
  end

  def working_items_per_minute
    (self.production_rate_per_hour / 60).to_i
  end
end
