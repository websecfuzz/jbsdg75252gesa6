# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module MirroringRepositories
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/views/projects/mirrors/_mirror_repos_form.html.haml' do
                  element 'mirror-direction-field'
                end

                view 'ee/app/views/projects/mirrors/_table_pull_row.html.haml' do
                  element 'mirror-last-update-at-content'
                  element 'mirror-repository-url-content'
                  element 'mirrored-repository-row-container'
                  element 'update-now-button'
                  element 'copy-public-key-button'
                end
              end
            end
          end
        end
      end
    end
  end
end
