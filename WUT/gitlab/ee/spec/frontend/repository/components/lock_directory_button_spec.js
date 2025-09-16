import { shallowMount } from '@vue/test-utils';
import { GlButton, GlSprintf, GlModal, GlTooltip } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import projectInfoQuery from 'ee_component/repository/queries/project_info.query.graphql';
import currentUserQuery from '~/graphql_shared/queries/current_user.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';
import { logError } from '~/lib/logger';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import LockDirectoryButton from 'ee_component/repository/components/lock_directory_button.vue';
import {
  projectMock,
  getProjectMockWithOverrides,
  exactDirectoryLock,
  upstreamDirectoryLock,
  downstreamDirectoryLock,
  userMock,
  lockPathMutationMock,
} from 'ee_jest/repository/mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/lib/logger');

describe('LockDirectoryButton', () => {
  let wrapper;
  let fakeApollo;

  const mockRequestError = new Error('Request failed');

  const currentUserMockResolver = jest.fn().mockResolvedValue(userMock);
  const signedOutUserResolver = jest.fn().mockResolvedValue({ data: { currentUser: null } });
  const currentUserErrorResolver = jest.fn().mockRejectedValue(mockRequestError);

  const projectInfoQueryMockResolver = jest
    .fn()
    .mockResolvedValue({ data: { project: projectMock } });
  const projectInfoQueryErrorResolver = jest.fn().mockRejectedValue(mockRequestError);

  const lockPathMutationMockResolver = jest.fn().mockResolvedValue(lockPathMutationMock);
  const lockPathMutationErrorResolver = jest.fn().mockRejectedValue(new Error('Request failed'));

  const createComponent = ({
    fileLocks = true,
    props = {},
    projectInfoResolver = projectInfoQueryMockResolver,
    currentUserResolver = currentUserMockResolver,
    lockPathMutationResolver = lockPathMutationMockResolver,
  } = {}) => {
    fakeApollo = createMockApollo([
      [projectInfoQuery, projectInfoResolver],
      [currentUserQuery, currentUserResolver],
      [lockPathMutation, lockPathMutationResolver],
    ]);

    wrapper = shallowMount(LockDirectoryButton, {
      apolloProvider: fakeApollo,
      provide: {
        glFeatures: {
          fileLocks,
        },
      },
      propsData: {
        projectPath: 'group/project',
        path: 'test/component',
        ...props,
      },
      stubs: {
        GlSprintf,
        GlButton,
        GlModal,
        GlTooltip,
      },
    });
  };

  const findLockDirectoryButton = () => wrapper.findComponent(GlButton);
  const findModal = () => wrapper.findComponent(GlModal);
  const findTooltip = () => wrapper.findComponent(GlTooltip);

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('lock button', () => {
    it('does not render when fileLocks feature is not available', async () => {
      createComponent({ fileLocks: false });
      await waitForPromises();

      expect(currentUserMockResolver).toHaveBeenCalled();
      expect(findLockDirectoryButton().exists()).toBe(false);
    });

    it('does not render when user is not logged in', async () => {
      createComponent({
        currentUserResolver: signedOutUserResolver,
      });
      await waitForPromises();

      expect(findLockDirectoryButton().exists()).toBe(false);
    });

    it('renders when feature is available and user logged in', () => {
      expect(findLockDirectoryButton().exists()).toBe(true);
      expect(findLockDirectoryButton().text()).toBe('Lock');
    });

    it('emits lock information to parent component', () => {
      expect(wrapper.emitted('lockedDirectory')).toEqual([
        [{ isLocked: false, lockAuthor: undefined }],
      ]);
    });

    it('renders with loading state until query fetches projects info', async () => {
      createComponent({
        projectInfoResolver: projectInfoQueryMockResolver.mockReturnValue(new Promise(() => {})),
      });
      await waitForPromises();
      expect(projectInfoQueryMockResolver).toHaveBeenCalled();
      expect(findLockDirectoryButton().props('loading')).toBe(true);
    });

    describe('renders disabled with correct tooltip', () => {
      it('disables button and shows tooltip when user does not have permissions to create path lock', async () => {
        createComponent({
          projectInfoResolver: jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                userPermissionsOverride: {
                  createPathLock: false,
                },
              }),
            },
          }),
        });
        await waitForPromises();

        expect(findLockDirectoryButton().text()).toBe('Lock');
        expect(findLockDirectoryButton().props('disabled')).toBe(true);
        expect(findTooltip().text()).toBe('You do not have permission to lock this');
      });
    });

    it('renders enabled without a tooltip when user have permission to lock', async () => {
      createComponent({
        projectInfoResolver: jest.fn().mockResolvedValue({
          data: {
            project: getProjectMockWithOverrides({
              userPermissionsOverride: {
                createPathLock: true,
              },
            }),
          },
        }),
      });
      await waitForPromises();

      expect(findLockDirectoryButton().text()).toBe('Lock');
      expect(findLockDirectoryButton().props('disabled')).toBe(false);
      expect(findTooltip().exists()).toBe(false);
    });

    describe('lock types', () => {
      it.each`
        mock                       | type                  | isExactLock | isUpstreamLock | isDownstreamLock
        ${exactDirectoryLock}      | ${'isExactLock'}      | ${true}     | ${false}       | ${false}
        ${upstreamDirectoryLock}   | ${'isUpstreamLock'}   | ${false}    | ${true}        | ${false}
        ${downstreamDirectoryLock} | ${'isDownstreamLock'} | ${false}    | ${false}       | ${true}
      `(
        'correctly assigns the lock type as $type depending on PathLock data',
        async ({ mock, type, isExactLock, isUpstreamLock, isDownstreamLock }) => {
          createComponent({
            projectInfoResolver: jest.fn().mockResolvedValue({
              data: {
                project: getProjectMockWithOverrides({
                  pathLockNodesOverride: [mock],
                }),
              },
            }),
          });
          await waitForPromises();

          expect(wrapper.vm.$data.pathLock[type]).toBe(true);
          expect(wrapper.vm.$data.pathLock.isExactLock).toBe(isExactLock);
          expect(wrapper.vm.pathLock.isUpstreamLock).toBe(isUpstreamLock);
          expect(wrapper.vm.pathLock.isDownstreamLock).toBe(isDownstreamLock);
        },
      );
    });

    describe('when there is an exact lock', () => {
      it('renders an enabled "Unlock" button when lock author is allowed to unlock', async () => {
        createComponent({
          projectInfoResolver: jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: [
                  {
                    ...exactDirectoryLock,
                    user: {
                      __typename: 'CurrentUser',
                      id: 'gid://gitlab/User/1',
                      username: 'root',
                      name: 'Administrator',
                    },
                  },
                ],
              }),
            },
          }),
        });
        await waitForPromises();

        expect(findLockDirectoryButton().text()).toBe('Unlock');
        expect(findLockDirectoryButton().props('disabled')).toBe(false);
        expect(findTooltip().exists()).toBe(false);
      });

      it('renders disabled button and shows tooltip when user does not have permissions to unlock', async () => {
        createComponent({
          projectInfoResolver: jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: [
                  { ...exactDirectoryLock, userPermissions: { destroyPathLock: false } },
                ],
              }),
            },
          }),
        });
        await waitForPromises();

        expect(findLockDirectoryButton().text()).toBe('Unlock');
        expect(findLockDirectoryButton().props('disabled')).toBe(true);
        expect(findTooltip().text()).toContain('Locked by User2');
      });

      it('emits lock information to parent component', async () => {
        createComponent({
          projectInfoResolver: jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: [exactDirectoryLock],
              }),
            },
          }),
        });
        await waitForPromises();

        expect(wrapper.emitted('lockedDirectory')).toEqual([
          [{ isLocked: true, lockAuthor: 'User2' }],
        ]);
      });
    });

    describe('when there is an upstream lock', () => {
      const testCases = [
        {
          name: 'user is allowed to unlock',
          data: {
            project: getProjectMockWithOverrides({
              pathLockNodesOverride: [upstreamDirectoryLock],
              userPermissionsOverride: {
                createPathLock: true,
              },
            }),
          },
          expectedTooltipText:
            'User2 has a lock on "test". Unlock that directory in order to unlock this',
        },
        {
          name: 'user does not have permissions',
          data: {
            project: getProjectMockWithOverrides({
              pathLockNodesOverride: [upstreamDirectoryLock],
              userPermissionsOverride: {
                createPathLock: false,
              },
            }),
          },
          expectedTooltipText:
            'User2 has a lock on "test". You do not have permission to unlock it',
        },
      ];

      it.each(testCases)(
        'disables button and shows tooltip when $name',
        async ({ data, expectedTooltipText }) => {
          createComponent({
            projectInfoResolver: jest.fn().mockResolvedValue({ data }),
          });
          await waitForPromises();

          expect(findLockDirectoryButton().text()).toBe('Unlock');
          expect(findLockDirectoryButton().props('disabled')).toBe(true);
          expect(findTooltip().text()).toBe(expectedTooltipText);
        },
      );

      it('emits lock information to parent component', async () => {
        createComponent({
          projectInfoResolver: jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: [upstreamDirectoryLock],
              }),
            },
          }),
        });
        await waitForPromises();

        expect(wrapper.emitted('lockedDirectory')).toEqual([
          [{ isLocked: true, lockAuthor: 'User2' }],
        ]);
      });
    });

    describe('when there is a downstream lock', () => {
      const testCases = [
        {
          name: 'user is allowed to unlock',
          projectInfoResolvedValue: {
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: [downstreamDirectoryLock],
              }),
            },
          },
          expectedTooltipText:
            'This directory cannot be locked while User2 has a lock on "test/component/icon". Unlock this in order to proceed',
        },
        {
          name: 'user does not have permissions',
          projectInfoResolvedValue: {
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: [downstreamDirectoryLock],
                userPermissionsOverride: {
                  createPathLock: false,
                },
              }),
            },
          },
          expectedTooltipText:
            'This directory cannot be locked while User2 has a lock on "test/component/icon". You do not have permission to unlock it',
        },
      ];

      it.each(testCases)(
        'disables button and shows tooltip when $name',
        async ({ projectInfoResolvedValue, expectedTooltipText }) => {
          createComponent({
            projectInfoResolver: jest.fn().mockResolvedValue(projectInfoResolvedValue),
          });
          await waitForPromises();

          expect(findLockDirectoryButton().text()).toBe('Lock');
          expect(findLockDirectoryButton().props('disabled')).toBe(true);
          expect(findTooltip().text()).toBe(expectedTooltipText);
        },
      );
    });

    describe('modal', () => {
      it('shows a modal when clicked', async () => {
        findLockDirectoryButton().trigger('click');
        await waitForPromises();
        expect(findModal().exists()).toBe(true);
      });

      it('has a unique modal id', async () => {
        findLockDirectoryButton().trigger('click');
        await waitForPromises();
        expect(findModal().props('modalId')).toBe('lock-directory-modal-test-component');
      });

      it('displays correct content, when user tries to lock the directory', async () => {
        findLockDirectoryButton().trigger('click');
        await waitForPromises();
        expect(findModal().text()).toContain('Are you sure you want to lock this directory?');
      });

      it('displays correct content, when user tries to unlock the directory', async () => {
        createComponent({
          projectInfoResolver: jest.fn().mockResolvedValue({
            data: {
              project: getProjectMockWithOverrides({
                pathLockNodesOverride: [exactDirectoryLock],
              }),
            },
          }),
        });
        await waitForPromises();
        findLockDirectoryButton().trigger('click');
        await waitForPromises();
        expect(findModal().text()).toContain('Are you sure you want to unlock this directory?');
      });
    });

    describe('when the user confirms the action in the modal', () => {
      useMockLocationHelper();

      it('calls the mutation and reloads the page, when mutation is successful', async () => {
        findLockDirectoryButton().trigger('click');
        await waitForPromises();
        findModal().vm.$emit('primary');
        await waitForPromises();
        expect(lockPathMutationMockResolver).toHaveBeenCalledWith({
          filePath: 'test/component',
          projectPath: 'group/project',
          lock: true,
        });
        expect(window.location.reload).toHaveBeenCalled();
      });

      it('calls the mutation and creates an alert with the correct message, when mutation fails', async () => {
        createComponent({
          lockPathMutationResolver: lockPathMutationErrorResolver,
        });
        await waitForPromises();
        findLockDirectoryButton().trigger('click');
        await waitForPromises();
        findModal().vm.$emit('primary');
        await waitForPromises();
        expect(logError).toHaveBeenCalledWith(
          'Unexpected error while Locking/Unlocking path',
          mockRequestError,
        );
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while editing lock information, please try again.',
          captureError: true,
          error: mockRequestError,
        });
        expect(window.location.reload).not.toHaveBeenCalled();
      });
    });

    describe('when user cancels the action in the modal', () => {
      it('does not call the mutation', async () => {
        findLockDirectoryButton().trigger('click');
        await waitForPromises();
        findModal().vm.$emit('cancel');
        await waitForPromises();
        expect(lockPathMutationMockResolver).not.toHaveBeenCalled();
      });
    });

    describe('alert', () => {
      it('creates an alert with the correct message, when projectInfo query fails', async () => {
        createComponent({
          projectInfoResolver: projectInfoQueryErrorResolver,
        });
        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while fetching lock information, please try again.',
        });
      });

      it('creates an alert with the correct message, when currentUser query fails', async () => {
        createComponent({
          currentUserResolver: currentUserErrorResolver,
        });
        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          message: 'An error occurred while fetching lock information, please try again.',
        });
      });
    });
  });
});
