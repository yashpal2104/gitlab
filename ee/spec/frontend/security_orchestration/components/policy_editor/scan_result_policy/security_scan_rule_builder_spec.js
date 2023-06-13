import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import Api from 'ee/api';
import SecurityScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result_policy/security_scan_rule_builder.vue';
import PolicyRuleMultiSelect from 'ee/security_orchestration/components/policy_rule_multi_select.vue';
import PolicyRuleBranchSelection from 'ee/security_orchestration/components/policy_editor/scan_result_policy/policy_rule_branch_selection.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result_policy/scan_filters/severity_filter.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result_policy/scan_filters/status_filter.vue';
import ScanTypeSelect from 'ee/security_orchestration/components/policy_editor/scan_result_policy/base_layout/scan_type_select.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  securityScanBuildRule,
  SCAN_FINDING,
} from 'ee/security_orchestration/components/policy_editor/scan_result_policy/lib/rules';
import { getDefaultRule } from 'ee/security_orchestration/components/policy_editor/scan_result_policy/lib';
import {
  SEVERITY,
  STATUS,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
} from 'ee/security_orchestration/components/policy_editor/scan_result_policy/scan_filters/constants';
import {
  ANY_OPERATOR,
  MORE_THAN_OPERATOR,
} from 'ee/security_orchestration/components/policy_editor/constants';

