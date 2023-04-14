import { GlEmptyState } from '@gitlab/ui';
import { shallowMount, mount } from '@vue/test-utils';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import Vue, { nextTick } from 'vue';
import Vuex from 'vuex';
import Component from 'ee/analytics/cycle_analytics/components/base.vue';
import DurationChart from 'ee/analytics/cycle_analytics/components/duration_chart.vue';
import DurationOverviewChart from 'ee/analytics/cycle_analytics/components/duration_overview_chart.vue';
import TypeOfWorkCharts from 'ee/analytics/cycle_analytics/components/type_of_work_charts.vue';
import ValueStreamSelect from 'ee/analytics/cycle_analytics/components/value_stream_select.vue';
import ValueStreamAggregationStatus from 'ee/analytics/cycle_analytics/components/value_stream_aggregation_status.vue';
import ValueStreamEmptyState from 'ee/analytics/cycle_analytics/components/value_stream_empty_state.vue';
import createStore from 'ee/analytics/cycle_analytics/store';
import waitForPromises from 'helpers/wait_for_promises';
import {
  currentGroup,
  groupNamespace as namespace,
  projectNamespace,
  createdBefore,
  createdAfter,
  initialPaginationQuery,
  selectedProjects as rawSelectedProjects,
} from 'jest/analytics/cycle_analytics/mock_data';
import ValueStreamMetrics from '~/analytics/shared/components/value_stream_metrics.vue';
import { toYmd } from '~/analytics/shared/utils';
import PathNavigation from '~/analytics/cycle_analytics/components/path_navigation.vue';
import StageTable from '~/analytics/cycle_analytics/components/stage_table.vue';
import ValueStreamFilters from '~/analytics/cycle_analytics/components/value_stream_filters.vue';
import {
  OVERVIEW_STAGE_ID,
  I18N_VSA_ERROR_STAGES,
  I18N_VSA_ERROR_STAGE_MEDIAN,
  I18N_VSA_ERROR_SELECTED_STAGE,
} from '~/analytics/cycle_analytics/constants';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as commonUtils from '~/lib/utils/common_utils';
import {
  HTTP_STATUS_FORBIDDEN,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';
import * as urlUtils from '~/lib/utils/url_utility';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import {
  valueStreams,
  endpoints,
  customizableStagesAndEvents,
  issueStage,
  issueEvents,
  groupLabels,
  tasksByTypeData,
  aggregationData,
} from '../mock_data';

const noDataSvgPath = 'path/to/no/data';
const noAccessSvgPath = 'path/to/no/access';
const emptyStateSvgPath = 'path/to/empty/state';
const stage = null;

Vue.use(Vuex);
jest.mock('~/alert');

const defaultStubs = {
  'tasks-by-type-chart': true,
  'labels-selector': true,
  DurationChart: true,
  ValueStreamSelect: true,
  Metrics: true,
  UrlSync,
};

const [selectedValueStream] = valueStreams;
const selectedProjects = rawSelectedProjects.map(({ pathWithNamespace: fullPath, ...rest }) => ({
  ...rest,
  fullPath,
}));
const initialCycleAnalyticsState = {
  selectedValueStream,
  createdAfter,
  createdBefore,
  groupPath: currentGroup.fullPath,
  stage,
  aggregation: aggregationData,
  namespace,
  enableTasksByTypeChart: true,
  enableProjectsFilter: true,
  enableCustomizableStages: true,
};

const mocks = {
  $toast: {
    show: jest.fn(),
  },
  $apollo: {
    query: jest.fn().mockResolvedValue({
      data: { group: { projects: { nodes: [] } } },
    }),
  },
};

function mockRequiredRoutes(mockAdapter) {
  mockAdapter.onGet(endpoints.stageData).reply(HTTP_STATUS_OK, issueEvents);
  mockAdapter.onGet(endpoints.tasksByTypeTopLabelsData).reply(HTTP_STATUS_OK, groupLabels);
  mockAdapter.onGet(endpoints.tasksByTypeData).reply(HTTP_STATUS_OK, { ...tasksByTypeData });
  mockAdapter
    .onGet(endpoints.baseStagesEndpoint)
    .reply(HTTP_STATUS_OK, { ...customizableStagesAndEvents });
  mockAdapter
    .onGet(endpoints.durationData)
    .reply(HTTP_STATUS_OK, customizableStagesAndEvents.stages);
  mockAdapter.onGet(endpoints.stageMedian).reply(HTTP_STATUS_OK, { value: null });
  mockAdapter.onGet(endpoints.valueStreamData).reply(HTTP_STATUS_OK, valueStreams);
}

async function shouldMergeUrlParams(wrapper, result) {
  await nextTick();
  expect(urlUtils.mergeUrlParams).toHaveBeenCalledWith(result, window.location.href, {
    spreadArrays: true,
  });
  expect(commonUtils.historyPushState).toHaveBeenCalled();
}

describe('EE Value Stream Analytics component', () => {
  let wrapper;
  let mock;
  let store;

  async function createComponent(options = {}) {
    const {
      opts = {
        stubs: defaultStubs,
      },
      shallow = true,
      withStageSelected = false,
      features = {},
      initialState = initialCycleAnalyticsState,
      props = {},
      selectedStage = null,
    } = options;

    store = createStore();
    await store.dispatch('initializeCycleAnalytics', {
      ...initialState,
      features: {
        ...features,
      },
    });

    const func = shallow ? shallowMount : mount;
    const comp = func(Component, {
      store,
      propsData: {
        emptyStateSvgPath,
        noDataSvgPath,
        noAccessSvgPath,
        ...props,
      },
      provide: {
        glFeatures: {
          ...features,
        },
      },
      mocks,
      ...opts,
    });

    if (withStageSelected || selectedStage) {
      await store.dispatch('receiveGroupStagesSuccess', customizableStagesAndEvents.stages);
      if (selectedStage) {
        await store.dispatch('setSelectedStage', selectedStage);
        await store.dispatch('fetchStageData', selectedStage.slug);
      } else {
        await store.dispatch('setDefaultSelectedStage');
      }
    }
    return comp;
  }

  const findAggregationStatus = () => wrapper.findComponent(ValueStreamAggregationStatus);
  const findPathNavigation = () => wrapper.findComponent(PathNavigation);
  const findStageTable = () => wrapper.findComponent(StageTable);
  const findOverviewMetrics = () => wrapper.findComponent(ValueStreamMetrics);
  const findFilterBar = () => wrapper.findComponent(ValueStreamFilters);

  const displaysMetrics = (flag) => {
    expect(findOverviewMetrics().exists()).toBe(flag);
  };

  const displaysStageTable = (flag) => {
    expect(findStageTable().exists()).toBe(flag);
  };

  const displaysDurationChart = (flag) => {
    expect(wrapper.findComponent(DurationChart).exists()).toBe(flag);
  };

  const displaysDurationOverviewChart = (flag) => {
    expect(wrapper.findComponent(DurationOverviewChart).exists()).toBe(flag);
  };

  const displaysTypeOfWork = (flag) => {
    expect(wrapper.findComponent(TypeOfWorkCharts).exists()).toBe(flag);
  };

  const displaysPathNavigation = (flag) => {
    expect(findPathNavigation().exists()).toBe(flag);
  };

  const displaysFilters = (flag) => {
    expect(findFilterBar().exists()).toBe(flag);
  };

  const displaysProjectFilter = (flag) => {
    expect(findFilterBar().props('hasProjectFilter')).toBe(flag);
  };

  const displaysValueStreamSelect = (flag) => {
    expect(wrapper.findComponent(ValueStreamSelect).exists()).toBe(flag);
  };

  describe('with no value streams', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      wrapper = await createComponent({
        initialState: { ...initialCycleAnalyticsState, valueStreams: [] },
      });
    });

    afterEach(() => {
      mock.restore();
    });

    it('displays an empty state', () => {
      const emptyState = wrapper.findComponent(ValueStreamEmptyState);

      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('emptyStateSvgPath')).toBe(emptyStateSvgPath);
    });

    it('does not display the metrics cards', () => {
      displaysMetrics(false);
    });

    it('does not display the stage table', () => {
      displaysStageTable(false);
    });

    it('does not display the duration chart', () => {
      displaysDurationChart(false);
    });

    it('does not display the duration overview chart', () => {
      displaysDurationOverviewChart(false);
    });

    it('does not display the path navigation', () => {
      displaysPathNavigation(false);
    });

    it('does not display the value stream select component', () => {
      displaysValueStreamSelect(false);
    });
  });

  describe('the user does not have access to the group', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);

      wrapper = await createComponent();

      await store.dispatch('receiveCycleAnalyticsDataError', {
        response: { status: HTTP_STATUS_FORBIDDEN },
      });
    });

    it('renders the no access information', () => {
      const emptyState = wrapper.findComponent(GlEmptyState);

      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('svgPath')).toBe(noAccessSvgPath);
    });

    it('does not display the metrics', () => {
      displaysMetrics(false);
    });

    it('does not display the stage table', () => {
      displaysStageTable(false);
    });

    it('does not display the tasks by type chart', () => {
      displaysTypeOfWork(false);
    });

    it('does not display the duration chart', () => {
      displaysDurationChart(false);
    });

    it('does not display the duration overview chart', () => {
      displaysDurationOverviewChart(false);
    });

    it('does not display the path navigation', () => {
      displaysPathNavigation(false);
    });
  });

  describe('the user has access to the group', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
      wrapper = await createComponent({ withStageSelected: true });
    });

    afterEach(() => {
      mock.restore();
    });

    it('hides the empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(false);
    });

    it('displays the value stream select component', () => {
      displaysValueStreamSelect(true);
    });

    it('displays the filter bar', () => {
      displaysFilters(true);
    });

    it('displays the project filter', () => {
      displaysProjectFilter(true);
    });

    it('displays the metrics', () => {
      displaysMetrics(true);
    });

    it('displays the type of work chart', () => {
      displaysTypeOfWork(true);
    });

    it('displays the duration overview chart', () => {
      displaysDurationOverviewChart(true);
    });

    it('does not display the duration chart', () => {
      displaysDurationChart(false);
    });

    it('hides the stage table', () => {
      displaysStageTable(false);
    });

    it('renders the aggregation status', () => {
      expect(findAggregationStatus().exists()).toBe(true);
      expect(findAggregationStatus().props('data')).toEqual(aggregationData);
    });

    it('does not render a link to the value streams dashboard', () => {
      expect(findOverviewMetrics().props('dashboardsPath')).toBeNull();
    });

    describe('Without the overview stage selected', () => {
      beforeEach(async () => {
        mock = new MockAdapter(axios);
        mockRequiredRoutes(mock);
        wrapper = await createComponent({ selectedStage: issueStage });
      });

      it('displays the stage table', () => {
        displaysStageTable(true);
      });

      it('sets the `includeProjectName` prop on stage table', () => {
        expect(findStageTable().props('includeProjectName')).toBe(true);
      });

      it('displays the path navigation', () => {
        displaysPathNavigation(true);
      });

      it('displays the duration chart', () => {
        displaysDurationChart(true);
      });

      it('does not display the duration overview chart', () => {
        displaysDurationOverviewChart(false);
      });
    });
  });

  describe('with no aggregation data', () => {
    beforeEach(async () => {
      wrapper = await createComponent({
        initialState: {
          ...initialCycleAnalyticsState,
          aggregation: {
            ...aggregationData,
            lastRunAt: null,
          },
        },
      });
    });

    it('does not render the aggregation status', () => {
      expect(findAggregationStatus().exists()).toBe(false);
    });
  });

  describe('with failed requests while loading', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
    });

    afterEach(() => {
      mock.restore();
    });

    it('will display an error if the fetchGroupStagesAndEvents request fails', async () => {
      expect(createAlert).not.toHaveBeenCalled();

      mock
        .onGet(endpoints.baseStagesEndpoint)
        .reply(HTTP_STATUS_NOT_FOUND, { response: { status: HTTP_STATUS_NOT_FOUND } });
      wrapper = await createComponent();

      expect(createAlert).toHaveBeenCalledWith({ message: I18N_VSA_ERROR_STAGES });
    });

    it('will display an error if the fetchStageData request fails', async () => {
      expect(createAlert).not.toHaveBeenCalled();

      mock
        .onGet(endpoints.stageData)
        .reply(HTTP_STATUS_NOT_FOUND, { response: { status: HTTP_STATUS_NOT_FOUND } });

      wrapper = await createComponent({ selectedStage: issueStage });

      expect(createAlert).toHaveBeenCalledWith({ message: I18N_VSA_ERROR_SELECTED_STAGE });
    });

    it('will display an error if the fetchTopRankedGroupLabels request fails', async () => {
      expect(createAlert).not.toHaveBeenCalled();

      mock
        .onGet(endpoints.tasksByTypeTopLabelsData)
        .reply(HTTP_STATUS_NOT_FOUND, { response: { status: HTTP_STATUS_NOT_FOUND } });
      wrapper = await createComponent();
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching the top labels for the selected group',
      });
    });

    it('will display an error if the fetchTasksByTypeData request fails', async () => {
      expect(createAlert).not.toHaveBeenCalled();

      mock
        .onGet(endpoints.tasksByTypeData)
        .reply(HTTP_STATUS_NOT_FOUND, { response: { status: HTTP_STATUS_NOT_FOUND } });
      wrapper = await createComponent();
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching data for the tasks by type chart',
      });
    });

    it('will display an error if the fetchStageMedian request fails', async () => {
      expect(createAlert).not.toHaveBeenCalled();

      mock
        .onGet(endpoints.stageMedian)
        .reply(HTTP_STATUS_NOT_FOUND, { response: { status: HTTP_STATUS_NOT_FOUND } });
      wrapper = await createComponent();

      expect(createAlert).toHaveBeenCalledWith({ message: I18N_VSA_ERROR_STAGE_MEDIAN });
    });

    it('will display an error if the fetchStageData request is successful but has an embedded error', async () => {
      const tooMuchDataError = 'There is too much data to calculate. Please change your selection.';
      mock.onGet(endpoints.stageData).reply(HTTP_STATUS_OK, { error: tooMuchDataError });

      wrapper = await createComponent({ selectedStage: issueStage });

      displaysStageTable(true);
      expect(findStageTable().props('emptyStateMessage')).toBe(tooMuchDataError);
      expect(findStageTable().props('stageEvents')).toEqual([]);
      expect(findStageTable().props('pagination')).toEqual({});
    });
  });

  describe('Path navigation', () => {
    const selectedStage = { id: 2, title: 'Plan' };
    const overviewStage = { id: OVERVIEW_STAGE_ID, title: 'Overview' };
    let actionSpies = {};

    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
      wrapper = await createComponent();
      actionSpies = {
        setDefaultSelectedStage: jest.spyOn(wrapper.vm, 'setDefaultSelectedStage'),
        setSelectedStage: jest.spyOn(wrapper.vm, 'setSelectedStage'),
        updateStageTablePagination: jest.spyOn(wrapper.vm, 'updateStageTablePagination'),
      };
    });

    afterEach(() => {
      mock.restore();
    });

    it('when a stage is selected', () => {
      findPathNavigation().vm.$emit('selected', selectedStage);

      expect(actionSpies.setDefaultSelectedStage).not.toHaveBeenCalled();
      expect(actionSpies.setSelectedStage).toHaveBeenCalledWith(selectedStage);
      expect(actionSpies.updateStageTablePagination).toHaveBeenCalledWith({
        ...initialPaginationQuery,
        page: 1,
      });
    });

    it('when the overview is selected', () => {
      findPathNavigation().vm.$emit('selected', overviewStage);

      expect(actionSpies.setSelectedStage).not.toHaveBeenCalled();
      expect(actionSpies.updateStageTablePagination).not.toHaveBeenCalled();
      expect(actionSpies.setDefaultSelectedStage).toHaveBeenCalled();
    });
  });

  describe('Url parameters', () => {
    const defaultParams = {
      value_stream_id: selectedValueStream.id,
      created_after: toYmd(createdAfter),
      created_before: toYmd(createdBefore),
      stage_id: null,
      project_ids: null,
      sort: null,
      direction: null,
      page: null,
    };

    const selectedStage = { title: 'Plan', id: 2 };
    const selectedProjectIds = selectedProjects.map(({ id }) => getIdFromGraphQLId(id));

    beforeEach(async () => {
      commonUtils.historyPushState = jest.fn();
      urlUtils.mergeUrlParams = jest.fn();

      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('with minimal parameters set', () => {
      beforeEach(async () => {
        wrapper = await createComponent();

        await store.dispatch('initializeCycleAnalytics', {
          ...initialCycleAnalyticsState,
          selectedValueStream: null,
        });
      });

      it('sets the created_after and created_before url parameters', async () => {
        await shouldMergeUrlParams(wrapper, defaultParams);
      });
    });

    describe('with selectedValueStream set', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
        await store.dispatch('initializeCycleAnalytics', initialCycleAnalyticsState);
        await nextTick();
      });

      it('sets the value_stream_id url parameter', async () => {
        await shouldMergeUrlParams(wrapper, {
          ...defaultParams,
          created_after: toYmd(createdAfter),
          created_before: toYmd(createdBefore),
          project_ids: null,
        });
      });
    });

    describe('with selectedProjectIds set', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
        await store.dispatch('setSelectedProjects', selectedProjects);
        await nextTick();
      });

      it('sets the project_ids url parameter', async () => {
        await shouldMergeUrlParams(wrapper, {
          ...defaultParams,
          created_after: toYmd(createdAfter),
          created_before: toYmd(createdBefore),
          project_ids: selectedProjectIds,
          stage_id: null,
        });
      });
    });

    describe('with selectedStage set', () => {
      beforeEach(async () => {
        wrapper = await createComponent({
          initialState: {
            ...initialCycleAnalyticsState,
            pagination: initialPaginationQuery,
          },
          selectedStage,
        });
      });

      it('sets the stage, sort, direction and page parameters', async () => {
        await shouldMergeUrlParams(wrapper, {
          ...defaultParams,
          ...initialPaginationQuery,
          stage_id: selectedStage.id,
        });
      });
    });
  });

  describe('with`groupAnalyticsDashboardsPage=true` and `groupLevelAnalyticsDashboard=true`', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
    });

    afterEach(() => {
      mock.restore();
    });

    it('renders a link to the value streams dashboard', async () => {
      wrapper = await createComponent({
        withStageSelected: true,
        features: { groupAnalyticsDashboardsPage: true, groupLevelAnalyticsDashboard: true },
      });

      expect(findOverviewMetrics().props('dashboardsPath')).toBe(
        '/groups/foo/-/analytics/dashboards/value_streams_dashboard',
      );
    });

    it('renders the value streams dashboard with selected projects as a query parameter', async () => {
      wrapper = await createComponent({
        withStageSelected: true,
        features: { groupAnalyticsDashboardsPage: true, groupLevelAnalyticsDashboard: true },
        initialState: {
          ...initialCycleAnalyticsState,
          selectedProjects,
        },
      });

      expect(findOverviewMetrics().props('dashboardsPath')).toContain(
        '?query=group/cool-project,group/another-cool-project',
      );
    });
  });

  describe('with `enableTasksByTypeChart=false`', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
      wrapper = await createComponent({
        withStageSelected: true,
        initialState: {
          ...initialCycleAnalyticsState,
          enableTasksByTypeChart: false,
        },
      });
    });

    afterEach(() => {
      mock.restore();
    });

    it('does not display the tasks by type chart', () => {
      displaysTypeOfWork(false);
    });
  });

  describe('with `enableCustomizableStages=false`', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
      wrapper = await createComponent({
        withStageSelected: true,
        features: { groupAnalyticsDashboardsPage: true, groupLevelAnalyticsDashboard: true },
        initialState: {
          ...initialCycleAnalyticsState,
          enableCustomizableStages: false,
        },
      });
    });

    afterEach(() => {
      mock.restore();
    });

    it('does not display the value stream selector', () => {
      displaysValueStreamSelect(false);
    });
  });

  describe('with `enableProjectsFilter=false`', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
      wrapper = await createComponent({
        withStageSelected: true,
        features: { groupAnalyticsDashboardsPage: true, groupLevelAnalyticsDashboard: true },
        initialState: {
          ...initialCycleAnalyticsState,
          enableProjectsFilter: false,
        },
      });
    });

    afterEach(() => {
      mock.restore();
    });

    it('does not display the project filter', () => {
      displaysProjectFilter(false);
    });
  });

  describe('with a project namespace', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);
      mockRequiredRoutes(mock);
      wrapper = await createComponent({
        withStageSelected: true,
        features: { groupAnalyticsDashboardsPage: true, groupLevelAnalyticsDashboard: true },
        initialState: {
          ...initialCycleAnalyticsState,
          enableProjectsFilter: false,
          namespace: projectNamespace,
          project: 'fake-id',
        },
      });
    });

    afterEach(() => {
      mock.restore();
    });

    it('renders a link to the value streams dashboard', () => {
      expect(findOverviewMetrics().props('dashboardsPath')).toBe(
        '/groups/foo/-/analytics/dashboards/value_streams_dashboard?query=some/cool/path',
      );
    });
  });
});
