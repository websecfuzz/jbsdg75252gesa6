import { nextTick } from 'vue';
import { RouterLinkStub } from '@vue/test-utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HeaderArea from '~/repository/components/header_area.vue';
import HeaderLockIcon from 'ee_component/repository/components/header_area/header_lock_icon.vue';
import LockDirectoryButton from 'ee_component/repository/components/lock_directory_button.vue';
import CompactCodeDropdown from 'ee_component/repository/components/code_dropdown/compact_code_dropdown.vue';
import BlobControls from '~/repository/components/header_area/blob_controls.vue';
import CodeDropdown from '~/vue_shared/components/code_dropdown/code_dropdown.vue';
import CloneCodeDropdown from '~/vue_shared/components/code_dropdown/clone_code_dropdown.vue';
import { headerAppInjected } from 'ee_else_ce_jest/repository/mock_data';

const defaultMockRoute = {
  params: {
    path: '/directory',
  },
  meta: {
    refType: '',
  },
  query: {
    ref_type: '',
  },
};

describe('HeaderArea', () => {
  let wrapper;

  const findHeaderLockIcon = () => wrapper.findComponent(HeaderLockIcon);
  const findLockDirectoryButton = () => wrapper.findComponent(LockDirectoryButton);
  const findCodeDropdown = () => wrapper.findComponent(CodeDropdown);
  const findCloneCodeDropdown = () => wrapper.findComponent(CloneCodeDropdown);
  const findCompactCodeDropdown = () => wrapper.findComponent(CompactCodeDropdown);
  const findBlobControls = () => wrapper.findComponent(BlobControls);

  const createComponent = ({
    props = {},
    route = { name: 'treePathDecoded', params: { path: '/directory' } },
    provided = {},
    stubs = {},
  } = {}) => {
    return shallowMountExtended(HeaderArea, {
      provide: {
        ...headerAppInjected,
        ...provided,
      },
      propsData: {
        projectPath: 'test/project',
        historyLink: '/history',
        refType: 'branch',
        projectId: '123',
        currentRef: 'main',
        ...props,
      },
      stubs: {
        RouterLink: RouterLinkStub,
        HeaderLockIcon,
        ...stubs,
      },
      mocks: {
        $route: {
          ...defaultMockRoute,
          ...route,
        },
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('when rendered for tree view', () => {
    describe('HeaderLockIcon', () => {
      it('does not render when on root directory', () => {
        wrapper = createComponent({ route: { name: 'treePathDecoded', params: { path: '/' } } });
        expect(findHeaderLockIcon().exists()).toBe(false);
      });

      it('renders HeaderLockIcon component with correct props', () => {
        expect(findHeaderLockIcon().exists()).toBe(true);
        expect(findHeaderLockIcon().props('isTreeView')).toBe(true);
        expect(findHeaderLockIcon().props('isLocked')).toBe(false);
      });

      it('receives lock information from a LockDirectoryButton', async () => {
        expect(findHeaderLockIcon().props('isLocked')).toBe(false);

        findLockDirectoryButton().vm.$emit('lockedDirectory', {
          isLocked: true,
          lockAuthor: 'Admin',
        });
        await nextTick();

        expect(findHeaderLockIcon().props('isLocked')).toBe(true);
        expect(findHeaderLockIcon().props('lockAuthor')).toBe('Admin');
      });
    });

    describe('Lock button', () => {
      it('renders Lock directory button for directories inside the project', () => {
        expect(findLockDirectoryButton().exists()).toBe(true);
      });

      it('does not render Lock directory button for root directory', () => {
        wrapper = createComponent({ route: { name: 'treePathDecoded', params: { path: '/' } } });
        expect(findLockDirectoryButton().exists()).toBe(false);
      });
    });

    describe('CodeDropdown', () => {
      describe('when `directory_code_dropdown_updates` flag is false', () => {
        it('renders CodeDropdown component with correct props for desktop layout', () => {
          expect(findCodeDropdown().exists()).toBe(true);
          expect(findCodeDropdown().props('kerberosUrl')).toBe(headerAppInjected.kerberosUrl);
        });
      });

      describe('when `directory_code_dropdown_updates` flag is true', () => {
        it('renders CompactCodeDropdown component with correct props for desktop layout', () => {
          wrapper = createComponent({
            provided: {
              glFeatures: {
                directoryCodeDropdownUpdates: true,
              },
              newWorkspacePath: '/workspaces/new',
              organizationId: '1',
            },
            stubs: {
              CompactCodeDropdown,
            },
          });

          expect(findCompactCodeDropdown().exists()).toBe(true);
          expect(findCompactCodeDropdown().props('kerberosUrl')).toBe(
            headerAppInjected.kerberosUrl,
          );
        });
      });
    });

    describe('SourceCodeDownloadDropdown', () => {
      it('renders CloneCodeDropdown component with correct props for mobile layout', () => {
        expect(findCloneCodeDropdown().exists()).toBe(true);
        expect(findCloneCodeDropdown().props('kerberosUrl')).toBe(headerAppInjected.kerberosUrl);
      });
    });
  });

  describe('when rendered for blob view', () => {
    beforeEach(() => {
      wrapper = createComponent({
        route: { name: 'blobPathDecoded' },
      });
    });

    describe('HeaderLockIcon', () => {
      it('renders HeaderLockIcon component with correct props', () => {
        expect(findHeaderLockIcon().exists()).toBe(true);
        expect(findHeaderLockIcon().props('isTreeView')).toBe(false);
        expect(findHeaderLockIcon().props('isLocked')).toBe(false);
      });

      it('receives lock information from BlobControls', async () => {
        expect(findHeaderLockIcon().props('isLocked')).toBe(false);

        findBlobControls().vm.$emit('lockedFile', { isLocked: true, lockAuthor: 'Admin' });
        await nextTick();

        expect(findHeaderLockIcon().props('isLocked')).toBe(true);
        expect(findHeaderLockIcon().props('lockAuthor')).toBe('Admin');
      });
    });
  });
});