describe('SecurityScanRuleBuilder', () => {
  let wrapper;

  const PROTECTED_BRANCHES_MOCK = [{ id: 1, name: 'main' }];

  const UPDATED_RULE = {
    type: SCAN_FINDING,
    branches: [PROTECTED_BRANCHES_MOCK[0].name],
    scanners: ['dast'],
    vulnerabilities_allowed: 1,
    severity_levels: ['high'],
    vulnerability_states: ['newly_detected'],
  };

  const factory = (propsData = {}, provide = {}) => {
    wrapper = mountExtended(SecurityScanRuleBuilder, {
      propsData: {
        initRule: securityScanBuildRule(),
        ...propsData,
      },
      provide: {
        namespaceId: '1',
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
      stubs: {
        PolicyRuleBranchSelection: true,
      },
    });
  };

  const findBranches = () => wrapper.findComponent(PolicyRuleBranchSelection);
  const findGroupLevelBranches = () => wrapper.findByTestId('group-level-branch');
  const findScanners = () => wrapper.findByTestId('scanners-select');
  const findSeverities = () => wrapper.findByTestId('severities-select');
  const findVulnStates = () => wrapper.findByTestId('vulnerability-states-select');
  const findVulnAllowedOperator = () => wrapper.findByTestId('vulnerabilities-allowed-operator');
  const findVulnAllowed = () => wrapper.findByTestId('vulnerabilities-allowed-input');
  const findAllPolicyRuleMultiSelect = () => wrapper.findAllComponents(PolicyRuleMultiSelect);
  const findScanFilterSelector = () => wrapper.findComponent(ScanFilterSelector);
  const findStatusFilter = () => wrapper.findComponent(StatusFilter);
  const findAllStatusFilters = () => wrapper.findAllComponents(StatusFilter);
  const findSeverityFilter = () => wrapper.findComponent(SeverityFilter);
  const findScanTypeSelect = () => wrapper.findComponent(ScanTypeSelect);

  beforeEach(() => {
    jest
      .spyOn(Api, 'projectProtectedBranches')
      .mockReturnValue(Promise.resolve(PROTECTED_BRANCHES_MOCK));
  });

  describe('initial rendering', () => {
    beforeEach(() => {
      factory();
    });

    it('renders one field for each attribute of the rule', () => {
      expect(findBranches().exists()).toBe(true);
      expect(findGroupLevelBranches().exists()).toBe(false);
      expect(findScanners().exists()).toBe(true);
      expect(findSeverities().exists()).toBe(false);
      expect(findVulnStates().exists()).toBe(false);
      expect(findVulnAllowedOperator().exists()).toBe(true);
      expect(findVulnAllowed().exists()).toBe(false);
    });

    it('includes select all option to all PolicyRuleMultiSelect', () => {
      const props = findAllPolicyRuleMultiSelect().wrappers.map((w) => w.props());

      expect(props).toEqual(
        expect.arrayContaining([expect.objectContaining({ includeSelectAll: true })]),
      );
    });
  });

  describe('when editing any attribute of the rule', () => {
    it.each`
      currentComponent | event        | newValue                                           | expected
      ${findBranches}  | ${'changed'} | ${{ branches: [PROTECTED_BRANCHES_MOCK[0].name] }} | ${{ branches: UPDATED_RULE.branches }}
      ${findScanners}  | ${'input'}   | ${UPDATED_RULE.scanners}                           | ${{ scanners: UPDATED_RULE.scanners }}
    `(
      'triggers a changed event (by $currentComponent) with the updated rule',
      async ({ currentComponent, event, newValue, expected }) => {
        factory();
        await nextTick();
        currentComponent().vm.$emit(event, newValue);
        await nextTick();

        expect(wrapper.emitted().changed).toEqual([[expect.objectContaining(expected)]]);
      },
    );
  });

  describe('vulnerabilities allowed', () => {
    it('renders MORE_THAN_OPERATOR when initial vulnerabilities_allowed are not zero', async () => {
      factory({ initRule: { ...UPDATED_RULE, vulnerabilities_allowed: 1 } });
      await nextTick();
      expect(findVulnAllowed().exists()).toBe(true);
      expect(findVulnAllowedOperator().props('selected')).toEqual(MORE_THAN_OPERATOR);
    });

    describe('when editing vulnerabilities allowed', () => {
      beforeEach(async () => {
        factory();
        await nextTick();
      });

      it.each`
        currentComponent   | newValue                                | expected
        ${findVulnAllowed} | ${UPDATED_RULE.vulnerabilities_allowed} | ${{ vulnerabilities_allowed: UPDATED_RULE.vulnerabilities_allowed }}
        ${findVulnAllowed} | ${''}                                   | ${{ vulnerabilities_allowed: 0 }}
      `(
        'triggers a changed event (by $currentComponent) with the updated rule',
        async ({ currentComponent, newValue, expected }) => {
          findVulnAllowedOperator().vm.$emit('select', MORE_THAN_OPERATOR);
          await nextTick();
          currentComponent().vm.$emit('input', newValue);
          await nextTick();

          expect(wrapper.emitted().changed).toEqual([[expect.objectContaining(expected)]]);
        },
      );

      it('resets vulnerabilities_allowed to 0 after changing to ANY_OPERATOR', async () => {
        findVulnAllowedOperator().vm.$emit('select', MORE_THAN_OPERATOR);
        await nextTick();
        findVulnAllowed().vm.$emit('input', 1);
        await nextTick();
        findVulnAllowedOperator().vm.$emit('select', ANY_OPERATOR);
        await nextTick();

        expect(wrapper.emitted().changed).toEqual([
          [expect.objectContaining({ vulnerabilities_allowed: 1 })],
          [expect.objectContaining({ vulnerabilities_allowed: 0 })],
        ]);
      });
    });
  });

  it.each`
    currentComponent  | selectedFilter
    ${findSeverities} | ${SEVERITY}
    ${findVulnStates} | ${STATUS}
  `('select different filters', async ({ currentComponent, selectedFilter }) => {
    factory();
    await findScanFilterSelector().vm.$emit('select', selectedFilter);

    expect(currentComponent().exists()).toBe(true);
  });

  it('selects the correct filters', () => {
    factory({ initRule: UPDATED_RULE });
    expect(findScanFilterSelector().props('selected')).toEqual({
      newly_detected: ['new_needs_triage', 'new_dismissed'],
      severity: ['high'],
      status: null,
    });
  });

  it('can add second status filter', async () => {
    factory({ initRule: UPDATED_RULE });

    await findScanFilterSelector().vm.$emit('select', STATUS);

    const statusFilters = findAllStatusFilters();

    expect(statusFilters).toHaveLength(2);
    expect(statusFilters.at(0).props('filter')).toEqual(NEWLY_DETECTED);
    expect(statusFilters.at(1).props('filter')).toEqual(PREVIOUSLY_EXISTING);
    expect(findScanFilterSelector().props('selected')).toEqual({
      newly_detected: ['new_needs_triage', 'new_dismissed'],
      previously_existing: [],
      severity: ['high'],
      status: [],
    });
  });

  it('renders filters for exiting rule', () => {
    factory({ initRule: UPDATED_RULE });

    expect(findSeverities().exists()).toBe(true);
    expect(findVulnStates().exists()).toBe(true);
  });

  it.each`
    currentComponent      | selectedFilter
    ${findSeverityFilter} | ${SEVERITY}
    ${findStatusFilter}   | ${NEWLY_DETECTED}
    ${findStatusFilter}   | ${PREVIOUSLY_EXISTING}
  `('removes existing filters', async ({ currentComponent, selectedFilter }) => {
    factory();
    await findScanFilterSelector().vm.$emit('select', selectedFilter);
    expect(currentComponent().exists()).toBe(true);

    await currentComponent().vm.$emit('remove', selectedFilter);

    expect(currentComponent().exists()).toBe(false);
    expect(wrapper.emitted('changed')).toHaveLength(1);
  });

  it.each`
    currentComponent      | selectedFilter    | emittedPayload
    ${findSeverityFilter} | ${SEVERITY}       | ${{ ...UPDATED_RULE, severity_levels: [] }}
    ${findStatusFilter}   | ${NEWLY_DETECTED} | ${{ ...UPDATED_RULE, vulnerability_states: [] }}
  `(
    'removes existing filters for saved policies',
    ({ currentComponent, selectedFilter, emittedPayload }) => {
      factory({
        initRule: UPDATED_RULE,
      });

      expect(currentComponent().exists()).toBe(true);

      currentComponent().vm.$emit('remove', selectedFilter);

      expect(wrapper.emitted('changed')).toEqual([[emittedPayload]]);
    },
  );

  it('can change scan type', () => {
    factory({ initRule: securityScanBuildRule() });
    findScanTypeSelect().vm.$emit('select', SCAN_FINDING);

    expect(wrapper.emitted('set-scan-type')).toEqual([[getDefaultRule(SCAN_FINDING)]]);
  });
});
