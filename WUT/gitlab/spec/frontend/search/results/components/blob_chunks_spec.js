import { GlIcon, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlobChunks from '~/search/results/components/blob_chunks.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { isUnsupportedLanguage } from '~/search/results/utils';
import {
  EVENT_CLICK_BLOB_RESULT_BLAME_LINE,
  EVENT_CLICK_BLOB_RESULT_LINE,
} from '~/search/results/tracking';
import { mockDataForBlobChunk } from '../../mock_data';

jest.mock('~/search/results/utils', () => ({
  isUnsupportedLanguage: jest.fn(),
  initLineHighlight: jest.fn(),
}));

describe('BlobChunks', () => {
  const { bindInternalEventDocument } = useMockInternalEventsTracking();
  let wrapper;

  const createComponent = (props) => {
    wrapper = shallowMountExtended(BlobChunks, {
      propsData: {
        ...props,
      },
      stubs: {
        GlLink,
      },
    });
  };

  const findGlIcon = () => wrapper.findAllComponents(GlIcon);
  const findGlLink = () => wrapper.findAllComponents(GlLink);
  const findLine = () => wrapper.findAllByTestId('search-blob-line');
  const findLineNumbers = () => wrapper.findAllByTestId('search-blob-line-numbers');
  const findHighlightedLineCode = () => wrapper.findAllByTestId('search-blob-line-code');
  const findBlameLink = () =>
    findGlLink().wrappers.filter(
      (w) => w.attributes('data-testid') === 'search-blob-line-blame-link',
    );
  const findLineLink = () =>
    findGlLink().wrappers.filter((w) => w.attributes('data-testid') === 'search-blob-line-link');

  describe('when initial render', () => {
    beforeEach(() => {
      const mockHighlightedText = 'test test test';
      jest.spyOn(BlobChunks.methods, 'codeHighlighting').mockResolvedValue(mockHighlightedText);
      isUnsupportedLanguage.mockReturnValue(true);
      createComponent(mockDataForBlobChunk);
    });

    it('renders default state', () => {
      expect(findLine()).toHaveLength(4);
      expect(findLineNumbers()).toHaveLength(4);
      expect(findHighlightedLineCode()).toHaveLength(4);
      expect(findGlLink()).toHaveLength(8);
      expect(findGlIcon()).toHaveLength(4);
    });

    it('renders links correctly', () => {
      expect(findGlLink().at(0).attributes('href')).toBe('https://gitlab.com/blame/test.js#L1');
      expect(findGlLink().at(0).attributes('title')).toBe('View blame');
      expect(findGlLink().at(0).findComponent(GlIcon).exists()).toBe(true);
      expect(findGlLink().at(0).findComponent(GlIcon).props('name')).toBe('git');

      expect(findGlLink().at(1).attributes('href')).toBe('https://gitlab.com/file/test.js#L1');
      expect(findGlLink().at(1).attributes('title')).toBe('View line in repository');
      expect(findGlLink().at(1).text()).toBe('1');
    });

    it.each`
      trackedLink      | event
      ${findBlameLink} | ${EVENT_CLICK_BLOB_RESULT_BLAME_LINE}
      ${findLineLink}  | ${EVENT_CLICK_BLOB_RESULT_LINE}
    `('emits $event on click', ({ trackedLink, event }) => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackedLink().at(0).vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(event, { property: '1', value: 1 }, undefined);
    });
  });

  describe('when frontend highlighting', () => {
    beforeEach(async () => {
      const mockHighlightedText = 'console.log("test")';
      jest.spyOn(BlobChunks.methods, 'codeHighlighting').mockResolvedValue(mockHighlightedText);

      isUnsupportedLanguage.mockReturnValue(false);

      createComponent(mockDataForBlobChunk);
      await waitForPromises();
    });

    it('renders proper colors', () => {
      expect(findHighlightedLineCode().exists()).toBe(true);
      expect(findHighlightedLineCode().at(2).text()).toBe('console.log("test")');
    });
  });

  describe('processLine method', () => {
    const mockHighlightedText = 'highlighted code';

    beforeEach(() => {
      jest.spyOn(BlobChunks.methods, 'codeHighlighting').mockResolvedValue(mockHighlightedText);
    });

    describe('with unsupported language', () => {
      beforeEach(async () => {
        isUnsupportedLanguage.mockReturnValue(true);

        createComponent({
          ...mockDataForBlobChunk,
          language: 'unsupported-lang',
        });

        await waitForPromises();
      });

      it('sets line text directly when language is unsupported', () => {
        const lineElements = wrapper.findAllByTestId('search-blob-line-code');

        expect(lineElements.exists()).toBe(true);
        expect(wrapper.vm.lines[0].richText).toBe(mockHighlightedText);
      });
    });

    describe('with supported language', () => {
      beforeEach(async () => {
        isUnsupportedLanguage.mockReturnValue(false);

        createComponent({
          ...mockDataForBlobChunk,
          language: 'javascript',
        });

        await waitForPromises();
      });

      it('sets richText when language is supported', () => {
        const lineElements = wrapper.findAllByTestId('search-blob-line-code');

        expect(lineElements.exists()).toBe(true);
        expect(wrapper.vm.lines[0].richText).toBe(mockHighlightedText);
      });
    });
  });
});
