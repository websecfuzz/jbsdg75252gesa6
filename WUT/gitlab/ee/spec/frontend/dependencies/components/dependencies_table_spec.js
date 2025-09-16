import { GlBadge, GlLink, GlSkeletonLoader, GlLoadingIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DependenciesTable from 'ee/dependencies/components/dependencies_table.vue';
import DependencyLicenseLinks from 'ee/dependencies/components/dependency_license_links.vue';
import DependencyVulnerabilities from 'ee/dependencies/components/dependency_vulnerabilities.vue';
import DependencyLocationCount from 'ee/dependencies/components/dependency_location_count.vue';
import DependencyProjectCount from 'ee/dependencies/components/dependency_project_count.vue';
import DependencyLocation from 'ee/dependencies/components/dependency_location.vue';
import { DEPENDENCIES_TABLE_I18N, NAMESPACE_ORGANIZATION } from 'ee/dependencies/constants';
import stubChildren from 'helpers/stub_children';
import waitForPromises from 'helpers/wait_for_promises';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';
import { makeDependency } from './utils';

describe('DependenciesTable component', () => {
  let wrapper;
  const vulnerabilityInfo = {
    1: ['bar', 'baz'],
  };

  const basicAppProps = {
    namespaceType: 'project',
    endpoint: 'endpoint',
    locationsEndpoint: 'endpoint',
  };

  const createComponent = ({ propsData, provide } = {}) => {
    wrapper = mountExtended(DependenciesTable, {
      propsData: { vulnerabilityInfo: {}, ...propsData },
      stubs: {
        ...stubChildren(DependenciesTable),
        GlTable: false,
        DependencyLocation: false,
        DependencyProjectCount: false,
        DependencyLocationCount: false,
      },
      provide: {
        ...basicAppProps,
        ...provide,
      },
    });
  };

  const findTableRows = () => wrapper.findAll('tbody > tr');
  const findRowToggleButtons = () => wrapper.findAllByTestId('row-toggle-button');
  const findDependencyVulnerabilities = () => wrapper.findComponent(DependencyVulnerabilities);
  const findDependencyLocation = () => wrapper.findComponent(DependencyLocation);
  const findDependencyLocationCount = () => wrapper.findComponent(DependencyLocationCount);
  const findDependencyProjectCount = () => wrapper.findComponent(DependencyProjectCount);
  const findDependencyPathButtons = () => wrapper.findAllByTestId('dependency-path-button');
  const findDependencyPathDrawer = () => wrapper.findComponent(DependencyPathDrawer);
  const findDependencyLicenseLinks = (licenseCell) =>
    licenseCell.findComponent(DependencyLicenseLinks);
  const normalizeWhitespace = (string) => string.replace(/\s+/g, ' ');
  const loadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const sharedExpectations = (rowWrapper, dependency) => {
    const [componentCell, packagerCell, , licenseCell] = rowWrapper.findAll('td').wrappers;

    expect(normalizeWhitespace(componentCell.text())).toBe(
      `${dependency.name} ${dependency.version}`,
    );

    expect(packagerCell.text()).toBe(dependency.packager);

    expect(findDependencyLicenseLinks(licenseCell).props()).toEqual({
      licenses: dependency.licenses,
      title: dependency.name,
    });
  };
  const sharedExpectationsProjectOnly = (rowWrapper, dependency) => {
    sharedExpectations(rowWrapper, dependency);
    const [, , locationCell, , ,] = rowWrapper.findAll('td').wrappers;

    expect(findDependencyLocation().exists()).toBe(true);
    const locationLink = locationCell.findComponent(GlLink);
    expect(locationLink.attributes().href).toBe(dependency.location.blobPath);
    expect(locationLink.text()).toContain(dependency.location.path);

    expect(findDependencyLocationCount().exists()).toBe(false);
    expect(findDependencyProjectCount().exists()).toBe(false);
  };

  const expectDependencyRow = (rowWrapper, dependency) => {
    sharedExpectationsProjectOnly(rowWrapper, dependency);
    const [, , , , isVulnerableCell] = rowWrapper.findAll('td').wrappers;

    const isVulnerableCellText = normalizeWhitespace(isVulnerableCell.text());

    if (dependency?.vulnerabilities?.length) {
      expect(isVulnerableCellText).toContain(`${dependency.vulnerabilities.length} vuln`);
    } else {
      expect(isVulnerableCellText).toBe('');
    }
  };

  const expectDependencyRowWithSbom = (rowWrapper, dependency) => {
    sharedExpectationsProjectOnly(rowWrapper, dependency);
    const [, , , , isVulnerableCell] = rowWrapper.findAll('td').wrappers;

    const isVulnerableCellText = normalizeWhitespace(isVulnerableCell.text());
    const vulns = vulnerabilityInfo[dependency.occurrenceId];

    if (vulns?.length) {
      expect(isVulnerableCellText).toContain(`${vulns.length} vuln`);
    } else {
      expect(isVulnerableCellText).toBe('');
    }
  };

  const expectGroupDependencyRow = (rowWrapper, dependency) => {
    sharedExpectations(rowWrapper, dependency);
    const [, , locationCell, , projectCell, isVulnerableCell] = rowWrapper.findAll('td').wrappers;

    const { occurrenceCount, projectCount } = dependency;

    const isVulnerableCellText = normalizeWhitespace(isVulnerableCell.text());
    const vulns = vulnerabilityInfo[dependency.occurrenceId];

    if (vulns?.length) {
      expect(isVulnerableCellText).toContain(`${vulns.length} vuln`);
    } else {
      expect(isVulnerableCellText).toBe('');
    }
    expect(locationCell.text()).toContain(occurrenceCount.toString());
    expect(projectCell.text()).toContain(projectCount.toString());
  };

  const expectOrganizationDependencyRow = (rowWrapper, dependency) => {
    const [componentCell, packagerCell, locationCell] = rowWrapper.findAll('td').wrappers;

    expect(normalizeWhitespace(componentCell.text())).toBe(
      `${dependency.name} ${dependency.version}`,
    );

    expect(packagerCell.text()).toBe(dependency.packager);
    expect(locationCell.text()).toContain(dependency.location.path);
  };

  describe('given the table is loading', () => {
    let dependencies;

    beforeEach(() => {
      dependencies = [makeDependency()];
      createComponent({
        propsData: {
          dependencies,
          isLoading: true,
        },
      });
    });

    it('renders the loading skeleton', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('does not render any dependencies', () => {
      expect(wrapper.text()).not.toContain(dependencies[0].name);
    });
  });

  describe('given an empty list of dependencies', () => {
    describe.each`
      namespaceType | expectedLabels
      ${'project'}  | ${['Component', 'Packager', 'Location', 'License', 'Vulnerabilities']}
      ${'group'}    | ${['Component', 'Packager', 'Location', 'License', 'Projects']}
    `('with namespaceType set to "$namespaceType"', ({ namespaceType, expectedLabels }) => {
      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: [],
            isLoading: false,
          },
          provide: {
            namespaceType,
          },
        });
      });

      it('renders the table header', () => {
        const headerCells = wrapper.findAll('thead th');

        expectedLabels.forEach((expectedLabel, i) => {
          expect(headerCells.at(i).text()).toContain(expectedLabel);
        });
      });

      it('renders a message that there are no records to show', () => {
        expect(wrapper.text()).toContain('There are no records to show');
      });
    });
  });

  describe.each`
    description                                                             | vulnerabilitiesPayload
    ${'given dependencies with no vulnerabilities'}                         | ${{ vulnerabilities: [] }}
    ${'given dependencies when user is not allowed to see vulnerabilities'} | ${{}}
  `('$description', ({ vulnerabilitiesPayload }) => {
    let dependencies;

    beforeEach(() => {
      dependencies = [
        makeDependency({ ...vulnerabilitiesPayload }),
        makeDependency({ name: 'foo', ...vulnerabilitiesPayload }),
      ];

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
        },
      });
    });

    it('renders a row for each dependency', () => {
      const rows = findTableRows();

      dependencies.forEach((dependency, i) => {
        expectDependencyRow(rows.at(i), dependency);
      });
    });

    it('does not render any row toggle buttons', () => {
      expect(findRowToggleButtons()).toHaveLength(0);
    });

    it('does not render vulnerability details', () => {
      expect(findDependencyVulnerabilities().exists()).toBe(false);
    });
  });

  describe('given some dependencies with vulnerabilities', () => {
    let dependencies;

    beforeEach(() => {
      dependencies = [
        makeDependency({
          name: 'qux',
          vulnerabilities: ['bar', 'baz'],
          vulnerabilityCount: 2,
          occurrenceId: 1,
        }),
        makeDependency({ vulnerabilities: [], vulnerabilityCount: 0, occurrenceId: 2 }),
        // Guarantee that the component doesn't mutate these, but still
        // maintains its row-toggling behaviour (i.e., via _showDetails)
      ].map(Object.freeze);

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
          vulnerabilityInfo,
        },
      });
    });

    it('renders a row for each dependency', () => {
      const rows = findTableRows();

      dependencies.forEach((dependency, i) => {
        expectDependencyRowWithSbom(rows.at(i), dependency);
      });
    });

    it('render the toggle button for each row', () => {
      const toggleButtons = findRowToggleButtons();

      dependencies.forEach((dependency, i) => {
        const button = toggleButtons.at(i);

        expect(button.exists()).toBe(true);
        expect(button.classes('invisible')).toBe(dependency.vulnerabilityCount === 0);
      });
    });

    it('does not render vulnerability details', () => {
      expect(findDependencyVulnerabilities().exists()).toBe(false);
    });

    describe('the dependency vulnerabilities', () => {
      let rowIndexWithVulnerabilities;

      beforeEach(() => {
        rowIndexWithVulnerabilities = dependencies.findIndex(
          (dep) => dep.vulnerabilities.length > 0,
        );
      });

      it('can be displayed by clicking on the toggle button', () => {
        const dependency = dependencies[rowIndexWithVulnerabilities];
        const vulnerabilities = vulnerabilityInfo[dependency.occurrenceId];
        const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
        toggleButton.vm.$emit('click');

        return nextTick().then(() => {
          expect(findDependencyVulnerabilities().props()).toEqual({
            vulnerabilities,
          });
        });
      });

      it('can be displayed by clicking on the vulnerabilities badge', () => {
        const dependency = dependencies[rowIndexWithVulnerabilities];
        const vulnerabilities = vulnerabilityInfo[dependency.occurrenceId];
        const badge = findTableRows().at(rowIndexWithVulnerabilities).findComponent(GlBadge);
        badge.vm.$emit('click');

        return nextTick().then(() => {
          expect(findDependencyVulnerabilities().props()).toEqual({
            vulnerabilities,
          });
        });
      });

      it('handles row-click event', () => {
        const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
        toggleButton.vm.$emit('click');

        return nextTick().then(() => {
          expect(wrapper.emitted('row-click')).toHaveLength(1);
        });
      });

      it('can display loading icon', async () => {
        const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
        toggleButton.vm.$emit('click');

        await waitForPromises();
        const events = wrapper.emitted('row-click');

        wrapper.setProps({ vulnerabilityItemsLoading: events[0] });
        await waitForPromises();
        expect(loadingIcon().exists()).toBe(true);
      });
    });
  });

  describe('with dependencies that do not have an occurrence count', () => {
    let dependencies;

    beforeEach(() => {
      dependencies = [
        makeDependency({
          name: 'actioncable',
          version: '7.0.6',
          packager: 'bundler',
          location: {
            blobPath:
              '/a-group/a-project/-/blob/f67dc4c5466304d6cbe1ecdd18196283447f1a34/Gemfile.lock',
            path: 'Gemfile.lock',
          },
        }),
      ];

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
        },
        provide: { namespaceType: NAMESPACE_ORGANIZATION },
      });
    });

    it('renders a row for each dependency', () => {
      const rows = findTableRows();
      expectOrganizationDependencyRow(rows.at(0), dependencies[0]);
    });
  });

  describe('with multiple dependencies sharing the same componentId', () => {
    let dependencies;
    beforeEach(() => {
      dependencies = [
        makeDependency({
          componentId: 1,
          occurrenceCount: 2,
          project: { full_path: 'full_path', name: 'name' },
          projectCount: 2,
        }),
        makeDependency({
          componentId: 1,
          occurrenceCount: 2,
          project: { full_path: 'full_path', name: 'name' },
          projectCount: 2,
        }),
        makeDependency({
          componentId: 2,
          occurrenceCount: 1,
          project: { full_path: 'full_path', name: 'name' },
          projectCount: 1,
        }),
      ];

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
        },
        provide: { namespaceType: 'group' },
      });
    });

    it('renders a row for each dependency', () => {
      const rows = findTableRows();
      expectGroupDependencyRow(rows.at(0), dependencies[0]);
      expectGroupDependencyRow(rows.at(1), dependencies[1]);
      expectGroupDependencyRow(rows.at(2), dependencies[2]);
    });
  });

  describe('when packager is not set', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          dependencies: [
            makeDependency({
              componentId: 1,
              occurrenceCount: 1,
              project: { full_path: 'full_path', name: 'name' },
              projectCount: 1,
              packager: null,
            }),
          ],
          isLoading: false,
        },
      });
    });

    it('displays unknown', () => {
      const rows = findTableRows();
      const packagerCell = rows.at(0).findAll('td').at(1);

      expect(packagerCell.text()).toBe(DEPENDENCIES_TABLE_I18N.unknown);
    });
  });

  describe('dependency paths', () => {
    describe('for project level when there is location data', () => {
      const dependency = makeDependency({
        occurrenceId: 1,
      });

      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: [dependency],
            isLoading: false,
          },
        });
      });

      it('passes the correct prop to the DependencyPathDrawer component when triggered', async () => {
        const { name, version } = dependency;

        findDependencyLocation().vm.$emit('click-dependency-path');

        await nextTick();

        expect(findDependencyPathDrawer().props()).toMatchObject({
          showDrawer: true,
          component: { name, version },
          occurrenceId: 1,
        });
      });
    });

    describe('for group level when there is occurrenceCount data', () => {
      const dependency = makeDependency({
        componentId: 1,
        occurrenceCount: 2,
        occurrenceId: 1,
        project: { full_path: 'full_path', name: 'name' },
      });

      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: [dependency],
            isLoading: false,
          },
        });
      });

      it('does not display the dependency path button', () => {
        expect(findDependencyPathButtons()).toHaveLength(0);
      });

      it('passes the correct props and only locations with dependency paths to the DependencyPathDrawer component when triggered', async () => {
        const { name, version } = dependency;
        const emittedItem = [
          {
            location: { has_dependency_paths: true },
            project: { name: 'emitted-project', full_path: 'group-1/emitted-project' },
            occurrence_id: 1,
          },
          {
            location: { has_dependency_paths: false },
            project: { name: 'emitted-project-2', full_path: 'group-1/emitted-project-2' },
            occurrence_id: 2,
          },
        ];

        findDependencyLocationCount().vm.$emit('click-dependency-path', emittedItem);

        await nextTick();

        expect(findDependencyPathDrawer().props()).toMatchObject({
          showDrawer: true,
          component: { name, version },
          dropdownItems: [
            { value: 1, text: 'emitted-project', fullPath: 'group-1/emitted-project' },
          ],
          occurrenceId: 1,
        });
      });
    });
  });
});
