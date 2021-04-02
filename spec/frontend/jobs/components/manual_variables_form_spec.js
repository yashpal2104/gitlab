import { createLocalVue, mount, shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import Vuex from 'vuex';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import Form from '~/jobs/components/manual_variables_form.vue';

const localVue = createLocalVue();

Vue.use(Vuex);

describe('Manual Variables Form', () => {
  let wrapper;
  let store;

  const requiredProps = {
    action: {
      path: '/play',
      method: 'post',
      button_title: 'Trigger this manual action',
    },
    variablesSettingsUrl: '/settings',
  };

  const createComponent = (props = {}, mountFn = shallowMount) => {
    store = new Vuex.Store({
      actions: {
        triggerManualJob: jest.fn(),
      },
    });

    wrapper = extendedWrapper(
      mountFn(localVue.extend(Form), {
        propsData: props,
        localVue,
        store,
      }),
    );
  };

  const findInputKey = () => wrapper.findComponent({ ref: 'inputKey' });
  const findInputValue = () => wrapper.findComponent({ ref: 'inputSecretValue' });

  const findTriggerBtn = () => wrapper.findByTestId('trigger-manual-job-btn');
  const findHelpText = () => wrapper.findByTestId('form-help-text');
  const findDeleteVarBtn = () => wrapper.findByTestId('delete-variable-btn');

  afterEach(() => {
    wrapper.destroy();
  });

  describe('shallowMount', () => {
    beforeEach(() => {
      createComponent(requiredProps);
    });

    it('renders empty form with correct placeholders', () => {
      expect(findInputKey().attributes('placeholder')).toBe('Input variable key');
      expect(findInputValue().attributes('placeholder')).toBe('Input variable value');
    });

    it('renders help text with provided link', () => {
      expect(findHelpText().text()).toBe(
        'Specify variable values to be used in this run. The values specified in CI/CD settings will be used as default',
      );

      expect(wrapper.find('a').attributes('href')).toBe(requiredProps.variablesSettingsUrl);
    });

    describe('when adding a new variable', () => {
      it('creates a new variable when user types a new key and resets the form', async () => {
        await findInputKey().setValue('new key');

        expect(wrapper.vm.variables).toHaveLength(1);
        expect(wrapper.vm.variables[0].key).toBe('new key');
        expect(findInputKey().attributes('value')).toBe(undefined);
      });

      it('creates a new variable when user types a new value and resets the form', async () => {
        await findInputValue().setValue('new value');

        expect(wrapper.vm.variables).toHaveLength(1);
        expect(wrapper.vm.variables[0].secret_value).toBe('new value');
        expect(findInputValue().attributes('value')).toBe(undefined);
      });
    });

    describe('when deleting a variable', () => {
      it('removes the variable row', async () => {
        await wrapper.setData({
          variables: [
            {
              key: 'new key',
              secret_value: 'value',
              id: '1',
            },
          ],
        });

        findDeleteVarBtn().vm.$emit('click');

        expect(wrapper.vm.variables).toHaveLength(0);
      });
    });
  });

  describe('mount', () => {
    it('trigger button is disabled after trigger action', async () => {
      createComponent(requiredProps, mount);

      expect(findTriggerBtn().props('disabled')).toBe(false);

      await findTriggerBtn().trigger('click');

      expect(findTriggerBtn().props('disabled')).toBe(true);
    });
  });
});
