# frozen_string_literal: true

scope path: :uploads do
  # Note attachments and User/Group/Project/Topic avatars
  get "-/system/:model/:mounted_as/:id/:filename",
      to: "uploads#show",
      constraints: { model: %r{note|user|group|project|projects\/topic|achievements\/achievement}, mounted_as: /avatar|attachment/, filename: %r{[^/]+} }

  # show uploads for models, snippets (notes) available for now
  get '-/system/:model/:id/:secret/:filename',
    to: 'uploads#show',
    constraints: { model: /personal_snippet|user/, id: /\d+/, filename: %r{[^/]+} }

  # show temporary uploads
  get '-/system/temp/:secret/:filename',
    to: 'uploads#show',
    constraints: { filename: %r{[^/]+} }

  # Appearance
  get "-/system/:model/:mounted_as/:id/:filename",
      to: "uploads#show",
      constraints: { model: /appearance/, mounted_as: /logo|header_logo|pwa_icon|favicon/, filename: /.+/ },
      as: 'appearance_upload'

  # create uploads for models, snippets (notes) available for now
  post ':model',
    to: 'uploads#create',
    constraints: { model: /personal_snippet|user/, id: /\d+/ },
    as: 'upload'

  post ':model/authorize',
    to: 'uploads#authorize',
    constraints: { model: /personal_snippet|user/ }

  # Alert Metric Images
  get "-/system/:model/:mounted_as/:id/:filename",
      to: "uploads#show",
      constraints: { model: /alert_management_metric_image/, mounted_as: /file/, filename: %r{[^/]+} },
      as: 'alert_metric_image_upload'
end

# Redirect old note attachments path to new uploads path.
get "files/note/:id/:filename",
  to: redirect("uploads/note/attachment/%{id}/%{filename}"),
  constraints: { filename: %r{[^/]+} }
