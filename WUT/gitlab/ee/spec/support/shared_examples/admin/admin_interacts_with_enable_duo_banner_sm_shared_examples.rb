# frozen_string_literal: true

RSpec.shared_examples 'admin interacts with enable duo banner sm' do
  context 'with banner interactions' do
    let(:banner_content) { 'Code Suggestions and Chat are now available in supported IDEs' }

    it 'dismisses the banner' do
      expect(page).to have_content(banner_content)

      within_testid('enable-duo-banner-sm') do
        find('.gl-banner-close').click
      end

      expect_banner_to_be_dismissed

      page.refresh

      expect_banner_to_be_dismissed
    end

    it 'enables duo core settings and dismisses the banner' do
      expect(page).to have_content(banner_content)

      within_testid('enable-duo-banner-sm') do
        click_button 'Enable GitLab Duo Core'
      end

      expect(page).to have_content('By enabling GitLab Duo, you accept the GitLab AI functionality terms.')

      click_button 'Enable'

      expect(page).to have_content('GitLab Duo Core is now enabled.')
      expect_banner_to_be_dismissed

      page.refresh

      expect_banner_to_be_dismissed
    end

    def expect_banner_to_be_dismissed
      expect(page).not_to have_content(banner_content)
    end
  end
end
