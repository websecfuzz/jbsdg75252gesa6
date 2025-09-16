import { createAppOptions } from 'ee/ci/pipeline_details/pipeline_tabs';
import { DASHBOARD_TYPE_PIPELINE } from 'ee/security_dashboard/constants';
import findingsQuery from 'ee/security_dashboard/graphql/queries/pipeline_findings.query.graphql';
import { dataset } from 'ee_jest/security_dashboard/mock_data/pipeline_report_dataset';
import { createAlert } from '~/alert';

const mockCeOptions = {
  foo: 'bar',
};

jest.mock('~/ci/pipeline_details/pipeline_tabs', () => ({
  createAppOptions: () => mockCeOptions,
}));
jest.mock('~/alert');

describe('createAppOptions', () => {
  const EL_ID = 'EL_ID';

  let el;

  const createElement = () => {
    el = document.createElement('div');
    el.id = EL_ID;
    el.dataset.vulnerabilityReportData = JSON.stringify(dataset);

    document.body.appendChild(el);
  };

  afterEach(() => {
    el = null;
    document.body.innerHTML = '';
  });

  it('merges EE options with CE ones', () => {
    createElement();
    const options = createAppOptions(`#${EL_ID}`, null);

    expect(createAlert).not.toHaveBeenCalled();
    expect(options).toMatchObject({
      ...mockCeOptions,
      provide: {
        projectFullPath: dataset.projectFullPath,
        emptyStateSvgPath: dataset.emptyStateSvgPath,
        dashboardType: DASHBOARD_TYPE_PIPELINE,
        fullPath: dataset.projectFullPath,
        canAdminVulnerability: true,
        pipeline: {
          id: 500,
          iid: 43,
          jobsPath: dataset.pipelineJobsPath,
          sourceBranch: dataset.sourceBranch,
        },
        canViewFalsePositive: true,
        vulnerabilitiesQuery: findingsQuery,
      },
    });
  });

  it('returns `null` if el does not exist', () => {
    expect(createAppOptions('foo', null)).toBe(null);
  });

  it('shows an error message if options cannot be parsed and just returns CE options', () => {
    createElement();
    delete el.dataset.vulnerabilityReportData;
    const options = createAppOptions(`#${EL_ID}`, null);

    expect(createAlert).toHaveBeenCalledWith({
      message: "Unable to parse the vulnerability report's options.",
      error: expect.any(Error),
    });
    expect(options).toMatchObject(mockCeOptions);
  });
});
