# frozen_string_literal: true

module AnthosDeployer
  module Helm
    class Client
      def initialize(context:, logger:, log_failure_by_default:, default_timeout: '30s',
                     output_is_sensitive: false)
        @context = context
        @logger = logger
        @log_failure_by_default = log_failure_by_default
        @default_timeout = default_timeout
        @output_is_sensitive = output_is_sensitive

        raise ArgumentError, 'context is required' if context.blank?
      end

      def run(*args, log_failure: nil, use_context: true)
        log_failure = @log_failure_by_default if log_failure.nil?

        args = args.unshift('helm')
        args.push("--kube-context=#{@context}") if use_context

        @logger.debug Shellwords.join(args)
        out, err, st = Open3.capture3(*args)
        @logger.debug(out.shellescape) unless output_is_sensitive?

        if !st.success? && log_failure
          @logger.warn("The following command failed: #{Shellwords.join(args)}")
          @logger.warn(err) unless output_is_sensitive?
        end
        [out.chomp, err.chomp, st]
      end

      private

      def output_is_sensitive?
        @output_is_sensitive
      end
    end
  end
end
