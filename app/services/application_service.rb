class ApplicationService
  class Error < StandardError; end

  def self.call(...)
    new(...).call
  end

  def self.save(...)
    new(...).save
  end

  def call
    raise NotImplementedError, "#{self.class}#call not implemented"
  end

  def save
    raise NotImplementedError, "#{self.class}#save not implemented"
  end
end
