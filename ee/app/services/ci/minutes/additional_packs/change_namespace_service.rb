# frozen_string_literal: true

module Ci
  module Minutes
    module AdditionalPacks
      class ChangeNamespaceService < ::Ci::Minutes::AdditionalPacks::BaseService
        ChangeNamespaceError = Class.new(StandardError)

        def initialize(current_user, namespace, target)
          @current_user = current_user
          @namespace = namespace
          @target = target
        end

        def execute
          authorize_current_user!

          validate_namespaces!
          validate_owners!

          Ci::Minutes::AdditionalPack.transaction do
            update_packs
            reset_ci_minutes!

            success
          end
        rescue ChangeNamespaceError => e
          error(e.message)
        end

        private

        attr_reader :current_user, :namespace, :target

        def additional_packs
          @additional_packs ||= namespace.ci_minutes_additional_packs
        end

        def update_packs
          return unless additional_packs.any?

          additional_packs.update_all(namespace_id: target.id)
        end

        def validate_namespaces!
          raise ChangeNamespaceError, 'Namespace must be provided' unless namespace.present?
          raise ChangeNamespaceError, 'Target namespace must be provided' unless target.present?
          raise ChangeNamespaceError, 'Namespace must be a top-level namespace' unless namespace.root?
          raise ChangeNamespaceError, 'Target namespace must be a top-level namespace' unless target.root?
          raise ChangeNamespaceError, 'Namespace and target must be different' if namespace == target
        end

        def validate_owners!
          shared_ids = owner_ids_for(namespace) & owner_ids_for(target)

          raise ChangeNamespaceError, 'Both namespaces must share the same owner' unless shared_ids.any?
        end

        def reset_ci_minutes!
          ::Ci::Minutes::RefreshCachedDataService.new(namespace).execute
          ::Ci::Minutes::RefreshCachedDataService.new(target).execute
        end

        def owner_ids_for(namespace)
          namespace.user? ? Array(namespace.owner_id) : namespace.owner_ids
        end
      end
    end
  end
end
