import events from 'test_fixtures/controller/users/activity.json';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ContributionEventApproved from '~/contribution_events/components/contribution_event/contribution_event_approved.vue';
import ContributionEventBase from '~/contribution_events/components/contribution_event/contribution_event_base.vue';
import TargetLink from '~/contribution_events/components/target_link.vue';
import ResourceParentLink from '~/contribution_events/components/resource_parent_link.vue';
import { eventApproved } from '../../utils';

const defaultPropsData = {
  event: eventApproved(events),
};

describe('ContributionEventApproved', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = mountExtended(ContributionEventApproved, {
      propsData: defaultPropsData,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders `ContributionEventBase`', () => {
    expect(wrapper.findComponent(ContributionEventBase).props()).toEqual({
      event: defaultPropsData.event,
      iconName: 'approval-solid',
      iconClass: 'gl-text-green-500',
    });
  });

  it('renders message', () => {
    expect(wrapper.findByTestId('event-body').text()).toBe(
      `Approved merge request ${defaultPropsData.event.target.reference_link_text} in ${defaultPropsData.event.resource_parent.full_name}.`,
    );
  });

  it('renders target link', () => {
    expect(wrapper.findComponent(TargetLink).props('event')).toEqual(defaultPropsData.event);
  });

  it('renders resource parent link', () => {
    expect(wrapper.findComponent(ResourceParentLink).props('event')).toEqual(
      defaultPropsData.event,
    );
  });
});
