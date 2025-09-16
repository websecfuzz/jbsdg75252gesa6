import { GlIcon, GlCollapsibleListbox, GlLink } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import waitForPromises from 'helpers/wait_for_promises';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import DependencyLocationCount from 'ee/dependencies/components/dependency_location_count.vue';
import { SEARCH_MIN_THRESHOLD } from 'ee/dependencies/components/constants';

describe('Dependency Location Count component', () => {
  let wrapper;
  let mockAxios;

  const blobPath = '/blob_path/Gemfile.lock';
  const path = 'Gemfile.lock';
  const projectName = 'test-project';
  const endpoint = 'endpoint';
  const unknownPath = 'Unknown path';
  const topLevel = false;
  const topLevelText = '(top level)';

  const locationsData = {
    locations: [
      {
        location: {
          blob_path: blobPath,
          path,
          top_level: topLevel,
        },
        project: {
          name: projectName,
        },
      },
    ],
  };

  const createComponent = ({
    propsData,
    mountFn = shallowMountExtended,
    dependencyPaths = true,
    ...options
  } = {}) => {
    wrapper = mountFn(DependencyLocationCount, {
      propsData: {
        ...{
          locationCount: 2,
          componentId: 1,
        },
        ...propsData,
      },
      provide: {
        locationsEndpoint: endpoint,
        glFeatures: {
          dependencyPaths,
        },
      },
      ...options,
    });
  };

  const findToggleText = () => wrapper.findByTestId('toggle-text');
  const findLocationList = () => wrapper.findComponent(GlCollapsibleListbox);
  const findLocationInfo = () => wrapper.findComponent(GlLink);
  const findUnknownLocationInfo = () => wrapper.findByTestId('unknown-path');
  const findUnknownLocationIcon = () => findUnknownLocationInfo().findComponent(GlIcon);
  const findDependencyPathButton = () => wrapper.findByTestId('dependency-path-button');

  const clickLocationList = async () => {
    await findLocationList().vm.$emit('shown');
    await waitForPromises();
  };

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  it('renders toggle text', () => {
    createComponent();

    expect(findToggleText().html()).toMatchSnapshot();
  });

  it.each`
    locationCount | headerText
    ${1}          | ${'1 location'}
    ${2}          | ${'2 locations'}
  `(
    'renders correct location text when `locationCount` is $locationCount',
    ({ locationCount, headerText }) => {
      createComponent({
        propsData: {
          locationCount,
        },
      });

      expect(findLocationList().props('headerText')).toBe(headerText);
    },
  );

  it('renders the listbox', () => {
    createComponent();

    expect(findLocationList().props()).toMatchObject({
      headerText: '2 locations',
      searchable: true,
      items: [],
      loading: false,
      searching: true,
    });
  });

  describe('with fetched data', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mountExtended,
      });
      mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, locationsData);
    });

    it('sets searching based on the data being fetched', async () => {
      await findLocationList().vm.$emit('shown');

      expect(findLocationList().props('searching')).toBe(true);

      await waitForPromises();

      expect(mockAxios.history.get).toHaveLength(1);

      expect(findLocationList().props('searching')).toBe(false);
    });

    it('sets searching when search term is updated', async () => {
      await findLocationList().vm.$emit('search', 'a');

      expect(findLocationList().props('searching')).toBe(true);

      await waitForPromises();

      expect(findLocationList().props('searching')).toBe(false);
    });

    it('renders location information', async () => {
      await clickLocationList();

      expect(findLocationInfo().attributes('href')).toBe(blobPath);
      expect(findLocationInfo().text()).toContain(path);
      expect(wrapper.text()).toContain(projectName);
      expect(wrapper.text()).not.toContain(topLevelText);
    });

    describe('when top level is set to true', () => {
      beforeEach(() => {
        createComponent({
          mountFn: mountExtended,
        });
        locationsData.locations[0].location.top_level = true;
        mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, locationsData);
      });

      it('renders location information', async () => {
        await findLocationList().vm.$emit('shown');
        await waitForPromises();

        expect(findLocationInfo().attributes('href')).toBe(blobPath);
        expect(findLocationInfo().text()).toContain(path);
        expect(wrapper.text()).toContain(projectName);
        expect(wrapper.text()).toContain(topLevelText);
      });
    });

    describe('with unknown path', () => {
      const unknownPathLocationsData = {
        locations: [
          {
            location: {
              blob_path: null,
              path: null,
            },
            project: {
              name: projectName,
            },
          },
        ],
      };

      beforeEach(() => {
        mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, unknownPathLocationsData);
      });

      it('renders location information', async () => {
        await clickLocationList();

        expect(findUnknownLocationIcon().props('name')).toBe('error');
        expect(findUnknownLocationInfo().text()).toContain(unknownPath);
        expect(wrapper.text()).toContain(projectName);
      });
    });

    describe.each`
      locationCount               | searchable
      ${SEARCH_MIN_THRESHOLD - 1} | ${false}
      ${SEARCH_MIN_THRESHOLD + 1} | ${true}
    `('with location count equal to $locationCount', ({ locationCount, searchable }) => {
      beforeEach(() => {
        createComponent({
          propsData: { locationCount },
        });
      });

      it(`renders listbox with searchable set to ${searchable}`, async () => {
        await clickLocationList();

        expect(findLocationList().props()).toMatchObject({
          headerText: `${locationCount} locations`,
          searchable,
        });
      });
    });

    describe('with dependency path', () => {
      const dependencyPathsLocationsData = {
        locations: [
          {
            location: {
              has_dependency_paths: true,
            },
            project: { name: projectName },
          },
        ],
      };

      beforeEach(() => {
        mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, dependencyPathsLocationsData);
      });

      it('shows the dependency path button', async () => {
        await clickLocationList();
        expect(findDependencyPathButton().exists()).toBe(true);
      });

      it('emits event and passes the project and selected location data', async () => {
        await clickLocationList();

        findDependencyPathButton().vm.$emit('click');
        await waitForPromises();

        const emittedData = wrapper.emitted('click-dependency-path')[0][0];
        const index = 0;
        const { location, project } = dependencyPathsLocationsData.locations[index];

        expect(emittedData).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              location,
              project,
              value: index,
            }),
          ]),
        );
      });

      it('does not show the dependency path button', async () => {
        const noDependencyPathsLocationsData = {
          locations: [
            {
              location: { has_dependency_paths: false },
              project: { name: projectName },
            },
          ],
        };

        mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, noDependencyPathsLocationsData);
        await clickLocationList();

        expect(findDependencyPathButton().exists()).toBe(false);
      });

      describe('when feature flag "dependencyPaths" is disabled', () => {
        it('does not show the dependency path', async () => {
          createComponent({
            mountFn: mountExtended,
            dependencyPaths: false,
          });
          mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, locationsData);

          await clickLocationList();

          expect(findDependencyPathButton().exists()).toBe(false);
        });
      });
    });
  });
});
