# frozen_string_literal: true

module AnthosDeployer
  module Helm
    class ChartUpgrader < Base
      array :helm_args, default: -> { ['upgrade'] }

      class HelmChartUpgradationError < KubernetesDeploy::FatalDeploymentError
        def initialize(msg)
          super("Helm chart updation failed: #{msg}")
        end
      end

      def execute
        log_start
        build_args
        out, err, st = helm.run(*helm_args)
        handle_output(out, err, st)
        [out, err, st]
      end

      private

      def log_start
        logger.phase_heading("Building arguments for Helm Upgrade of Chart: #{chart_name}")
        logger.info("Executing upgrade of Chart: #{chart_name}")
      end

      def build_args
        add_chart_name_to_helm_args
        add_chart_path_to_helm_args
        add_values_overrides if values_overrides.present?
      end

      def handle_output(out, err, st)
        logger.debug(out)
        return if st.success?
        logger.error("Error: Executing upgrade of Chart: #{chart_name}, #{err}")
        raise HelmChartUpgradationError, err
      end

      def add_chart_name_to_helm_args
        helm_args.push(chart_name)
      end
    end
  end
end
