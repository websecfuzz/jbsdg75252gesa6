import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import AiGenie from 'ee/ai/components/ai_genie.vue';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { i18n, GENIE_CHAT_EXPLAIN_MESSAGE } from 'ee/ai/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import LineHighlighter from '~/blob/line_highlighter';
import { getMarkdown } from '~/rest_api';

const lineHighlighter = new LineHighlighter();
jest.mock('~/blob/line_highlighter', () =>
  jest.fn().mockReturnValue({
    highlightRange: jest.fn(),
    clearHighlight: jest.fn(),
  }),
);
jest.mock('ee/ai/utils', () => ({
  generateExplainCodePrompt: jest.fn(),
  generateChatPrompt: jest.fn(),
  sendDuoChatCommand: jest.fn(),
}));
jest.mock('~/rest_api');
jest.mock('~/alert');

Vue.use(VueApollo);

const SELECTION_START_POSITION = 50;
const SELECTION_END_POSITION = 150;
const CONTAINER_TOP = 20;
const LINE_ID = 'LC1';

describe('AiGenie', () => {
  let wrapper;
  const containerSelector = '.container';
  const filePath = 'some_file.js';
  const language = 'vue';
  const resourceId = 'gid://gitlab/Project/1';

  const getContainer = () => document.querySelector(containerSelector);
  const createComponent = ({ propsData = { containerSelector, filePath }, data = {} } = {}) => {
    wrapper = shallowMountExtended(AiGenie, {
      propsData,
      data() {
        return data;
      },
      provide: {
        resourceId,
      },
    });
  };
  const findButton = () => wrapper.findComponent(GlButton);

  const getRangeAtMock = (top = () => 0) => {
    return jest.fn((rangePosition) => {
      return {
        getBoundingClientRect: jest.fn(() => {
          return {
            top: top(rangePosition),
            left: 0,
            right: 0,
            bottom: 0,
          };
        }),
      };
    });
  };
  const getSelectionMock = ({ getRangeAt = getRangeAtMock(), toString = () => {} } = {}) => {
    return {
      anchorNode: document.getElementById('first-paragraph'),
      focusNode: document.getElementById('first-paragraph'),
      isCollapsed: false,
      getRangeAt,
      rangeCount: 10,
      toString,
      removeAllRanges: jest.fn(),
    };
  };

  const simulateSelectionEvent = () => {
    const selectionChangeEvent = new Event('selectionchange');
    document.dispatchEvent(selectionChangeEvent);
  };

  const waitForDebounce = async () => {
    await nextTick();
    jest.runOnlyPendingTimers();
  };

  const simulateSelectText = async ({
    contains = true,
    getSelection = getSelectionMock(),
  } = {}) => {
    jest.spyOn(window, 'getSelection').mockImplementation(() => getSelection);
    jest
      .spyOn(document.querySelector(containerSelector), 'contains')
      .mockImplementation(() => contains);
    simulateSelectionEvent();
    await waitForDebounce();
  };

  const requestExplanation = async () => {
    await findButton().vm.$emit('click');
  };

  beforeEach(() => {
    setHTMLFixture(
      `<div class="container" style="height:1000px; width: 800px"><span class="line" id="${LINE_ID}"><p lang=${language} id="first-paragraph">Foo</p></span></div>`,
    );
    getMarkdown.mockImplementation(({ text }) => Promise.resolve({ data: { html: text } }));
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('correctly renders the component by default', () => {
    createComponent();
    expect(findButton().exists()).toBe(true);
  });

  describe('the toggle button', () => {
    beforeEach(() => {
      createComponent();
    });

    it('is hidden by default, yet gets the correct props', () => {
      const btnWrapper = findButton();
      expect(btnWrapper.isVisible()).toBe(false);
      expect(btnWrapper.attributes('title')).toBe(i18n.GENIE_TOOLTIP);
    });

    it('is rendered when a text is selected', async () => {
      await simulateSelectText();
      expect(findButton().isVisible()).toBe(true);
    });

    describe('toggle position', () => {
      beforeEach(() => {
        jest.spyOn(getContainer(), 'getBoundingClientRect').mockImplementation(() => {
          return { top: CONTAINER_TOP };
        });
      });

      it('is positioned correctly at the start of the selection', async () => {
        const getRangeAt = getRangeAtMock((position) => {
          return position === 0 ? SELECTION_START_POSITION : SELECTION_END_POSITION;
        });
        const getSelection = getSelectionMock({ getRangeAt });
        await simulateSelectText({ getSelection });
        expect(wrapper.element.style.top).toBe(`${SELECTION_START_POSITION - CONTAINER_TOP}px`);
      });

      it('is positioned correctly at the end of the selection', async () => {
        const getRangeAt = getRangeAtMock((position) => {
          return position === 0 ? SELECTION_END_POSITION : SELECTION_START_POSITION;
        });
        const getSelection = getSelectionMock({ getRangeAt });
        await simulateSelectText({ getSelection });
        expect(wrapper.element.style.top).toBe(`${SELECTION_START_POSITION - CONTAINER_TOP}px`);
      });
    });
  });

  describe('selectionchange event listener', () => {
    let addEventListenerSpy;
    let removeEventListenerSpy;

    beforeEach(() => {
      addEventListenerSpy = jest.spyOn(document, 'addEventListener');
      removeEventListenerSpy = jest.spyOn(document, 'removeEventListener');
      createComponent();
    });

    afterEach(() => {
      addEventListenerSpy.mockRestore();
      removeEventListenerSpy.mockRestore();
    });

    it('sets up the `selectionchange` event listener', () => {
      expect(addEventListenerSpy).toHaveBeenCalledWith('selectionchange', expect.any(Function));
      expect(removeEventListenerSpy).not.toHaveBeenCalled();
    });

    it('removes the event listener when destroyed', () => {
      wrapper.destroy();
      expect(removeEventListenerSpy).toHaveBeenCalledWith('selectionchange', expect.any(Function));
    });
  });

  describe('interaction', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls the `sendDuoChatCommand` code request', async () => {
      await simulateSelectText();
      await requestExplanation();
      expect(sendDuoChatCommand).toHaveBeenCalledWith({
        question: GENIE_CHAT_EXPLAIN_MESSAGE,
        resourceId,
        variables: {
          currentFileContext: {
            fileName: filePath,
            selectedText: getSelection().toString(),
          },
        },
      });
    });
  });

  describe('Lines highlighting', () => {
    beforeEach(() => {
      createComponent();
    });

    it('initiates LineHighlighter', () => {
      expect(LineHighlighter).toHaveBeenCalled();
    });

    it('calls highlightRange with expected range', async () => {
      await simulateSelectText();
      await requestExplanation();
      expect(lineHighlighter.highlightRange).toHaveBeenCalledWith([1, 1]);
    });

    it('calls clearHighlight to clear previous selection', async () => {
      await simulateSelectText();
      await requestExplanation();
      expect(lineHighlighter.clearHighlight).toHaveBeenCalledTimes(1);
    });

    it('does not call highlight range when no line found', async () => {
      document.getElementById(`${LINE_ID}`).classList.remove('line');
      await simulateSelectText();
      await requestExplanation();
      expect(lineHighlighter.highlightRange).not.toHaveBeenCalled();
    });
  });
});
