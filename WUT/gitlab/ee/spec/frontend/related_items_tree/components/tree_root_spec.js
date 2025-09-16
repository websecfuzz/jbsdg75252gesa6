import { GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import Draggable from 'vuedraggable';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { ESC_KEY_CODE } from '~/lib/utils/keycodes';
import { DRAG_DELAY } from '~/sortable/constants';
import TreeRoot from 'ee/related_items_tree/components/tree_root.vue';
import { treeItemChevronBtnKey } from 'ee/related_items_tree/constants';
import createDefaultStore from 'ee/related_items_tree/store';
import * as epicUtils from 'ee/related_items_tree/utils/epic_utils';
import { gqClient } from 'ee/related_items_tree/utils/epic_utils';
import {
  mockQueryResponse,
  mockInitialConfig,
  mockParentItem,
  mockEpic1,
  mockIssue2,
} from '../mock_data';

const { epic } = mockQueryResponse.data.group;

Vue.use(Vuex);

describe('RelatedItemsTree', () => {
  let wrapper;
  let store;

  const createComponent = ({
    parentItem = mockParentItem,
    epicPageInfo = epic.children.pageInfo,
    issuesPageInfo = epic.issues.pageInfo,
  } = {}) => {
    store = createDefaultStore();
    const children = epicUtils.processQueryResponse(mockQueryResponse.data.group);

    store.dispatch('setInitialParentItem', mockParentItem);
    store.dispatch('setInitialConfig', mockInitialConfig);
    store.dispatch('setItemChildrenFlags', {
      isSubItem: false,
      children,
    });

    store.dispatch('setEpicPageInfo', {
      parentItem,
      pageInfo: epicPageInfo,
    });

    store.dispatch('setIssuePageInfo', {
      parentItem,
      pageInfo: issuesPageInfo,
    });

    wrapper = shallowMountExtended(TreeRoot, {
      store,
      stubs: {
        'tree-item': true,
      },
      propsData: {
        parentItem,
        children,
      },
    });
  };

  const findTreeRoot = () => wrapper.findByTestId('tree-root');
  const findMoreChildren = () => findTreeRoot().find('li');

  describe('TreeRoot', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('mixins', () => {
      describe('TreeDragAndDropMixin', () => {
        const containedDragClassOriginally = document.body.classList.contains('is-dragging');
        const containedNoDropClassOriginally = document.body.classList.contains('no-drop');

        beforeEach(() => {
          document.body.classList.remove('is-dragging');
          document.body.classList.remove('no-drop');
        });

        afterAll(() => {
          // Prevent side-effects of this test.
          document.body.classList.toggle('is-dragging', containedDragClassOriginally);
          document.body.classList.toggle('no-drop', containedNoDropClassOriginally);
        });

        describe('Draggable root', () => {
          it('should configure a Draggable component when userSignedIn is true', () => {
            expect(findTreeRoot().element.tagName).toBe('DRAGGABLE-STUB');
            expect(findTreeRoot().attributes()).toEqual(
              expect.objectContaining({
                animation: '200',
                delay: '100',
                forcefallback: 'true',
                fallbackclass: 'is-dragging',
                ghostclass: 'is-ghost',
                group: 'crud-body',
                tag: 'ul',
                'data-parent-reference': mockParentItem.reference,
                'data-parent-id': mockParentItem.id,
                filter: `[data-button-type=${treeItemChevronBtnKey}]`,
              }),
            );
          });

          it('should not be a Draggable component when userSignedIn is false', async () => {
            await store.dispatch('setInitialConfig', {
              ...mockInitialConfig,
              userSignedIn: false,
            });

            expect(findTreeRoot().element.tagName).toBe('UL');
          });
        });

        describe('methods', () => {
          describe('getItemId', () => {
            it('returns value of `id` prop when item is an Epic', () => {
              expect(wrapper.vm.getItemId(wrapper.vm.children[0])).toBe(mockEpic1.id);
            });

            it('returns value of `epicIssueId` prop when item is an Issue', () => {
              expect(wrapper.vm.getItemId(wrapper.vm.children[2])).toBe(mockIssue2.epicIssueId);
            });
          });

          describe('getTreeReorderMutation', () => {
            it('returns an object containing ID of targetItem', () => {
              const targetItemEpic = wrapper.vm.children[0];
              const targetItemIssue = wrapper.vm.children[2];
              const newIndex = 0;

              expect(
                wrapper.vm.getTreeReorderMutation({
                  targetItem: targetItemEpic,
                  newIndex,
                }),
              ).toEqual(
                expect.objectContaining({
                  id: mockEpic1.id,
                }),
              );

              expect(
                wrapper.vm.getTreeReorderMutation({
                  targetItem: targetItemIssue,
                  newIndex,
                }),
              ).toEqual(
                expect.objectContaining({
                  id: mockIssue2.epicIssueId,
                }),
              );
            });

            it('returns an object containing `adjacentReferenceId` of children item at provided `newIndex`', () => {
              const targetItem = wrapper.vm.children[0];

              expect(
                wrapper.vm.getTreeReorderMutation({
                  targetItem,
                  newIndex: 0,
                }),
              ).toEqual(
                expect.objectContaining({
                  adjacentReferenceId: mockEpic1.id,
                }),
              );

              expect(
                wrapper.vm.getTreeReorderMutation({
                  targetItem,
                  newIndex: 2,
                }),
              ).toEqual(
                expect.objectContaining({
                  adjacentReferenceId: mockIssue2.epicIssueId,
                }),
              );
            });

            it('returns object containing `relativePosition` containing `after` when `newIndex` param is 0', () => {
              const targetItem = wrapper.vm.children[0];

              expect(
                wrapper.vm.getTreeReorderMutation({
                  targetItem,
                  newIndex: 0,
                }),
              ).toEqual(
                expect.objectContaining({
                  relativePosition: 'after',
                }),
              );
            });

            it('returns object containing `relativePosition` containing `before` when `newIndex` param is last item index', () => {
              const targetItem = wrapper.vm.children[0];

              expect(
                wrapper.vm.getTreeReorderMutation({
                  targetItem,
                  newIndex: wrapper.vm.children.length - 1,
                }),
              ).toEqual(
                expect.objectContaining({
                  relativePosition: 'before',
                }),
              );
            });

            it('returns object containing `relativePosition` containing `after` when `newIndex` param neither `0` nor last item index', () => {
              const targetItem = wrapper.vm.children[0];

              expect(
                wrapper.vm.getTreeReorderMutation({
                  targetItem,
                  newIndex: 2,
                }),
              ).toEqual(
                expect.objectContaining({
                  relativePosition: 'after',
                }),
              );
            });
          });

          describe('handleDragOnStart', () => {
            it('adds a class `is-dragging` to document body', () => {
              expect(document.body.classList.contains('is-dragging')).toBe(false);

              wrapper.findComponent(Draggable).vm.$emit('start', {
                to: wrapper.element,
              });

              expect(document.body.classList.contains('is-dragging')).toBe(true);
            });

            it('adds and removes a click event handler to ignore clicks while dragging', () => {
              const mockElement = {
                addEventListener: jest.fn(),
                removeEventListener: jest.fn(),
              };

              wrapper.findComponent(Draggable).vm.$emit('start', {
                to: mockElement,
              });
              jest.runAllTimers();

              expect(mockElement.addEventListener).toHaveBeenCalled();
              expect(mockElement.removeEventListener).toHaveBeenCalled();
            });

            it('attaches `keyup` event listener on document', async () => {
              jest.spyOn(document, 'addEventListener');
              wrapper.findComponent(Draggable).vm.$emit('start', {
                to: wrapper.element,
              });
              await nextTick();

              expect(document.addEventListener).toHaveBeenCalledWith('keyup', expect.any(Function));
            });

            it('sets delay and delayOnTouchOnly attributes on list', () => {
              const listEl = wrapper.findComponent(Draggable);

              expect(listEl.vm.$attrs.delay).toBe(DRAG_DELAY);
              expect(listEl.vm.$attrs.delayOnTouchOnly).toBe(true);
            });
          });

          describe('handleDragOnEnd', () => {
            it('removes class `is-dragging` from document body', async () => {
              document.body.classList.add('is-dragging');

              wrapper.findComponent(Draggable).vm.$emit('end', {});
              await nextTick();

              expect(document.body.classList.contains('is-dragging')).toBe(false);
            });

            it('detaches `keyup` event listener on document', async () => {
              jest.spyOn(document, 'removeEventListener');

              wrapper.findComponent(Draggable).vm.$emit('end', { oldIndex: 0, newIndex: 0 });
              await nextTick();

              expect(document.removeEventListener).toHaveBeenCalledWith(
                'keyup',
                expect.any(Function),
              );
            });

            describe('origin parent is destination parent', () => {
              it('does not call `reorderItem` action when newIndex is same as oldIndex', async () => {
                jest.spyOn(store, 'dispatch').mockImplementation(() => {});

                wrapper.findComponent(Draggable).vm.$emit('end', {
                  oldIndex: 0,
                  newIndex: 0,
                  from: wrapper.element,
                  to: wrapper.element,
                });
                await nextTick();

                expect(store.dispatch).not.toHaveBeenCalled();
              });

              it('calls `reorderItem` action when newIndex is different from oldIndex', async () => {
                jest.spyOn(store, 'dispatch').mockImplementation(() => {});

                wrapper.findComponent(Draggable).vm.$emit('end', {
                  oldIndex: 1,
                  newIndex: 0,
                  from: wrapper.element,
                  to: wrapper.element,
                });
                await nextTick();

                expect(store.dispatch).toHaveBeenCalledWith(
                  'reorderItem',
                  expect.objectContaining({
                    treeReorderMutation: expect.any(Object),
                    parentItem: mockParentItem,
                    targetItem: epicUtils.processQueryResponse(mockQueryResponse.data.group)[1],
                    oldIndex: 1,
                    newIndex: 0,
                  }),
                );
              });
            });

            describe('origin parent is different than destination parent', () => {
              it('calls `moveItem`', async () => {
                const mockElement = document.createElement('div');
                mockElement.dataset.id = 'test-id';

                jest.spyOn(store, 'dispatch').mockImplementation(() => {});

                wrapper.findComponent(Draggable).vm.$emit('end', {
                  oldIndex: 1,
                  newIndex: 0,
                  from: wrapper.element,
                  to: mockElement,
                });
                await nextTick();

                expect(store.dispatch).toHaveBeenCalledWith(
                  'moveItem',
                  expect.objectContaining({
                    oldParentItem: wrapper.vm.parentItem,
                    newParentItem: expect.objectContaining({ id: 'test-id' }),
                    targetItem: wrapper.vm.children[1],
                    oldIndex: 1,
                    newIndex: 0,
                  }),
                );
              });
            });
          });

          describe('handleKeyUp', () => {
            it('dispatches `mouseup` event when Escape key is pressed', () => {
              jest.spyOn(store, 'dispatch').mockImplementation(() => {});
              jest.spyOn(document, 'dispatchEvent');

              document.dispatchEvent(
                new Event('keyup', {
                  keyCode: ESC_KEY_CODE,
                }),
              );

              expect(document.dispatchEvent).toHaveBeenCalledWith(new Event('mouseup'));
              expect(store.dispatch).not.toHaveBeenCalled();
            });
          });
        });
      });
    });

    describe('methods', () => {
      describe('onMove', () => {
        let mockEvt;
        let mockOriginalEvt;

        beforeEach(() => {
          mockEvt = {
            relatedContext: {
              element: mockParentItem,
            },
          };
          mockOriginalEvt = {
            clientX: 10,
            clientY: 10,
            target: {
              getBoundingClientRect() {
                return {
                  top: 5,
                  left: 5,
                };
              },
            },
          };
        });

        it('calls toggleItem action after a delay if move event finds epic with children and mouse cursor is over it', () => {
          jest.spyOn(store, 'dispatch');
          wrapper.vm.onMove(mockEvt, mockOriginalEvt);

          jest.runAllTimers();

          expect(store.dispatch).toHaveBeenCalledWith('toggleItem', {
            isDragging: true,
            parentItem: mockParentItem,
          });
        });

        it('does not call toggleItem action if move event does not find epic with children', () => {
          jest.spyOn(store, 'dispatch').mockImplementation(() => {});
          mockEvt = {
            relatedContext: {
              element: mockIssue2,
            },
          };
          mockOriginalEvt = {
            clientX: 10,
            clientY: 10,
          };

          wrapper.vm.$emit('start', mockOriginalEvt);

          expect(store.dispatch).not.toHaveBeenCalled();
        });

        it('does not call toggleItem action if move event no longer have cursor over an epic with children', () => {
          jest.spyOn(store, 'dispatch').mockImplementation(() => {});
          wrapper.vm.$emit('start', mockOriginalEvt);

          jest.runAllTimers();

          expect(store.dispatch).not.toHaveBeenCalled();
        });
      });
    });

    describe('template', () => {
      describe('Children', () => {
        it('displays children when either when either `hasMoreEpics` or `hasMoreIssues` are true', () => {
          expect(findMoreChildren().exists()).toBe(true);
        });

        it('does not display children when both `hasMoreEpics` and `hasMoreIssues` are false', () => {
          createComponent({
            epicPageInfo: {
              hasNextPage: false,
              endCursor: 'abc',
            },
            issuesPageInfo: {
              hasNextPage: false,
              endCursor: 'def',
            },
          });

          expect(findMoreChildren().exists()).toBe(false);
        });
      });

      it('renders tree item component', () => {
        expect(wrapper.html()).toContain('tree-item-stub');
      });

      it('renders `Show more` link', () => {
        expect(wrapper.findComponent(GlButton).text()).toBe('Show more');
      });

      it('fetches more when `Show more` link is clicked and disables the button', async () => {
        jest.spyOn(gqClient, 'query').mockResolvedValue({ data: {} });
        await wrapper.findComponent(GlButton).vm.$emit('click');
        expect(gqClient.query).toHaveBeenCalled();
        expect(wrapper.findComponent(GlButton).exists()).toBe(false);
        const { fullPath, iid } = mockParentItem;
        expect(gqClient.query).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              epicEndCursor: 'abc',
              fullPath,
              iid,
              issueEndCursor: 'def',
            },
          }),
        );
      });
    });
  });
});
