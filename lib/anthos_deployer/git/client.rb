# frozen_string_literal: true

module AnthosDeployer
  module Git
    class Client
      def initialize(logger:, git_dir:, log_failure_by_default:, output_is_sensitive: false)
        @logger = logger
        @log_failure_by_default = log_failure_by_default
        @output_is_sensitive = output_is_sensitive
        @git_dir = git_dir
      end

      def run(*args, log_failure: nil)
        log_failure = @log_failure_by_default if log_failure.nil?

        args = args.unshift(
          'git',
          "--git-dir=#{File.join(@git_dir, '.git')}"
        )

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
