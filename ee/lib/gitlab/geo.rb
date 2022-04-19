# frozen_string_literal: true

module Gitlab
  module Geo
    OauthApplicationUndefinedError = Class.new(StandardError)
    GeoNodeNotFoundError = Class.new(StandardError)
    InvalidDecryptionKeyError = Class.new(StandardError)
    InvalidSignatureTimeError = Class.new(StandardError)

    CACHE_KEYS = %i(
      primary_node
      secondary_nodes
      node_enabled
      oauth_application
      proxy_extra_data
    ).freeze

    API_SCOPE = 'geo_api'
    GEO_PROXIED_HEADER = 'HTTP_GITLAB_WORKHORSE_GEO_PROXY'
    GEO_PROXIED_EXTRA_DATA_HEADER = 'HTTP_GITLAB_WORKHORSE_GEO_PROXY_EXTRA_DATA'

    # TODO: Avoid having to maintain a list. Discussions related to possible
    # solutions can be found at
    # https://gitlab.com/gitlab-org/gitlab/-/issues/227693
    REPLICATOR_CLASSES = [
      ::Geo::LfsObjectReplicator,
      ::Geo::MergeRequestDiffReplicator,
      ::Geo::PackageFileReplicator,
      ::Geo::TerraformStateVersionReplicator,
      ::Geo::SnippetRepositoryReplicator,
      ::Geo::GroupWikiRepositoryReplicator,
      ::Geo::PipelineArtifactReplicator,
      ::Geo::PagesDeploymentReplicator,
      ::Geo::UploadReplicator,
      ::Geo::JobArtifactReplicator
    ].freeze

    # We "regenerate" an 1hour valid JWT every 30 minutes, resulting in
    # a token valid for at least 30 minutes at every given time, even if
    # the internal API is not available to serve a new one for up to 30m.
    # The primary shouldn't hard fail if this isn't valid, it just doesn't
    # know the proxying node.
    PROXY_JWT_VALIDITY_PERIOD = 1.hour
    PROXY_JWT_CACHE_EXPIRY = 30.minutes

    def self.current_node
      self.cache_value(:current_node, as: GeoNode) { GeoNode.current_node }
    end

    def self.primary_node
      self.cache_value(:primary_node, as: GeoNode) { GeoNode.primary_node }
    end

    def self.secondary_nodes
      self.cache_value(:secondary_nodes, as: GeoNode) { GeoNode.secondary_nodes }
    end

    def self.proxy_extra_data
      self.cache_value(:proxy_extra_data, l2_cache_expires_in: PROXY_JWT_CACHE_EXPIRY) { uncached_proxy_extra_data }
    end

    def self.uncached_proxy_extra_data
      # Extra data that can be computed/sent for all proxied requests.
      #
      # We're currently only interested in the signing node which can
      # be figured out from the signing key, so not sending any actual
      # extra data.
      data = {}

      Gitlab::Geo::SignedData.new(geo_node: self.current_node, validity_period: PROXY_JWT_VALIDITY_PERIOD)
        .sign_and_encode_data(data)
    rescue GeoNodeNotFoundError, OpenSSL::Cipher::CipherError
      nil
    end

    def self.connected?
      # GeoNode#connected? only attempts to use existing DB connections so it can't
      # be relied upon in initializers, without this active DB connectivity check.
      active_db_connection = GeoNode.connection_pool.with_connection(&:active?) rescue false

      active_db_connection && GeoNode.table_exists?
    end

    def self.enabled?
      self.cache_value(:node_enabled) { GeoNode.exists? }
    end

    def self.primary?
      self.enabled? && self.current_node&.primary?
    end

    def self.secondary?
      self.enabled? && self.current_node&.secondary?
    end

    def self.current_node_misconfigured?
      self.enabled? && self.current_node.nil?
    end

    def self.current_node_enabled?
      # No caching of the enabled! If we cache it and an admin disables
      # this node, an active Geo::RepositorySyncWorker would keep going for up
      # to max run time after the node was disabled.
      Gitlab::Geo.current_node.reset.enabled?
    end

    def self.geo_database_configured?
      ::Gitlab::Database.has_config?(:geo)
    end

    def self.primary_node_configured?
      Gitlab::Geo.primary_node.present?
    end

    def self.secondary_with_primary?
      self.secondary? && self.primary_node_configured?
    end

    def self.secondary_with_unified_url?
      self.secondary_with_primary? && self.primary_node.url == self.current_node.url
    end

    def self.proxied_request?(env)
      env[GEO_PROXIED_HEADER] == '1'
    end

    def self.proxied_site(env)
      return unless ::Gitlab::Geo.primary?
      return unless proxied_request?(env) && env[GEO_PROXIED_EXTRA_DATA_HEADER].present?

      signed_data = Gitlab::Geo::SignedData.new
      signed_data.decode_data(env[GEO_PROXIED_EXTRA_DATA_HEADER])

      signed_data.geo_node
    end

    def self.license_allows?
      ::License.feature_available?(:geo)
    end

    def self.configure_cron_jobs!
      manager = CronManager.new
      manager.create_watcher!
      manager.execute
    end

    def self.oauth_authentication
      return unless Gitlab::Geo.secondary?

      self.cache_value(:oauth_application) do
        Gitlab::Geo.current_node.oauth_application || raise(OauthApplicationUndefinedError)
      end
    end

    def self.l1_cache
      SafeRequestStore[:geo_l1_cache] ||=
        Gitlab::JsonCache.new(namespace: :geo, backend: ::Gitlab::ProcessMemoryCache.cache_backend, cache_key_strategy: :version)
    end

    def self.l2_cache
      SafeRequestStore[:geo_l2_cache] ||= Gitlab::JsonCache.new(namespace: :geo, cache_key_strategy: :version)
    end

    # Default to a short expire time as we can't manually expire on a secondary node
    # so short-lived or data that can get frequently updated doesn't persist too much
    def self.cache_value(raw_key, as: nil, l1_cache_expires_in: 1.minute, l2_cache_expires_in: 2.minutes, &block)
      l1_cache.fetch(raw_key, as: as, expires_in: l1_cache_expires_in) do
        l2_cache.fetch(raw_key, as: as, expires_in: l2_cache_expires_in) { yield }
      end
    end

    def self.expire_cache!
      expire_cache_keys!(CACHE_KEYS)
    end

    def self.expire_cache_keys!(keys)
      keys.each do |key|
        l1_cache.expire(key)
        l2_cache.expire(key)
      end

      true
    end

    def self.generate_access_keys
      # Inspired by S3
      {
        access_key: generate_random_string(20),
        secret_access_key: generate_random_string(40)
      }
    end

    def self.generate_random_string(size)
      # urlsafe_base64 may return a string of size * 4/3
      SecureRandom.urlsafe_base64(size)[0, size]
    end

    def self.repository_verification_enabled?
      Feature.enabled?(:geo_repository_verification, default_enabled: true)
    end

    def self.allowed_ip?(ip)
      allowed_ips = ::Gitlab::CurrentSettings.current_application_settings.geo_node_allowed_ips

      Gitlab::CIDR.new(allowed_ips).match?(ip)
    end

    def self.interacting_with_primary_message(url)
      return unless url

      # This is formatted like this to fit into the console 'box', e.g.
      #
      # remote:
      # remote: This request to a Geo secondary node will be forwarded to the
      # remote: Geo primary node:
      # remote:
      # remote:   <url>
      # remote:
      template = <<~STR
        This request to a Geo secondary node will be forwarded to the
        Geo primary node:

          %{url}
      STR

      _(template) % { url: url }
    end

    def self.enabled_replicator_classes
      REPLICATOR_CLASSES.select(&:enabled?)
    end

    def self.verification_enabled_replicator_classes
      REPLICATOR_CLASSES.select(&:verification_enabled?)
    end

    # Returns the maximum number of concurrent verification jobs per Replicator
    # class.
    #
    # On the primary:
    #
    # - Geo::VerificationBatchWorker will run up to this many instances of
    #   itself, for each Replicator class with verification enabled.
    # - Geo::RepositoryVerification::Primary::ShardWorker will run up to this
    #   many concurrent Geo::RepositoryVerification::Primary::SingleWorker
    #   jobs.
    #
    # On each secondary:
    #
    # - Geo::VerificationBatchWorker will run up to this many instances of
    #   itself, for each Replicator class with verification enabled.
    # - Geo::RepositoryVerification::Secondary::ShardWorker will run up to this
    #   many concurrent Geo::RepositoryVerification::Secondary::SingleWorker
    #   jobs.
    #
    # @return [Integer] the maximum number of concurrent verification jobs per Replicator class
    def self.verification_max_capacity_per_replicator_class
      num_legacy_verification_schedulers = 1 # it handles both Projects and Wikis
      num_verifiable_replicator_classes = verification_enabled_replicator_classes.size + num_legacy_verification_schedulers

      capacity = current_node.verification_max_capacity / num_verifiable_replicator_classes

      [1, capacity].max # at least 1
    end

    def self.uncached_queries(&block)
      raise 'No block given' unless block_given?

      ApplicationRecord.uncached do
        if ::Gitlab::Geo.secondary?
          ::Geo::TrackingBase.uncached(&block)
        else
          yield
        end
      end
    end
  end
end
