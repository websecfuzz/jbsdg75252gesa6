# frozen_string_literal: true

direct :about_trial do |params|
  uri = Addressable::URI.join(about_url, '/free-trial')
  uri.query_values = params if params.present?
  uri.to_s
end
