# frozen_string_literal: true

class ApplicationService
  class Error < StandardError; end

  class << self
    def call(...)
      new(...).call
    end

    def save(...)
      new(...).save
    end
  end

  def call
    raise NotImplementedError, "#{self.class}#call not implemented"
  end

  def save
    raise NotImplementedError, "#{self.class}#save not implemented"
  end
end
