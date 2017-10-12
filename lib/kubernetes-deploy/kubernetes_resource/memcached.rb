# frozen_string_literal: true
module KubernetesDeploy
  class Memcached < KubernetesResource
    TIMEOUT = 5.minutes
    CONFIGMAP_NAME = "memcached-url"

    def sync
      _, _err, st = kubectl.run("get", type, @name)
      @found = st.success?
      @deployment_exists = memcached_deployment_exists?
      @service_exists = memcached_service_exists?
      @configmap_exists = memcached_configmap_exists?

      @status = if @deployment_exists && @service_exists && @configmap_exists
        "Provisioned"
      else
        "Unknown"
      end
    end

    def deploy_succeeded?
      @deployment_exists && @service_exists && @configmap_exists
    end

    def deploy_failed?
      false
    end

    def exists?
      @found
    end

    private

    def memcached_deployment_exists?
      deployments, _err, st = kubectl.run("get", "deployments", "-l name=#{@name}", "-o=json")
      return false unless st.success?
      parsed = JSON.parse(deployments)
      return false if parsed.fetch("items", []).count == 0
      deployment = parsed.fetch("items", []).first
      status = deployment.fetch("status", {})
      status.fetch("availableReplicas", -1) == status.fetch("replicas", 0)
    end

    def memcached_service_exists?
      services, _err, st = kubectl.run("get", "services", "-l name=#{@name}", "-o=json")
      return false unless st.success?
      parsed = JSON.parse(services)
      return false if parsed.fetch("items", []).count == 0
      service = parsed.fetch("items", []).first
      service.dig("spec", "clusterIP").present?
    end

    def memcached_configmap_exists?
      secret, _err, st = kubectl.run("get", "configmaps", CONFIGMAP_NAME, "-o=json")
      return false unless st.success?
      parsed = JSON.parse(secret)
      parsed.dig("data", @name).present?
    end
  end
end
