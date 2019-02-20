# frozen_string_literal: true

module AnthosDeployer
  module Docker
    class Client
      def initialize(logger:, log_failure_by_default:)
        @logger = logger
        @log_failure_by_default = log_failure_by_default
      end

      def run(*args, log_failure: nil)
        log_failure = @log_failure_by_default if log_failure.nil?
        args = args.unshift('--')
        args = args.unshift('docker')
        args = args.unshift('gcloud')
        @logger.info "Executing docker command #{Shellwords.join(args)}"
        result = system(Shellwords.join(args))
        @logger.error("The following command failed: #{Shellwords.join(args)}") if !result && log_failure
        result
      end
    end
  end
end
