import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/threat_monitoring/components/constants';
import PolicyEditor from 'ee/threat_monitoring/components/policy_editor/policy_editor_v2.vue';
import ScanExecutionPolicyEditor from 'ee/threat_monitoring/components/policy_editor/scan_execution_policy/scan_execution_policy_editor.vue';
import ScanResultPolicyEditor from 'ee/threat_monitoring/components/policy_editor/scan_result_policy/scan_result_policy_editor.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT, NAMESPACE_TYPES } from 'ee/threat_monitoring/constants';

describe('PolicyEditor V2 component', () => {
  let wrapper;

  const findGroupLevelAlert = () => wrapper.findByTestId('group-level-alert');
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findScanExecutionPolicyEditor = () => wrapper.findComponent(ScanExecutionPolicyEditor);
  const findScanResultPolicyEditor = () => wrapper.findComponent(ScanResultPolicyEditor);

  const factory = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyEditor, {
      propsData: {
        selectedPolicyType: 'container',
      },
      provide: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        policyType: undefined,
        ...provide,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('project-level', () => {
    beforeEach(factory);

    it.each`
      component              | status                | findComponent          | state
      ${'group-level alert'} | ${'does not display'} | ${findGroupLevelAlert} | ${false}
      ${'error alert'}       | ${'does not display'} | ${findErrorAlert}      | ${false}
    `('$status the $component', ({ findComponent, state }) => {
      expect(findComponent().exists()).toBe(state);
    });

    it('renders the network policy editor component', () => {
      expect(findScanExecutionPolicyEditor().props('existingPolicy')).toBe(null);
    });

    it('shows an alert when "error" is emitted from the component', async () => {
      const errorMessage = 'test';
      findScanExecutionPolicyEditor().vm.$emit('error', errorMessage);
      await nextTick();
      const alert = findErrorAlert();
      expect(alert.exists()).toBe(true);
      expect(alert.props('title')).toBe(errorMessage);
    });

    it('shows an alert with details when multiline "error" is emitted from the component', async () => {
      const errorMessages = 'title\ndetail1';
      findScanExecutionPolicyEditor().vm.$emit('error', errorMessages);
      await nextTick();
      const alert = findErrorAlert();
      expect(alert.exists()).toBe(true);
      expect(alert.props('title')).toBe('title');
      expect(alert.text()).toBe('detail1');
    });

    it.each`
      policyTypeId                                         | findComponent
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value} | ${findScanExecutionPolicyEditor}
      ${POLICY_TYPE_COMPONENT_OPTIONS.scanResult.value}    | ${findScanResultPolicyEditor}
    `(
      'renders the policy editor of type $policyType when selected',
      async ({ findComponent, policyTypeId }) => {
        wrapper.setProps({ selectedPolicyType: policyTypeId });
        await nextTick();
        const component = findComponent();
        expect(component.exists()).toBe(true);
        expect(component.props('isEditing')).toBe(false);
      },
    );
  });

  describe('group-level', () => {
    beforeEach(() => {
      factory({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
    });

    it('does display the group-level alert', () => {
      expect(findGroupLevelAlert().exists()).toBe(true);
    });
  });
});
