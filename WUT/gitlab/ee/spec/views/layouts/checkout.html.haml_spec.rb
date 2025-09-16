# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/checkout' do
  it_behaves_like 'a layout which reflects the application color mode setting'
  it_behaves_like 'a layout which reflects the preferred language'
end
