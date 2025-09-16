# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe ::RemoteDevelopment::DevfileOperations::RestrictionsEnforcer, feature_category: :workspaces do
  include ResultMatchers

  include_context "with remote development shared fixtures"

  let(:main_component_indicator_attribute) do
    RemoteDevelopment::RemoteDevelopmentConstants::MAIN_COMPONENT_INDICATOR_ATTRIBUTE
  end

  let(:input_devfile) { read_devfile(input_devfile_name) }
  let(:context) { { devfile: input_devfile } }

  subject(:result) do
    described_class.enforce(context)
  end

  context "for devfiles containing no violations" do
    shared_examples "an ok result" do
      it "returns an ok Result containing the original context" do
        expect(result).to eq(Gitlab::Fp::Result.ok(context))
      end
    end

    using RSpec::Parameterized

    where(:input_devfile_name) do
      %w[
        example.default_devfile.yaml.erb
        example.devfile.yaml.erb
        example.flattened-devfile.yaml.erb
        example.flattened-with-entries-devfile.yaml.erb
        example.multi-entry-devfile.yaml.erb
      ]
    end

    with_them do
      it_behaves_like "an ok result"

      context "when both devfile and processed_devfile are passed in the context" do
        let(:context) { { devfile: {}, processed_devfile: input_devfile } }

        it_behaves_like "an ok result"
      end
    end
  end

  context "for devfiles containing violations" do
    shared_examples "an err result" do
      it "returns an err Result containing error details" do
        is_expected.to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::DevfileRestrictionsFailed)
          message.content => { details: String => error_details, context: Hash => actual_context }
          expect(error_details).to eq(error_str)
          expect(actual_context).to eq(context)
        end
      end
    end

    context "for single-array-entry devfiles" do
      using RSpec::Parameterized::TableSyntax

      # rubocop:disable Layout/LineLength -- we want single lines for RSpec::Parameterized::TableSyntax
      where(:input_devfile_name, :error_str) do
        "example.invalid-attributes-tools-injector-absent-devfile.yaml.erb" | "No component has '#{main_component_indicator_attribute}' attribute"
        "example.invalid-attributes-tools-injector-multiple-devfile.yaml.erb" | "Multiple components '[\"tooling-container\", \"tooling-container-2\"]' have '#{main_component_indicator_attribute}' attribute"
        "example.invalid-component-missing-name.yaml.erb" | "Components must have a 'name'"
        "example.invalid-command-missing-component-devfile.yaml.erb" | "'exec' command 'missing-component-command' must specify a 'component'"
        "example.invalid-components-attributes-container-overrides-devfile.yaml.erb" | "Attribute 'container-overrides' is not yet supported"
        "example.invalid-components-attributes-pod-overrides-devfile.yaml.erb" | "Attribute 'pod-overrides' is not yet supported"
        "example.invalid-components-entry-empty-devfile.yaml.erb" | "No components present in devfile"
        "example.invalid-components-entry-missing-devfile.yaml.erb" | "No components present in devfile"
        "example.invalid-invalid-schema-version-devfile.yaml.erb" | "Invalid 'schemaVersion' 'example'"
        "example.invalid-no-elements-devfile.yaml.erb" | "No components present in devfile"
        "example.invalid-no-elements-flattened-devfile.yaml.erb" | "No components present in devfile"
        "example.invalid-restricted-prefix-command-apply-component-name-devfile.yaml.erb" | "Component name 'gl-example' for command id 'example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-command-exec-component-name-devfile.yaml.erb" | "Component name 'gl-example' for command id 'example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-command-name-devfile.yaml.erb" | "Command id 'gl-example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-component-container-endpoint-name-devfile.yaml.erb" | "Endpoint name 'gl-example' of component 'example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-component-name-devfile.yaml.erb" | "Component name 'gl-example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-event-type-prestart-name-devfile.yaml.erb" | "Event 'gl-example' of type 'preStart' must not start with 'gl-'"
        "example.invalid-restricted-prefix-variable-name-devfile.yaml.erb" | "Variable name 'gl-example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-command-apply-label-devfile.yaml.erb" | "Label 'gl-example' for command id 'example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-command-exec-label-devfile.yaml.erb" | "Label 'gl-example' for command id 'example' must not start with 'gl-'"
        "example.invalid-restricted-prefix-variable-name-with-underscore-devfile.yaml.erb" | "Variable name 'gl_example' must not start with 'gl_'"
        "example.invalid-root-attributes-pod-overrides-devfile.yaml.erb" | "Attribute 'pod-overrides' is not yet supported"
        "example.invalid-unsupported-command-exec-hot-reload-capable-option-devfile.yaml.erb" | "Property 'hotReloadCapable' for exec command 'unsupported-hot-reload-option' must be false when specified"
        "example.invalid-unsupported-command-exec-options-devfile.yaml.erb" | "Unsupported options 'unsupportedOption' for exec command 'unsupported-options'. Only 'commandLine, component, label, hotReloadCapable' are supported."
        "example.invalid-unsupported-command-type-devfile.yaml.erb" | "Command 'composite-command' must have one of the supported command types: exec, apply"
        "example.invalid-unsupported-command-type-poststart-event-devfile.yaml.erb" | "PostStart event references command 'apply-command' which is not an exec command. Only exec commands are supported in postStart events"
        "example.invalid-unsupported-component-container-dedicated-pod-devfile.yaml.erb" | "Property 'dedicatedPod' of component 'example' is not yet supported"
        "example.invalid-unsupported-component-type-image-devfile.yaml.erb" | "Component type 'image' is not yet supported"
        "example.invalid-unsupported-component-type-kubernetes-devfile.yaml.erb" | "Component type 'kubernetes' is not yet supported"
        "example.invalid-unsupported-component-type-openshift-devfile.yaml.erb" | "Component type 'openshift' is not yet supported"
        "example.invalid-unsupported-event-type-poststop-devfile.yaml.erb" | "Event type 'postStop' is not yet supported"
        "example.invalid-unsupported-event-type-prestop-devfile.yaml.erb" | "Event type 'preStop' is not yet supported"
        "example.invalid-unsupported-parent-inheritance-devfile.yaml.erb" | "Inheriting from 'parent' is not yet supported"
        "example.invalid-unsupported-projects-devfile.yaml.erb" | "'projects' is not yet supported"
        "example.invalid-unsupported-schema-version-devfile.yaml.erb" | "'schemaVersion' '2.0.0' is not supported, it must be '2.2.0'"
        "example.invalid-unsupported-starter-projects-devfile.yaml.erb" | "'starterProjects' is not yet supported"
      end
      # rubocop:enable Layout/LineLength

      with_them do
        it_behaves_like "an err result"

        context "when both devfile and processed_devfile are passed in the context" do
          let(:context) { { devfile: {}, processed_devfile: input_devfile } }

          it_behaves_like "an err result"
        end
      end
    end

    context "for multi-array-entry devfiles" do
      # NOTE: This context guards against the incorrect usage of
      #       `return Gitlab::Fp::Result.ok(context) unless condition`
      #       guard clauses within iterator blocks in the validator logic.
      #       Because the behavior of `return` in Ruby is to return from the entire containing method,
      #       regardless of how many blocks you are nexted within, this would result in early returns
      #       which do not process all entries which are being iterated over.

      using RSpec::Parameterized::TableSyntax

      # rubocop:disable Layout/LineLength -- we want single lines for RSpec::Parameterized::TableSyntax
      where(:input_devfile_name, :error_str) do
        "example.invalid-multi-component-devfile.yaml.erb" | "Component name 'gl-example-invalid-second-component' must not start with 'gl-'"
        "example.invalid-multi-endpoint-devfile.yaml.erb" | "Endpoint name 'gl-example-invalid-second-endpoint' of component 'example-invalid-second-component' must not start with 'gl-'"
        "example.invalid-multi-command-devfile.yaml.erb" | "Component name 'gl-example-invalid-component' for command id 'example-invalid-second-component-command' must not start with 'gl-'"
        "example.invalid-multi-event-devfile.yaml.erb" | "Event 'gl-example' of type 'preStart' must not start with 'gl-'"
        "example.invalid-multi-variable-devfile.yaml.erb" | "Variable name 'gl-example-invalid' must not start with 'gl-'"
      end
      # rubocop:enable Layout/LineLength

      with_them do
        it_behaves_like "an err result"
      end
    end

    context "for devfile size validation" do
      let(:input_devfile_name) { "example.devfile.yaml.erb" }

      context "when devfile exceeds maximum size" do
        before do
          json_string = input_devfile.to_json
          allow(input_devfile).to receive(:to_json).and_return(json_string)
          allow(json_string).to receive(:bytesize).and_return(3.megabytes + 1)
        end

        it "returns an err Result with size exceeded message" do
          is_expected.to be_err_result do |message|
            expect(message).to be_a(RemoteDevelopment::Messages::DevfileRestrictionsFailed)
            message.content => { details: String => error_details, context: Hash => actual_context }
            expect(error_details).to match(/Devfile size .* exceeds the maximum allowed size/)
            expect(actual_context).to eq(context)
          end
        end
      end
    end
  end
end
