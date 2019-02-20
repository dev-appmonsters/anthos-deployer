# frozen_string_literal: true

module AnthosDeployer
  module Helm
    class GetHelmInstallations < BaseInteraction
      string :context

      HELM_NAME_INDEX = 0
      HELM_REVISION_INDEX = 1
      HELM_UPDATED_INDEX = 2
      HELM_STATUS_INDEX = 3
      HELM_CHART_INDEX = 4
      HELM_NAMESPACE_INDEX = 5

      class GetHelmInstallationsError < KubernetesDeploy::FatalDeploymentError
      end

      class HelmListOutputParseError < KubernetesDeploy::FatalDeploymentError
      end

      def execute
        {}.tap do |helm_installations|
          parse_helm_list_output.each do |chart|
            helm_installations[chart[HELM_NAME_INDEX]] = {
              revision: chart[HELM_REVISION_INDEX].to_i,
              updated: Time.parse(chart[HELM_UPDATED_INDEX]),
              status: chart[HELM_STATUS_INDEX],
              chart: chart[HELM_CHART_INDEX],
              namespace: chart[HELM_NAMESPACE_INDEX]
            }
          end
        end
      end

      private

      def test_helm_output_columns(heading_columns)
        heading_columns.each_with_index do |column, i|
          raise HelmListOutputParseError unless self.class.const_get("HELM_#{column}_INDEX") == i
        end
      end

      def parse_helm_list_output
        output = helm_list_output.split("\n").map { |s| s.split("\t").map(&:strip) }
        test_helm_output_columns(output.first)
        output.shift
        output
      end

      def helm_list_output
        @helm_list_output ||= execute_helm_list
      end

      def execute_helm_list
        out, err, st = helm.run('list')
        logger.debug(out)
        raise GetHelmInstallationsError, err unless st.success?
        out
      end

      def helm
        @helm ||= AnthosDeployer::Helm::Client.new(context: context, logger: logger, log_failure_by_default: true)
      end
    end
  end
end
