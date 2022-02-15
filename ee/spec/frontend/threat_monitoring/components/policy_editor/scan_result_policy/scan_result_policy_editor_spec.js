import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import PolicyEditorLayout from 'ee/threat_monitoring/components/policy_editor/policy_editor_layout.vue';
import {
  DEFAULT_SCAN_RESULT_POLICY,
  fromYaml,
} from 'ee/threat_monitoring/components/policy_editor/scan_result_policy/lib';
import ScanResultPolicyEditor from 'ee/threat_monitoring/components/policy_editor/scan_result_policy/scan_result_policy_editor.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/threat_monitoring/constants';
import {
  mockScanResultManifest,
  mockScanResultObject,
} from 'ee_jest/threat_monitoring/mocks/mock_data';
import { visitUrl } from '~/lib/utils/url_utility';

import { modifyPolicy } from 'ee/threat_monitoring/components/policy_editor/utils';
import { SECURITY_POLICY_ACTIONS } from 'ee/threat_monitoring/components/policy_editor/constants';

jest.mock('~/lib/utils/url_utility', () => ({
  joinPaths: jest.requireActual('~/lib/utils/url_utility').joinPaths,
  visitUrl: jest.fn().mockName('visitUrlMock'),
  setUrlFragment: jest.requireActual('~/lib/utils/url_utility').setUrlFragment,
}));

const newlyCreatedPolicyProject = {
  branch: 'main',
  fullPath: 'path/to/new-project',
};
jest.mock('ee/threat_monitoring/components/policy_editor/utils', () => ({
  assignSecurityPolicyProject: jest.fn().mockResolvedValue({
    branch: 'main',
    fullPath: 'path/to/new-project',
  }),
  modifyPolicy: jest.fn().mockResolvedValue({ id: '2' }),
}));

describe('ScanResultPolicyEditor', () => {
  let wrapper;
  const defaultProjectPath = 'path/to/project';
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';
  const assignedPolicyProject = {
    branch: 'main',
    fullPath: 'path/to/existing-project',
  };
  const scanResultPolicyApprovers = [];

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(ScanResultPolicyEditor, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        projectId: 1,
        projectPath: defaultProjectPath,
        scanPolicyDocumentationPath,
        scanResultPolicyApprovers,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = () => {
    return factory({
      propsData: {
        assignedPolicyProject,
        existingPolicy: mockScanResultObject,
        isEditing: true,
      },
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(PolicyEditorLayout);

  afterEach(() => {
    wrapper.destroy();
  });

  describe('default', () => {
    it('updates the policy yaml when "update-yaml" is emitted', async () => {
      factory();
      await nextTick();
      const newManifest = 'new yaml!';
      expect(findPolicyEditorLayout().attributes('yamleditorvalue')).toBe(
        DEFAULT_SCAN_RESULT_POLICY,
      );
      await findPolicyEditorLayout().vm.$emit('update-yaml', newManifest);
      expect(findPolicyEditorLayout().attributes('yamleditorvalue')).toBe(newManifest);
    });

    it.each`
      status                            | action                             | event              | factoryFn                    | yamlEditorValue               | currentlyAssignedPolicyProject
      ${'to save a new policy'}         | ${SECURITY_POLICY_ACTIONS.APPEND}  | ${'save-policy'}   | ${factory}                   | ${DEFAULT_SCAN_RESULT_POLICY} | ${newlyCreatedPolicyProject}
      ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE} | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockScanResultManifest}     | ${assignedPolicyProject}
      ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}  | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockScanResultManifest}     | ${assignedPolicyProject}
    `(
      'navigates to the new merge request when "modifyPolicy" is emitted $status',
      async ({ action, event, factoryFn, yamlEditorValue, currentlyAssignedPolicyProject }) => {
        factoryFn();
        await nextTick();
        findPolicyEditorLayout().vm.$emit(event);
        await waitForPromises();
        expect(modifyPolicy).toHaveBeenCalledWith({
          action,
          assignedPolicyProject: currentlyAssignedPolicyProject,
          name:
            action === SECURITY_POLICY_ACTIONS.APPEND
              ? fromYaml(yamlEditorValue).name
              : mockScanResultObject.name,
          projectPath: defaultProjectPath,
          yamlEditorValue,
        });
        expect(visitUrl).toHaveBeenCalledWith(
          `/${currentlyAssignedPolicyProject.fullPath}/-/merge_requests/2`,
        );
      },
    );
  });

  describe('when a user is not an owner of the project', () => {
    it('displays the empty state with the appropriate properties', async () => {
      factory({ provide: { disableScanPolicyUpdate: true } });
      const emptyState = findEmptyState();

      expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
      expect(emptyState.props('primaryButtonLink')).toMatch('scan-result-policy-editor');
      expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
    });
  });
});
