# frozen_string_literal: true

module AnthosDeployer
  module AnthosResource
    class ChartDeployment < AnthosDeployer::BaseInteraction
      class GitRevParseChartDeploymentHashError < KubernetesDeploy::FatalDeploymentError
      end

      string :name, :config_context_dir, :context, :namespace

      hash :config, strip: false

      string :chart_path, default: proc { File.join(config_context_dir, config[:chart_path]) }

      hash :current_deployed_state, strip: false

      validates :name, :namespace, :context, :chart_path,
                :config, :config_context_dir, :current_deployed_state, presence: true

      def execute; end

      def additional_deployments
        config[:additional_deployments]
      end

      def additional_deployments?
        additional_deployments.present?
      end

      # This only works for single kubenetes deployment where the neame is similar to helm chart release
      def kube_deployment_name
        current_deployed_state[name]&.fetch(:kube_deployment, nil)
      end

      def should_wait_for_rollout?
        currently_deployed = (needs_helm_upgrade? || needs_helm_install?)
        return true if additional_deployments? && currently_deployed
        kube_deployment_name.present? && currently_deployed
      end

      def old_revision
        current_deployed_state.dig(name.to_sym, :helm, :revision)
      end

      def docker_context
        File.join(config_context_dir, config[:docker_context])
      end

      def chart_overrides
        config[:chart_overrides]
      end

      def require_common_code?
        config[:require_common_code]
      end

      def requires_docker_image_push?
        config[:docker_context].present? && (needs_helm_upgrade? || needs_helm_install?)
      end

      def installation_commands
        config[:install_cmds]
      end

      def pre_upgrade_commands
        config[:pre_upgrade_cmds]
      end

      def needs_deployment_to_be_patched?
        return true if config[:patch_after_commands]
        return true if installation_commands.present? && needs_helm_install?
        return true if pre_upgrade_commands.present? && needs_helm_upgrade?
      end

      def needs_helm_upgrade?
        return true if config[:always_upgrade]
        installed? && config[:docker_context].present? &&
          (
            service_code_hash != deployed_service_hash ||
            !deployment_working_fine? ||
            deployed_config_digest != config_digest ||
            (current_deployed_state[name][:database_state] && !database_state_ok?)
          )
      end

      def needs_helm_install?
        !installed?
      end

      def installed?
        current_deployed_state[name] && current_deployed_state[name][:helm].present? && deployed_chart_revision.present?
      end

      def deployed_service_hash
        current_deployed_state[name][:service_hash]
      end

      KUBE_DEPLOYMENT_OK_STATUS = 'True'
      def deployment_working_fine?
        current_deployed_state[name] && current_deployed_state[name][:status] == KUBE_DEPLOYMENT_OK_STATUS
      end

      KUBE_DEPLOYMENT_DB_STATUS_OK_STATUS = 'OK'
      def database_state_ok?
        current_deployed_state[name][:database_state] == KUBE_DEPLOYMENT_DB_STATUS_OK_STATUS
      end

      def deployed_chart_revision
        current_deployed_state[name][:helm][:revision]
      end

      def service_code_hash
        out = git_rev_parse_service_hash(name)
        out += "-#{git_rev_parse_service_hash('common')}" if require_common_code?
        out
      end

      def git_rev_parse_service_hash(service)
        out, err, st = git.run('rev-parse', '--short=30', "HEAD:#{service}")
        logger.debug(out)
        raise GitRevParseChartDeploymentHashError, err unless st.success?
        out.to_s
      end

      def deployed_config_digest
        current_deployed_state[name][:config_digest]
      end

      def config_digest
        @config_digest ||= Digest::SHA256.hexdigest(chart_checksum + config.to_s)[0..62]
      end

      def chart_checksum
        files = Dir["#{chart_path}/**/*"].reject { |f| File.directory?(f) }
        content = files.map { |f| Digest::MD5.file(f) }.join
        Digest::SHA256.hexdigest(content)
      end

      def git
        @git ||= Git::Client.new(logger: logger, git_dir: config_context_dir, log_failure_by_default: true)
      end
    end
  end
end
