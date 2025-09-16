# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project mirror', :js, feature_category: :source_code_management do
  include ReactiveCachingHelpers
  include Features::MirroringHelpers

  let(:project) { create(:project, :repository, creator: user, name: 'Victorialand') }
  let(:import_state) { create(:import_state, :mirror, :finished, project: project) }
  let(:user) { create(:user) }

  describe 'On a project' do
    before do
      project.add_maintainer(user)
      sign_in user
    end

    context 'when mirror was updated successfully' do
      before do
        import_state.update!(last_successful_update_at: 5.minutes.ago)
      end

      it 'shows the last successful at timestamp' do
        visit project_mirror_path(project)

        page.within('.js-mirrors-table-body tr:nth-child(1) td:nth-child(4)') do
          expect(page).to have_content('5 minutes ago')
        end
      end
    end

    context 'when mirror was never updated successfully' do
      before do
        import_state.update!(last_successful_update_at: nil)
      end

      it 'shows that mirror has never been updated' do
        visit project_mirror_path(project)

        page.within('.js-mirrors-table-body tr:nth-child(1) td:nth-child(4)') do
          expect(page).to have_content('Never')
        end
      end
    end

    context 'with Update now button' do
      let(:timestamp) { Time.zone.now }

      before do
        import_state.update!(last_update_at: 6.minutes.ago, next_execution_timestamp: timestamp + 10.minutes)
      end

      context 'when able to force update' do
        it 'forces import' do
          travel_to(timestamp) do
            visit project_mirror_path(project)
          end

          Sidekiq::Testing.fake! do
            expect { find('.js-force-update-mirror').click }
              .to change { UpdateAllMirrorsWorker.jobs.size }
              .by(1)
          end
        end
      end

      context 'when unable to force update' do
        before do
          import_state.update!(next_execution_timestamp: timestamp - 1.minute)
        end

        let(:disabled_updating_button) { '[data-testid="updating-button"].disabled' }

        it 'disables Update now button' do
          travel_to(timestamp) do
            visit project_mirror_path(project)
          end

          expect(page).to have_selector(disabled_updating_button)
        end
      end

      context 'when the project is archived' do
        let(:disabled_update_now_button) { '[data-testid="update-now-button"].disabled' }

        before do
          project.update!(archived: true)
        end

        it 'disables Update now button' do
          visit project_mirror_path(project)

          expect(page).to have_selector(disabled_update_now_button)
        end
      end
    end
  end

  describe 'configuration' do
    # Start from a project with no mirroring set up
    let(:project) { create(:project, :repository, creator: user) }
    let(:import_data) { project.reload_import_data }

    before do
      project.add_maintainer(user)
      sign_in(user)
    end

    describe 'password authentication' do
      let(:url) { 'http://example.com' }
      let(:username) { 'user' }
      let(:password) { 'foo' }
      let(:direction) { 'Pull' }

      def add_mirror
        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', url)

          select direction, from: 'Mirror direction'
          fill_in 'Username', with: username
          fill_in 'Password', with: password
          click_without_sidekiq 'Mirror repository'
        end
      end

      it 'can be set up' do
        add_mirror

        expect(page).to have_content('Mirroring settings were successfully updated')

        project.reload
        expect(project.mirror?).to be_truthy
        expect(import_data.auth_method).to eq('password')
        expect(project.import_url).to eq('http://user:foo@example.com')
      end

      context 'when username is provided in url' do
        let(:url) { 'http://urlusername@example.com' }

        it 'will be ignored' do
          add_mirror

          expect(page).to have_content('Mirroring settings were successfully updated')

          project.reload
          expect(project.mirror?).to be_truthy
          expect(import_data.auth_method).to eq('password')
          expect(project.import_url).to eq('http://user:foo@example.com')
        end
      end

      context 'when given special characters' do
        context 'in the username' do
          let(:username) { 'u@s+e/r' }
          let(:password) { 'foo' }

          context 'when adding a pull mirror' do
            it 'escapes special characters in username' do
              add_mirror

              project.reload
              expect(project.import_url).to eq('http://u%40s%2Be%2Fr:foo@example.com')
            end
          end

          context 'when adding a push mirror' do
            let(:direction) { 'Push' }

            it 'escapes special characters in username' do # this one
              add_mirror

              project.reload
              expect(project.remote_mirrors.first.url).to eq('http://u%40s%2Be%2Fr:foo@example.com')
            end
          end
        end

        context 'in the password' do
          let(:username) { 'user' }
          let(:password) { 'f@o+o/' }

          context 'when adding a pull mirror' do
            it 'escapes special characters in password' do
              add_mirror

              project.reload
              expect(project.import_url).to eq('http://user:f%40o%2Bo%2F@example.com')
            end
          end

          context 'when adding a push mirror' do
            let(:direction) { 'Push' }

            it 'escapes special characters in the password' do # this one
              add_mirror

              project.reload
              expect(project.remote_mirrors.first.url).to eq('http://user:f%40o%2Bo%2F@example.com')
            end
          end
        end
      end

      it 'can be changed to unauthenticated', quarantine: 'https://gitlab.com/gitlab-org/quality/engineering-productivity/master-broken-incidents/-/issues/1486' do
        project.update!(import_url: 'http://user:password@example.com')

        visit project_settings_repository_path(project)

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', 'http://2.example.com')

          select('Pull', from: 'Mirror direction')
          fill_in 'Password', with: ''
          click_without_sidekiq 'Mirror repository'
        end

        expect(page).to have_content('Mirroring settings were successfully updated')

        project.reload
        expect(import_data.auth_method).to eq('password')
        expect(project.import_url).to eq('http://2.example.com')
      end

      it 'can be recreated after an SSH mirror is set' do
        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', 'ssh://example.com')

          select('Pull', from: 'Mirror direction')
          fill_in 'Username', with: 'user'
          select 'SSH public key', from: 'Authentication method'

          # Generates an SSH public key with an asynchronous PUT and displays it
          wait_for_requests

          click_without_sidekiq 'Mirror repository'
        end

        expect(page).to have_content('Mirroring settings were successfully updated')

        find('.js-delete-pull-mirror').click
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', 'http://example.com')

          select('Pull', from: 'Mirror direction')
          fill_in 'Username', with: 'git'
          fill_in 'Password', with: 'test_password'
          click_without_sidekiq 'Mirror repository'
        end

        expect(page).to have_content('Mirroring settings were successfully updated')

        project.reload
        expect(import_data.auth_method).to eq('password')
        expect(import_data.password).to eq('test_password')
        expect(project.import_url).to eq('http://git:test_password@example.com')
      end
    end

    describe 'SSH public key authentication' do
      let(:ssh_url) { 'ssh://example.com' }

      it 'can be set up' do
        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', ssh_url)

          select('Pull', from: 'Mirror direction')
          fill_in 'Username', with: 'user'
          select 'SSH public key', from: 'Authentication method'

          click_without_sidekiq 'Mirror repository'
        end
        project.reload

        expect(page).to have_content('Mirroring settings were successfully updated')
        expect(page).not_to have_content('Verified by')
        expect(find('.rspec-copy-ssh-public-key')['data-clipboard-text']).to eq(import_data.ssh_public_key)
        expect(project.mirror?).to be_truthy
        expect(project.username_only_import_url).to eq('ssh://user@example.com')
        expect(import_data.auth_method).to eq('ssh_public_key')
        expect(import_data.password).to be_blank
      end

      context 'when no username is provided' do
        it 'import url has no delimiting colon' do
          visit project_settings_repository_path(project)
          click_button('Add new')

          within_testid('mirroring-repositories-settings-content') do
            fill_and_wait_for_mirror_url_javascript('Git repository URL', ssh_url)

            select('Pull', from: 'Mirror direction')
            select 'SSH public key', from: 'Authentication method'

            click_without_sidekiq 'Mirror repository'
          end
          project.reload
          expect(project.username_only_import_url).to eq('ssh://example.com')
          expect(import_data.auth_method).to eq('ssh_public_key')
          expect(import_data.password).to be_blank
        end
      end
    end

    describe 'host key management', :use_clean_rails_memory_store_caching do
      let(:key) { Gitlab::SSHPublicKey.new(SSHData::PrivateKey::RSA.generate(3072).public_key.openssh) }
      let(:cache) { SshHostKey.new(project: project, url: "ssh://example.com:22") }
      let(:ssh_url) { 'ssh://example.com' }

      it 'fills fingerprints and host keys when detecting' do
        stub_reactive_cache(cache, known_hosts: key.key_text)

        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', ssh_url)

          select('Pull', from: 'Mirror direction')
          click_on 'Detect host keys'

          wait_for_requests

          expect(page).to have_content(key.fingerprint_sha256)

          click_on 'Input host keys manually'

          expect(page).to have_field('SSH host keys', with: key.key_text)
        end
      end

      it 'displays error if detection fails' do
        stub_reactive_cache(cache, error: 'Some error text here')

        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', ssh_url)

          select('Pull', from: 'Mirror direction')
          click_on 'Detect host keys'

          wait_for_requests
        end

        # Appears in the flash
        expect(page).to have_content('Some error text here')
      end

      it 'allows manual host keys entry' do
        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', ssh_url)

          select('Pull', from: 'Mirror direction')
          click_on 'Input host keys manually'
          fill_in 'SSH host keys', with: "example.com #{key.key_text}"
          click_without_sidekiq 'Mirror repository'

          find('.js-delete-mirror').click
          click_button('Add new')
          fill_and_wait_for_mirror_url_javascript('Git repository URL', 'ssh://example.com')

          select('Pull', from: 'Mirror direction')

          expect(page).to have_content(key.fingerprint_sha256)
          expect(page).to have_content("Verified by #{h(user.name)} less than a minute ago")
        end
      end
    end

    describe 'authentication methods' do
      it 'shows SSH related fields for an SSH URL' do
        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', 'ssh://example.com')

          select('Pull', from: 'Mirror direction')

          execute_script 'document.querySelector("html").scrollTop = 1000;'
          expect(page).to have_select('Authentication method')

          # SSH can use password authentication but needs host keys
          select 'Password', from: 'Authentication method'
          expect(page).to have_field('Password')
          expect(page).to have_button('Detect host keys')
          expect(page).to have_button('Input host keys manually')

          # SSH public key authentication also needs host keys but no password
          select 'SSH public key', from: 'Authentication method'
          expect(page).not_to have_field('Password')
          expect(page).to have_button('Detect host keys')
          expect(page).to have_button('Input host keys manually')
        end
      end

      it 'hides SSH-related fields for a HTTP URL' do
        visit project_settings_repository_path(project)
        click_button('Add new')

        within_testid('mirroring-repositories-settings-content') do
          fill_and_wait_for_mirror_url_javascript('Git repository URL', 'https://example.com')

          select('Pull', from: 'Mirror direction')

          # HTTPS can't use public key authentication and doesn't need host keys
          expect(page).to have_field('Password')
          expect(page).not_to have_select('Authentication method')
          expect(page).not_to have_button('Detect host keys')
          expect(page).not_to have_button('Input host keys manually')
        end
      end
    end

    def click_without_sidekiq(...)
      Sidekiq::Testing.fake! { click_on(...) }
    end
  end
end
