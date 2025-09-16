# frozen_string_literal: true

module QA
  RSpec.describe 'Monitor', product_group: :platform_insights do
    describe 'Create incident' do
      let(:project) { create(:project, name: 'project-for-incident', description: 'Project for incident') }
      let!(:incident_label) { create(:project_label, project: project, title: 'incident') }
      let(:incident) { create(:incident, project: project, description: incident_description) }
      let(:incident_description) do
        <<~CONTENT
          /zoom https://zoom.us/j/123456789
          /label ~incident
          /severity 3
        CONTENT
      end

      before do
        Flow::Login.sign_in
        incident.visit!
      end

      it(
        'adds linked resources, label, and severity through quick actions',
        :aggregate_failures,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/428793'
      ) do # See https://gitlab.com/gitlab-org/gitlab/-/issues/423943
        Page::Project::Monitor::Incidents::Show.perform do |show|
          expect(show).to have_label(incident_label.title)
          expect(show).to have_severity('Medium - S3')
          expect(show).to have_linked_resource('Zoom #123456789')
          expect(show.linked_resources_count).to equal(1)
        end
      end
    end
  end
end
