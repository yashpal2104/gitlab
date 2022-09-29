import { mount } from '@vue/test-utils';
import { GlIcon } from '@gitlab/ui';

import TableHeaderComponent from 'ee/group_member_contributions/components/table_header.vue';
import defaultColumns from 'ee/group_member_contributions/constants';

import { mockSortOrders } from '../mock_data';

const createComponent = (columns = defaultColumns, sortOrders = mockSortOrders) =>
  mount(TableHeaderComponent, { propsData: { columns, sortOrders } });

describe('TableHeaderComponent', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  const firstColumnName = 'fullname';

  it('renders table column header with sort order icon', () => {
    const firstHeaderItem = wrapper.find('tr th');

    expect(firstHeaderItem.exists()).toBe(true);
    expect(firstHeaderItem.getComponent(GlIcon).props('name')).toBe('chevron-lg-up');
  });

  it('emits `onColumnClick` event with columnName param on component instance when clicked on relevant header', async () => {
    await wrapper.find('th').trigger('click');

    expect(wrapper.emitted('onColumnClick')[0]).toStrictEqual([firstColumnName]);
  });

  it('updates columnIconMeta prop for provided columnName when clicked on relevant header', async () => {
    jest.spyOn(wrapper.vm, 'getColumnIconMeta');

    await wrapper.find('th').trigger('click');

    expect(wrapper.vm.getColumnIconMeta).toHaveBeenCalledWith(firstColumnName, mockSortOrders);
  });

  it('sorts by first column by default', () => {
    const firstHeaderItem = wrapper.find('tr th');

    expect(firstHeaderItem.find('svg[data-testid="chevron-lg-up-icon"]').exists()).toBe(true);
    expect(firstHeaderItem.attributes('title')).toBe('Ascending');
  });
});
