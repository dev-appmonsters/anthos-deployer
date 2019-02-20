# frozen_string_literal: true

module AnthosDeployer
  module Helm
    class Base < BaseInteraction
      string :context, :chart_path, :chart_name, :namespace

      validates :logger, :context, :chart_path, :chart_name, :namespace, presence: true

      hash :values_overrides, strip: false, default: nil

      private

      def add_namespace_to_helm_args
        helm_args.push('--namespace', namespace)
      end

      def add_chart_path_to_helm_args
        helm_args.push(chart_path)
      end

      def add_values_overrides
        to_dotted_hash(values_overrides).each do |k, v|
          helm_args.push('--set', "#{k}=#{interpolate_from_env(v)}")
        end
      end

      def interpolate_from_env(value)
        val = value
        if val.to_s.start_with?('$')
          val = ENV[value[1..-1]]
          raise "#{value} not found in environment" if val.blank?
        end
        val
      end

      # Source: https://stackoverflow.com/a/xyz
      def to_dotted_hash(source, target = {}, namespace = nil)
        prefix = "#{namespace}." if namespace
        case source
        when Hash
          source.each do |key, value|
            to_dotted_hash(value, target, "#{prefix}#{key}")
          end
        when Array
          source.each_with_index do |value, index|
            to_dotted_hash(value, target, "#{prefix}#{index}")
          end
        else
          target[namespace] = source
        end
        target
      end

      def helm
        @helm ||= AnthosDeployer::Helm::Client.new(context: context, logger: logger, log_failure_by_default: true)
      end
    end
  end
end
