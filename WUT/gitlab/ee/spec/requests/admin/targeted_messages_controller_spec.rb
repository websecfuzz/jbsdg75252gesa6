# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::TargetedMessagesController, :enable_admin_mode, :saas, feature_category: :acquisition do
  let_it_be(:admin) { create(:admin) }
  let(:targeted_message) { build(:targeted_message) }

  before do
    sign_in(admin)
  end

  describe 'GET #index' do
    it 'renders index template' do
      get admin_targeted_messages_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:index)
    end
  end

  describe 'GET #new' do
    it 'renders new template' do
      get new_admin_targeted_message_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    before do
      targeted_message.save!
    end

    it 'renders edit template' do
      get edit_admin_targeted_message_path(targeted_message)
      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:edit)
    end
  end

  describe 'POST #create' do
    let_it_be(:targeted_namespace_ids) { create_list(:namespace, 2).map(&:id) }
    let(:invalid_namespace_ids) { [] }
    let(:targeted_message_params) do
      { targeted_message: targeted_message.attributes.merge(namespace_ids_csv: csv_file) }
    end

    let(:csv_content) { (targeted_namespace_ids + invalid_namespace_ids).map(&:to_s).join("\n") }
    let(:csv_file) do
      temp_file = Tempfile.new(%w[namespace_ids csv])
      temp_file.write(csv_content)
      temp_file.rewind

      fixture_file_upload(temp_file.path, 'text/csv')
    end

    after do
      csv_file.unlink
    end

    context 'when successful' do
      it 'redirects to index on success' do
        expect do
          post admin_targeted_messages_path, params: targeted_message_params
        end.to change { Notifications::TargetedMessage.count }.by(1)

        expect(response).to redirect_to(admin_targeted_messages_path)
        expect(flash[:notice]).to eq('Targeted message was successfully created.')
      end
    end

    context 'when there are invalid namespace ids' do
      let(:invalid_namespace_ids) { [non_existing_record_id] }

      it 'renders the edit page' do
        expect do
          post admin_targeted_messages_path, params: targeted_message_params
        end.to change { Notifications::TargetedMessage.count }.by(1)

        expect(flash[:alert]).to eq(
          "Targeted message was successfully created. But the following namespace ids " \
            "were invalid and have been ignored: #{non_existing_record_id}"
        )
        expect(response).to render_template(:edit)
      end
    end

    context 'when on failure' do
      let(:targeted_message_params) do
        { targeted_message: { target_type: '', namespace_ids_csv: csv_file } }
      end

      it 'renders the new page' do
        expect { post admin_targeted_messages_path, params: targeted_message_params }.not_to change {
          Notifications::TargetedMessage.count
        }

        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    let_it_be(:targeted_namespace_ids) { create_list(:namespace, 2).map(&:id) }
    let(:invalid_namespace_ids) { [] }
    let(:targeted_message_params) do
      { targeted_message: targeted_message.attributes.merge(namespace_ids_csv: csv_file) }
    end

    let(:csv_content) { (targeted_namespace_ids + invalid_namespace_ids).map(&:to_s).join("\n") }
    let(:temp_file) do
      temp_file = Tempfile.new(%w[namespace_ids csv])
      temp_file.write(csv_content)
      temp_file.rewind

      temp_file
    end

    let(:csv_file) { fixture_file_upload(temp_file.path, 'text/csv') }

    after do
      temp_file.unlink
    end

    before do
      targeted_message.save!
    end

    context 'when successful' do
      it 'redirects to index on success' do
        patch admin_targeted_message_path(targeted_message), params: targeted_message_params

        expect(response).to redirect_to(admin_targeted_messages_path)
        expect(flash[:notice]).to eq('Targeted message was successfully updated.')
      end
    end

    context 'when there are invalid namespace ids' do
      let(:invalid_namespace_ids) { [non_existing_record_id] }

      it 'renders the edit page' do
        patch admin_targeted_message_path(targeted_message), params: targeted_message_params

        expect(flash[:alert]).to eq(
          "Targeted message was successfully updated. But the following namespace ids " \
            "were invalid and have been ignored: #{non_existing_record_id}"
        )
        expect(response).to render_template(:edit)
      end
    end

    context 'when on failure' do
      let(:targeted_message_params) do
        { targeted_message: { target_type: '', namespace_ids_csv: csv_file } }
      end

      it 'renders the new page on failure' do
        patch admin_targeted_message_path(targeted_message), params: targeted_message_params

        expect(response).to render_template(:edit)
      end
    end
  end
end
