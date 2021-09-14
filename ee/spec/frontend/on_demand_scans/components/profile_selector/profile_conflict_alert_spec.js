import { GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ProfileConflictAlert from 'ee/on_demand_scans/components/profile_selector/profile_conflict_alert.vue';

describe('ProfileConflictAlert', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ProfileConflictAlert, {
      stubs: {
        GlSprintf,
      },
      provide: {
        siteProfilesLibraryPath: '/dast_scans#site-profiles',
      },
    });
  };

  it('renders properly', () => {
    createComponent();
    expect(wrapper.element).toMatchSnapshot();
  });
});
