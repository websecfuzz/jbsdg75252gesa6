# frozen_string_literal: true

Gitlab::Seeder.quiet do
  ::Ai::Setting.create!(Ai::Setting.defaults)
end
