# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Billing::PlanComponent, type: :component, feature_category: :subscription_management do
  include SubscriptionPortalHelpers
  using RSpec::Parameterized::TableSyntax

  where(:method_name, :error_pattern) do
    :plan_name               | /Missing plan_name implementation/
    :name                    | /Missing name implementation/
    :elevator_pitch          | /Missing elevator_pitch implementation/
    :show_upgrade_button?    | /Missing show_upgrade_button\? implementation/
    :features_elevator_pitch | /Missing features_elevator_pitch implementation/
    :features                | /Missing features implementation/
    :show_learn_more_link?   | /Missing show_learn_more_link\? implementation/
  end

  with_them do
    it 'raises NoMethodError' do
      expect { component_without(method_name) }.to raise_error(NoMethodError, error_pattern)
    end
  end

  context 'with all required methods implemented' do
    it 'renders without error' do
      expect { full_component }.not_to raise_error
    end
  end

  # Define a method to create a component with specific methods removed
  def component_without(method = nil)
    klass = stub_const('TestPlanComponent', Class.new(described_class))

    # Only implement the methods we need, excluding the one we're testing
    complete_methods = [
      :plan_name, :name, :elevator_pitch, :show_upgrade_button?,
      :features_elevator_pitch, :features, :show_learn_more_link?
    ]

    complete_methods.each do |m|
      next if m == method # Skip the method we want to test

      klass.class_eval do
        define_method(m) do
          case m
          when :plan_name then 'free'
          when :name then 'Free Plan'
          when :elevator_pitch then 'pitch'
          when :show_upgrade_button? then false
          when :features_elevator_pitch then 'features pitch'
          when :features then ['Feature 1', 'Feature 2']
          when :show_learn_more_link? then false
          end
        end
      end
    end

    plans_data = billing_plans_data.map { |plan| Hashie::Mash.new(plan) }

    render_inline(klass.new(plans_data: plans_data, namespace: nil, current_plan: Hashie::Mash.new(code: 'free')))
  end

  alias_method :full_component, :component_without
end
