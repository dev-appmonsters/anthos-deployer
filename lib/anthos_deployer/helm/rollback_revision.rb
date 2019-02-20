# frozen_string_literal: true

module AnthosDeployer
  module Helm
    class RollbackRevision < BaseInteraction
      string :release_name, :context

      integer :revision

      validates :release_name, :revision, :context, presence: true

      array :helm_args, default: -> { ['rollback'] }

      class HelmChartRollbackError < KubernetesDeploy::FatalDeploymentError
        def initialize(msg)
          super("Helm chart revision rollback failed: #{msg}")
        end
      end

      def execute
        log_start
        helm_args.push(release_name, revision.to_s)
        out, err, st = helm.run(*helm_args)
        handle_output(out, err, st)
        [out, err, st]
      end

      private

      def log_start
        logger.phase_heading("Building arguments for Helm rollback of Chart: #{release_name}")
        logger.info("Executing rollback of Chart: #{release_name} to revision #{revision}")
      end

      def handle_output(out, err, st)
        logger.debug(out)
        return if st.success?
        logger.error("Error: Executing rollback of Chart: #{release_name} to revision: #{revision} , #{err}")
        raise HelmChartRollbackError, err
      end

      def helm
        @helm ||= AnthosDeployer::Helm::Client.new(context: context, logger: logger, log_failure_by_default: true)
      end
    end
  end
end
