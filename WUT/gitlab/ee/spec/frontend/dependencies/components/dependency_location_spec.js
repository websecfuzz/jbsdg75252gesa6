import { GlLink, GlIcon, GlIntersperse, GlPopover, GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import DependencyLocation from 'ee/dependencies/components/dependency_location.vue';
import DirectDescendantViewer from 'ee/dependencies/components/direct_descendant_viewer.vue';
import { DEPENDENCIES_TABLE_I18N } from 'ee/dependencies/constants';
import { trimText } from 'helpers/text_helper';
import * as Paths from './mock_data';

describe('Dependency Location component', () => {
  let wrapper;

  const createComponent = ({ propsData, ...options } = {}) => {
    wrapper = shallowMount(DependencyLocation, {
      propsData: { ...propsData },
      stubs: { GlLink, DirectDescendantViewer, GlIntersperse },
      provide: {
        glFeatures: {
          dependencyPaths: true,
        },
      },
      ...options,
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPath = () => wrapper.find('[data-testid="dependency-path"]');
  const findPathLink = () => wrapper.findComponent(GlLink);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findButton = () => wrapper.findComponent(GlButton);

  it.each`
    name                      | location                    | path
    ${'without path'}         | ${Paths.withoutPath}        | ${DEPENDENCIES_TABLE_I18N.unknown}
    ${'without path to file'} | ${Paths.withoutFilePath}    | ${DEPENDENCIES_TABLE_I18N.unknown}
    ${'container image path'} | ${Paths.containerImagePath} | ${Paths.containerImagePath.image}
    ${'no path'}              | ${Paths.noPath}             | ${Paths.noPath.path}
    ${'top level path'}       | ${Paths.topLevelPath}       | ${'package.json (top level)'}
  `('shows dependency path for $name', ({ location, path }) => {
    createComponent({
      propsData: {
        location,
      },
    });

    expect(trimText(wrapper.text())).toContain(path);
  });

  describe('with dependency path', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          location: { hasDependencyPaths: true },
        },
      });
    });

    it('shows the dependency path button with the correct props', () => {
      expect(findButton().text()).toBe('View dependency paths');
      expect(findButton().props()).toMatchObject({
        size: 'small',
      });
    });

    it('emits event on click', () => {
      expect(wrapper.emitted('click-dependency-path')).toBeUndefined();
      findButton().vm.$emit('click');
      expect(wrapper.emitted('click-dependency-path')).toHaveLength(1);
    });
  });

  describe('dependency with container image dependency path', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          location: Paths.containerImagePath,
        },
      });
    });

    it('should render the dependency name not as a link without container-image: prefix', () => {
      expect(findPathLink().exists()).toBe(false);
      expect(findPath().text()).toBe(Paths.containerImagePath.image);
      expect(findPath().text()).not.toContain('container-image:');
    });

    it('should render the container-image icon', () => {
      const icon = findIcon();
      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('container-image');
    });
  });

  describe('when the feature flag "dependencyPaths" is disabled', () => {
    const mockShortPath = {
      ancestors: [
        {
          name: 'swell',
          version: '1.2',
        },
        {
          name: 'emmajsq',
          version: '10.11',
        },
      ],
      topLevel: false,
      blobPath: 'test.link',
      path: 'package.json',
    };

    const mockLongPath = {
      ancestors: [
        {
          name: 'swell',
          version: '1.2',
        },
        {
          name: 'emmajsq',
          version: '10.11',
        },
        {
          name: 'zeb',
          version: '12.1',
        },
        {
          name: 'post',
          version: '2.5',
        },
        {
          name: 'core',
          version: '1.0',
        },
      ],
      topLevel: false,
      blobPath: 'test.link',
      path: 'package.json',
    };

    describe('dependency path', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            location: { hasDependencyPaths: true },
          },
          provide: {
            glFeatures: {
              dependencyPaths: false,
            },
          },
        });
      });

      it('does not display button', () => {
        expect(findButton().exists()).toBe(false);
      });
    });

    describe('direct descendant', () => {
      it.each`
        name            | location         | path
        ${'short path'} | ${mockShortPath} | ${'package.json / swell 1.2 / emmajsq 10.11'}
        ${'long path'}  | ${mockLongPath}  | ${'package.json / swell 1.2 / emmajsq 10.11 / 3 more'}
      `('shows dependency path for $name', ({ location, path }) => {
        createComponent({
          propsData: {
            location,
          },
          provide: {
            glFeatures: {
              dependencyPaths: false,
            },
          },
        });

        expect(trimText(wrapper.text())).toContain(path);
      });

      describe('with no ancestors', () => {
        beforeEach(() => {
          createComponent({
            propsData: {
              location: Paths.noPath,
            },
            provide: {
              glFeatures: {
                dependencyPaths: false,
              },
            },
          });
        });

        it('should show the dependency name and link', () => {
          const locationLink = findPathLink();
          expect(locationLink.attributes().href).toBe('test.link');
          expect(locationLink.text()).toBe('package.json');
        });

        it('should not render dependency path', () => {
          const pathViewer = wrapper.findComponent(DirectDescendantViewer);
          expect(pathViewer.exists()).toBe(false);
        });

        it('should not render the popover', () => {
          expect(findPopover().exists()).toBe(false);
        });

        it('should render the icon', () => {
          expect(findIcon().exists()).toBe(true);
        });
      });

      describe('popover', () => {
        beforeEach(() => {
          createComponent({
            propsData: {
              location: mockLongPath,
            },
            provide: {
              glFeatures: {
                dependencyPaths: false,
              },
            },
          });
        });

        it('should render the popover', () => {
          expect(findPopover().exists()).toBe(true);
        });

        it('should have the complete path', () => {
          expect(trimText(findPopover().text())).toBe(
            'swell 1.2 / emmajsq 10.11 / zeb 12.1 / post 2.5 / core 1.0',
          );
        });
      });
    });
  });
});
