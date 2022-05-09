import { GlTable, GlDrawer } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import { merge } from 'lodash';
import VueApollo from 'vue-apollo';
import { POLICY_TYPE_OPTIONS } from 'ee/threat_monitoring/components/constants';
import PoliciesList from 'ee/threat_monitoring/components/policies/policies_list.vue';
import PolicyDrawer from 'ee/threat_monitoring/components/policy_drawer/policy_drawer.vue';
import { NAMESPACE_TYPES } from 'ee/threat_monitoring/constants';
import projectScanExecutionPoliciesQuery from 'ee/threat_monitoring/graphql/queries/project_scan_execution_policies.query.graphql';
import scanResultPoliciesQuery from 'ee/threat_monitoring/graphql/queries/scan_result_policies.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { projectScanExecutionPolicies, scanResultPolicies } from '../../mocks/mock_apollo';
import {
  mockScanExecutionPoliciesResponse,
  mockScanResultPoliciesResponse,
} from '../../mocks/mock_data';

Vue.use(VueApollo);

const namespacePath = 'path/to/project/or/group';
const projectScanExecutionPoliciesSpy = projectScanExecutionPolicies(
  mockScanExecutionPoliciesResponse,
);
const scanResultPoliciesSpy = scanResultPolicies(mockScanResultPoliciesResponse);
const defaultRequestHandlers = {
  projectScanExecutionPolicies: projectScanExecutionPoliciesSpy,
  scanResultPolicies: scanResultPoliciesSpy,
};
describe('PoliciesList component', () => {
  let wrapper;
  let requestHandlers;

  const factory = (mountFn = mountExtended) => (options = {}) => {
    const { handlers, ...wrapperOptions } = options;

    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = mountFn(
      PoliciesList,
      merge(
        {
          propsData: {
            documentationPath: 'documentation_path',
          },
          provide: {
            documentationPath: 'path/to/docs',
            namespaceType: NAMESPACE_TYPES.PROJECT,
            namespacePath,
            newPolicyPath: `${namespacePath}/-/security/policies/new`,
          },
          apolloProvider: createMockApollo([
            [projectScanExecutionPoliciesQuery, requestHandlers.projectScanExecutionPolicies],
            [scanResultPoliciesQuery, requestHandlers.scanResultPolicies],
          ]),
          stubs: {
            PolicyDrawer: stubComponent(PolicyDrawer, {
              props: {
                ...PolicyDrawer.props,
                ...GlDrawer.props,
              },
            }),
            NoPoliciesEmptyState: true,
          },
        },
        wrapperOptions,
      ),
    );
  };
  const mountShallowWrapper = factory(shallowMountExtended);
  const mountWrapper = factory();

  const findPolicyTypeFilter = () => wrapper.findByTestId('policy-type-filter');
  const findPoliciesTable = () => wrapper.findComponent(GlTable);
  const findPolicyStatusCells = () => wrapper.findAllByTestId('policy-status-cell');
  const findPolicyDrawer = () => wrapper.findByTestId('policyDrawer');

  afterEach(() => {
    wrapper.destroy();
  });

  describe('initial state', () => {
    beforeEach(() => {
      mountShallowWrapper({});
    });

    it('renders closed editor drawer', () => {
      const editorDrawer = findPolicyDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props('open')).toBe(false);
    });

    it('fetches policies', () => {
      expect(requestHandlers.projectScanExecutionPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
      });
      expect(requestHandlers.scanResultPolicies).toHaveBeenCalledWith({
        fullPath: namespacePath,
      });
    });

    it("sets table's loading state", () => {
      expect(findPoliciesTable().attributes('busy')).toBe('true');
    });
  });

  describe('given policies have been fetched', () => {
    let rows;

    beforeEach(async () => {
      mountWrapper();
      await waitForPromises();
      rows = wrapper.findAll('tr');
    });

    describe.each`
      rowIndex | expectedPolicyName                           | expectedPolicyType
      ${1}     | ${mockScanExecutionPoliciesResponse[0].name} | ${'Scan execution'}
      ${2}     | ${mockScanResultPoliciesResponse[0].name}    | ${'Scan result'}
    `('policy in row #$rowIndex', ({ rowIndex, expectedPolicyName, expectedPolicyType }) => {
      let row;

      beforeEach(() => {
        row = rows.at(rowIndex);
      });

      it(`renders ${expectedPolicyName} in the name cell`, () => {
        expect(row.findAll('td').at(1).text()).toBe(expectedPolicyName);
      });

      it(`renders ${expectedPolicyType} in the policy type cell`, () => {
        expect(row.findAll('td').at(2).text()).toBe(expectedPolicyType);
      });
    });

    it.each`
      description         | filterBy                                          | hiddenTypes
      ${'scan execution'} | ${POLICY_TYPE_OPTIONS.POLICY_TYPE_SCAN_EXECUTION} | ${[POLICY_TYPE_OPTIONS.POLICY_TYPE_SCAN_RESULT]}
      ${'scan result'}    | ${POLICY_TYPE_OPTIONS.POLICY_TYPE_SCAN_RESULT}    | ${[POLICY_TYPE_OPTIONS.POLICY_TYPE_SCAN_EXECUTION]}
    `('policies filtered by $description type', async ({ filterBy, hiddenTypes }) => {
      findPolicyTypeFilter().vm.$emit('input', filterBy.value);
      await nextTick();

      expect(findPoliciesTable().text()).toContain(filterBy.text);
      hiddenTypes.forEach((hiddenType) => {
        expect(findPoliciesTable().text()).not.toContain(hiddenType.text);
      });
    });

    it('does emit `update-policy-list` and refetch scan execution policies on `shouldUpdatePolicyList` change to `false`', async () => {
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(1);
      expect(wrapper.emitted('update-policy-list')).toBeUndefined();
      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();
      expect(wrapper.emitted('update-policy-list')).toStrictEqual([[false]]);
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
    });

    it('does not emit `update-policy-list` or refetch scan execution policies on `shouldUpdatePolicyList` change to `false`', async () => {
      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();
      wrapper.setProps({ shouldUpdatePolicyList: false });
      await nextTick();
      expect(wrapper.emitted('update-policy-list')).toStrictEqual([[false]]);
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
    });
  });

  describe('group-level policies', () => {
    beforeEach(async () => {
      mountShallowWrapper({
        provide: {
          namespacePath,
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });
      await waitForPromises();
    });

    it('does not fetch policies', () => {
      expect(requestHandlers.projectScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.scanResultPolicies).not.toHaveBeenCalled();
    });
  });

  describe('status column', () => {
    beforeEach(async () => {
      mountWrapper();
      await waitForPromises();
    });

    it('renders a checkmark icon for enabled policies', () => {
      const icon = findPolicyStatusCells().at(0).find('svg');

      expect(icon.exists()).toBe(true);
      expect(icon.props()).toMatchObject({
        name: 'check-circle-filled',
        ariaLabel: 'Enabled',
      });
    });

    it('renders a "Disabled" label for screen readers for disabled policies', () => {
      const span = findPolicyStatusCells().at(1).find('span');

      expect(span.exists()).toBe(true);
      expect(span.attributes('class')).toBe('gl-sr-only');
      expect(span.text()).toBe('Disabled');
    });
  });

  describe.each`
    description         | policy                                  | policyType         | editPolicyPath
    ${'scan execution'} | ${mockScanExecutionPoliciesResponse[0]} | ${'scanExecution'} | ${`${namespacePath}/-/security/policies/${encodeURIComponent(mockScanExecutionPoliciesResponse[0].name)}/edit?type=scan_execution_policy`}
    ${'scan result'}    | ${mockScanResultPoliciesResponse[0]}    | ${'scanResult'}    | ${`${namespacePath}/-/security/policies/${encodeURIComponent(mockScanResultPoliciesResponse[0].name)}/edit?type=scan_result_policy`}
  `('given there is a $description policy selected', ({ policy, policyType, editPolicyPath }) => {
    beforeEach(() => {
      mountShallowWrapper();
      findPoliciesTable().vm.$emit('row-selected', [policy]);
    });

    it('renders opened editor drawer', () => {
      const editorDrawer = findPolicyDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props()).toMatchObject({
        editPolicyPath,
        open: true,
        policy,
        policyType,
      });
    });
  });
});
