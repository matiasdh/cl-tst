class ApplicationService
  def self.call(**args)
    new(**args).call
  end

  def initialize(**)
    # subclasses define attributes
  end

  def call
    raise NotImplementedError
  end
end
