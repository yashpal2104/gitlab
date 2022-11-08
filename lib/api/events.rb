# frozen_string_literal: true

module API
  class Events < ::API::Base
    include PaginationParams
    include APIGuard
    helpers ::API::Helpers::EventsHelpers

    allow_access_with_scope :read_user, if: -> (request) { request.get? || request.head? }

    feature_category :users
    urgency :low

    resource :events do
      desc "List currently authenticated user's events" do
        detail 'This feature was introduced in GitLab 9.3.'
        success Entities::Event
      end
      params do
        optional :action, type: String, desc: 'Include only events of a particular action type'
        optional :target_type, type: String, desc: 'Include only events of a particular target type'
        optional :before, type: DateTime, desc: 'Include only events created before a particular date'
        optional :after, type: DateTime, desc: 'Include only events created after a particular date'
        optional :scope, type: String, desc: 'Include all events across a user’s projects'
        optional :sort, type: String, desc: 'Sort events in asc or desc order by created_at. Default is desc'
        use :pagination
        use :event_filter_params
        use :sort_params
      end

      get do
        authenticate!

        events = find_events(current_user)

        present_events(events)
      end
    end

    params do
      requires :id, type: String, desc: 'The ID or username of the user'
    end
    resource :users do
      desc 'Get the contribution events of a specified user' do
        detail 'This feature was introduced in GitLab 8.13.'
        success Entities::Event
        tags %w[events]
      end
      params do
        optional :action, type: String, desc: 'Include only events of a particular action type'
        optional :target_type, type: String, desc: 'Include only events of a particular target type'
        optional :before, type: DateTime, desc: 'Include only events created before a particular date'
        optional :after, type: DateTime, desc: 'Include only events created after a particular date'
        optional :sort, type: String, desc: 'Sort events in asc or desc order by created_at. Default is desc'
        optional :page, type: Integer, desc: 'The page of results to return. Defaults to 1'
        optional :per_page, type: Integer, desc: 'The number of results per page. Defaults to 20'
        use :pagination
        use :event_filter_params
        use :sort_params
      end

      get ':id/events' do
        user = find_user(params[:id])
        not_found!('User') unless user

        events = find_events(user)

        present_events(events)
      end
    end
  end
end
