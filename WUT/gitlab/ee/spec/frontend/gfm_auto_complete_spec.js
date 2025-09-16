import $ from 'jquery';
import GfmAutoCompleteEE, {
  Q_ISSUE_SUB_COMMANDS,
  Q_MERGE_REQUEST_SUB_COMMANDS,
  Q_MERGE_REQUEST_DIFF_SUB_COMMANDS,
} from 'ee/gfm_auto_complete';
import { TEST_HOST } from 'helpers/test_constants';
import GfmAutoComplete from '~/gfm_auto_complete';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import { iterationsMock } from 'ee_jest/gfm_auto_complete/mock_data';
import { ISSUABLE_EPIC } from '~/work_items/constants';
import AjaxCache from '~/lib/utils/ajax_cache';

const mockSpriteIcons = '/icons.svg';

describe('GfmAutoCompleteEE', () => {
  const dataSources = {
    labels: `${TEST_HOST}/autocomplete_sources/labels`,
    iterations: `${TEST_HOST}/autocomplete_sources/iterations`,
  };

  let instance;
  let $textarea;

  const triggerDropdown = (text) => {
    $textarea
      .trigger('focus')
      .val($textarea.val() + text)
      .caret('pos', -1);
    $textarea.trigger('keyup');

    jest.runOnlyPendingTimers();
  };

  const getDropdownItems = (id) => {
    const dropdown = document.getElementById(id);

    return Array.from(dropdown?.getElementsByTagName('li') || []);
  };

  const getDropdownSubcommands = (id) =>
    getDropdownItems(id).map((x) => ({
      name: x.querySelector('.name').textContent,
      description: x.querySelector('.description').textContent,
    }));

  beforeEach(() => {
    window.gon = { sprite_icons: mockSpriteIcons };
  });

  afterEach(() => {
    resetHTMLFixture();

    $textarea = null;

    instance?.destroy();
    instance = null;
  });

  it('should have enableMap', () => {
    instance = new GfmAutoCompleteEE(dataSources);
    instance.setup($('<input type="text" />'));

    expect(instance.enableMap).not.toBeNull();
  });

  describe('Issues.templateFunction', () => {
    it('should return html with id and title', () => {
      expect(GfmAutoComplete.Issues.templateFunction({ id: 42, title: 'Sample Epic' })).toBe(
        '<li><small>42</small> Sample Epic</li>',
      );
    });

    it('should replace id with reference if reference is set', () => {
      expect(
        GfmAutoComplete.Issues.templateFunction({
          id: 42,
          title: 'Another Epic',
          reference: 'foo&42',
        }),
      ).toBe('<li><small>foo&amp;42</small> Another Epic</li>');
    });

    it('should include the epic svg image when iconName is provided', () => {
      const expectedHtml = `<li><svg class="gl-fill-icon-subtle s16 gl-mr-2"><use xlink:href="/icons.svg#epic" /></svg><small>5</small> Some Work Item Epic</li>`;
      expect(
        GfmAutoComplete.Issues.templateFunction({
          id: 5,
          title: 'Some Work Item Epic',
          iconName: ISSUABLE_EPIC,
        }),
      ).toBe(expectedHtml);
    });
  });

  describe('Iterations', () => {
    beforeEach(() => {
      setHTMLFixture('<textarea></textarea>');
      $textarea = $('textarea');
      instance = new GfmAutoCompleteEE(dataSources);
      instance.setup($textarea, { iterations: true });
    });

    it("should list iterations when '/iteration *iteration:' is typed", () => {
      instance.cachedData['*iteration:'] = [...iterationsMock];

      const { id, title } = iterationsMock[0];
      const expectedDropdownItems = [`*iteration:${id} ${title}`];

      triggerDropdown('/iteration *iteration:');

      expect(getDropdownItems('at-view-iterations').map((x) => x.textContent.trim())).toEqual(
        expectedDropdownItems,
      );
    });

    describe('templateFunction', () => {
      const { templateFunction } = GfmAutoCompleteEE.Iterations;

      it('should return html with id and title', () => {
        expect(templateFunction({ id: 42, title: 'Foobar Iteration' })).toBe(
          '<li><small>*iteration:42</small> Foobar Iteration</li>',
        );
      });

      it.each`
        xssPayload                                           | escapedPayload
        ${'<script>alert(1)</script>'}                       | ${'&lt;script&gt;alert(1)&lt;/script&gt;'}
        ${'%3Cscript%3E alert(1) %3C%2Fscript%3E'}           | ${'&lt;script&gt; alert(1) &lt;/script&gt;'}
        ${'%253Cscript%253E alert(1) %253C%252Fscript%253E'} | ${'&lt;script&gt; alert(1) &lt;/script&gt;'}
      `('escapes title correctly', ({ xssPayload, escapedPayload }) => {
        expect(templateFunction({ id: 42, title: xssPayload })).toBe(
          `<li><small>*iteration:42</small> ${escapedPayload}</li>`,
        );
      });
    });
  });

  describe('AmazonQ quick action', () => {
    const EXPECTATION_ISSUE_SUB_COMMANDS = [
      {
        name: 'dev',
        description: Q_ISSUE_SUB_COMMANDS.dev.description,
      },
      {
        name: 'transform',
        description: Q_ISSUE_SUB_COMMANDS.transform.description,
      },
    ];
    const EXPECTATION_MR_SUB_COMMANDS = [
      {
        name: 'dev',
        description: Q_MERGE_REQUEST_SUB_COMMANDS.dev.description,
      },
      {
        name: 'review',
        description: Q_MERGE_REQUEST_SUB_COMMANDS.review.description,
      },
      {
        name: 'test',
        description: Q_MERGE_REQUEST_SUB_COMMANDS.test.description,
      },
    ];
    const EXPECTATION_MR_DIFF_SUB_COMMANDS = [
      ...EXPECTATION_MR_SUB_COMMANDS.filter((cmd) => cmd.name !== 'test'),
      {
        name: 'test',
        description: Q_MERGE_REQUEST_DIFF_SUB_COMMANDS.test.description,
      },
    ];

    describe.each`
      availableCommand | textareaAttributes                                             | expectation
      ${'foo'}         | ${''}                                                          | ${[]}
      ${'q'}           | ${''}                                                          | ${EXPECTATION_ISSUE_SUB_COMMANDS}
      ${'q'}           | ${'data-noteable-type="MergeRequest"'}                         | ${EXPECTATION_MR_SUB_COMMANDS}
      ${'q'}           | ${'data-noteable-type="MergeRequest" data-can-suggest="true"'} | ${EXPECTATION_MR_DIFF_SUB_COMMANDS}
    `(
      'with availableCommands=$availableCommand, textareaAttributes=$textareaAttributes',
      ({ availableCommand, textareaAttributes, expectation }) => {
        beforeEach(() => {
          jest
            .spyOn(AjaxCache, 'retrieve')
            .mockReturnValue(Promise.resolve([{ name: availableCommand }]));
          setHTMLFixture(
            `<textarea data-supports-quick-actions="true" ${textareaAttributes}></textarea>`,
          );
          instance = new GfmAutoCompleteEE({
            commands: `${TEST_HOST}/autocomplete_sources/commands`,
          });
          $textarea = $('textarea');
          instance.setup($textarea, {});
        });

        it('renders expected sub commands', async () => {
          triggerDropdown('/');

          await waitForPromises();

          triggerDropdown('q ');

          expect(getDropdownSubcommands('at-view-q')).toEqual(expectation);
        });
      },
    );
  });
});
