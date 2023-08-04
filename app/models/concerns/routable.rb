# frozen_string_literal: true

# Store object full path in separate table for easy lookup and uniq validation
# Object must have name and path db fields and respond to parent and parent_changed? methods.
module Routable
  extend ActiveSupport::Concern
  include CaseSensitivity

  # Finds a Routable object by its full path, without knowing the class.
  #
  # Usage:
  #
  #     Routable.find_by_full_path('groupname')             # -> Group
  #     Routable.find_by_full_path('groupname/projectname') # -> Project
  #
  # Returns a single object, or nil.
  def self.find_by_full_path(path, follow_redirects: false, route_scope: Route, redirect_route_scope: RedirectRoute)
    return unless path.present?

    # Convert path to string to prevent DB error: function lower(integer) does not exist
    path = path.to_s

    # Case sensitive match first (it's cheaper and the usual case)
    # If we didn't have an exact match, we perform a case insensitive search
    #
    # We need to qualify the columns with the table name, to support both direct lookups on
    # Route/RedirectRoute, and scoped lookups through the Routable classes.
    Gitlab::Database.allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/420046") do
      route =
        route_scope.find_by(routes: { path: path }) ||
        route_scope.iwhere(Route.arel_table[:path] => path).take

      if follow_redirects
        route ||= redirect_route_scope.iwhere(RedirectRoute.arel_table[:path] => path).take
      end

      next unless route

      route.is_a?(Routable) ? route : route.source
    end
  end

  included do
    # Remove `inverse_of: source` when upgraded to rails 5.2
    # See https://github.com/rails/rails/pull/28808
    has_one :route, as: :source, autosave: true, dependent: :destroy, inverse_of: :source # rubocop:disable Cop/ActiveRecordDependent
    has_many :redirect_routes, as: :source, autosave: true, dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent

    validates :route, presence: true, unless: -> { is_a?(Namespaces::ProjectNamespace) }

    scope :with_route, -> { includes(:route) }

    after_validation :set_path_errors

    before_validation :prepare_route
    before_save :prepare_route # in case validation is skipped
  end

  class_methods do
    # Finds a single object by full path match in routes table.
    #
    # Usage:
    #
    #     Klass.find_by_full_path('gitlab-org/gitlab-foss')
    #
    # Returns a single object, or nil.
    def find_by_full_path(path, follow_redirects: false)
      # TODO: Optimize these queries by avoiding joins
      # https://gitlab.com/gitlab-org/gitlab/-/issues/292252
      Routable.find_by_full_path(
        path,
        follow_redirects: follow_redirects,
        route_scope: includes(:route).references(:routes),
        redirect_route_scope: joins(:redirect_routes)
      )
    end

    # Builds a relation to find multiple objects by their full paths.
    #
    # Usage:
    #
    #     Klass.where_full_path_in(%w{gitlab-org/gitlab-foss gitlab-org/gitlab})
    #
    # Returns an ActiveRecord::Relation.
    def where_full_path_in(paths, use_includes: true)
      return none if paths.empty?

      wheres = paths.map do |path|
        "(LOWER(routes.path) = LOWER(#{connection.quote(path)}))"
      end

      route =
        if use_includes
          includes(:route).references(:routes)
        else
          joins(:route)
        end

      route
        .where(wheres.join(' OR '))
        .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/420046")
    end
  end

  def full_name
    full_attribute(:name)
  end

  def full_path
    full_attribute(:path)
  end

  # Overriden in the Project model
  # parent_id condition prevents issues with parent reassignment
  def parent_loaded?
    association(:parent).loaded?
  end

  def route_loaded?
    association(:route).loaded?
  end

  def full_path_components
    full_path.split('/')
  end

  def build_full_path
    if parent && path
      parent.full_path + '/' + path
    else
      path
    end
  end

  # Group would override this to check from association
  def owned_by?(user)
    owner == user
  end

  private

  # rubocop: disable GitlabSecurity/PublicSend
  def full_attribute(attribute)
    attribute_from_route_or_self = ->(attribute) do
      route&.public_send(attribute) || send("build_full_#{attribute}")
    end

    unless persisted? && Feature.enabled?(:cached_route_lookups, self, type: :ops)
      return attribute_from_route_or_self.call(attribute)
    end

    # Return the attribute as-is if the parent is missing
    return public_send(attribute) if route.nil? && parent.nil? && public_send(attribute).present?

    # If the route is already preloaded, return directly, preventing an extra load
    return route.public_send(attribute) if route_loaded? && route.present? && route.public_send(attribute)

    # Similarly, we can allow the build if the parent is loaded
    return send("build_full_#{attribute}") if parent_loaded?

    Gitlab::Cache.fetch_once([cache_key, :"full_#{attribute}"]) do
      attribute_from_route_or_self.call(attribute)
    end
  end
  # rubocop: enable GitlabSecurity/PublicSend

  def set_path_errors
    route_path_errors = self.errors.delete(:"route.path")
    route_path_errors&.each do |msg|
      self.errors.add(:path, msg)
    end
  end

  def full_name_changed?
    name_changed? || parent_changed?
  end

  def full_path_changed?
    path_changed? || parent_changed?
  end

  def build_full_name
    if parent && name
      parent.human_name + ' / ' + name
    else
      name
    end
  end

  def prepare_route
    return unless full_path_changed? || full_name_changed?
    return if is_a?(Namespaces::ProjectNamespace)

    route || build_route(source: self)
    route.path = build_full_path
    route.name = build_full_name
    route.namespace = if is_a?(Namespace)
                        self
                      elsif is_a?(Project)
                        self.project_namespace
                      end
  end
end
