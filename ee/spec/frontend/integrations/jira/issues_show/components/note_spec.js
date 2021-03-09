import { shallowMount } from '@vue/test-utils';
import JiraIssueNote from 'ee/integrations/jira/issues_show/components/note.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

import { mockJiraIssueComment } from '../mock_data';

describe('JiraIssuesNote', () => {
  let wrapper;

  const findTimeAgoLink = () => wrapper.findByTestId('time-ago-link');
  const findBadgesContainer = () => wrapper.findByTestId('badges-container');
  const findAuthorUsernameLink = () => wrapper.findByTestId('author-username');

  const createComponent = ({ props, slots } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(JiraIssueNote, {
        propsData: {
          authorName: mockJiraIssueComment.author.name,
          authorWebUrl: mockJiraIssueComment.author.web_url,
          authorAvatarUrl: mockJiraIssueComment.author.avatar_url,
          noteCreatedAt: mockJiraIssueComment.created_at,
          noteBodyHtml: mockJiraIssueComment.body_html,
          ...props,
        },
        slots,
      }),
    );
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('template', () => {
    it('renders note', () => {
      createComponent();

      expect(wrapper.html()).toMatchSnapshot();
    });

    it.each`
      id           | expectedTimeAgoHref
      ${undefined} | ${'#'}
      ${'1234'}    | ${'#1234'}
    `(
      'sets "time ago" link to $expectedTimeAgoHref when id is $id',
      ({ id, expectedTimeAgoHref }) => {
        createComponent({ props: { id } });

        expect(findTimeAgoLink().attributes('href')).toBe(expectedTimeAgoHref);
      },
    );

    describe('with badge slot', () => {
      it('renders slot content', () => {
        createComponent({ slots: { badges: 'testing badges content' } });

        expect(findBadgesContainer().html()).toContain('testing badges content');
      });
    });

    describe('with author username', () => {
      it('renders slot content', () => {
        createComponent({ props: { authorUsername: 'testuser' } });

        expect(findAuthorUsernameLink().html()).toContain('testuser');
      });
    });
  });
});
