# frozen_string_literal: true

module AnthosDeployer
  class BaseInteraction < ActiveInteraction::Base
    attr_reader :logger

    validates :logger, presence: true

    def log_and_raise(msg)
      logger.error msg
      raise msg
    end
  end
end
