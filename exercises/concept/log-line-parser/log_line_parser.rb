class LogLineParser
  def initialize(line)
    @line = line
  end

  def message
    @line.split(":")[1].strip
  end

  def log_level
    @line.split(":")[0].downcase.slice(1..-2)
  end

  def reformat
    "#{self.message} (#{log_level})"
  end
end
