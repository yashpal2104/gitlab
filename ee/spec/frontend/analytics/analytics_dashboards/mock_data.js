import { TEST_HOST } from 'spec/test_constants';

export const TEST_TRACKING_KEY = 'gid://gitlab/Project/2';

export const TEST_COLLECTOR_HOST = TEST_HOST;

export const TEST_EMPTY_DASHBOARD_SVG_PATH = 'illustration/empty-dashboard';

export const TEST_ROUTER_BACK_HREF = 'go-back';

export const TEST_CUSTOM_DASHBOARDS_PROJECT = {
  fullPath: 'test/test-dashboards',
  id: 123,
  name: 'test-dashboards',
};

export const TEST_CUSTOM_DASHBOARDS_LIST = [
  {
    file_name: 'product_analytics',
    lock_label: null,
  },
  {
    file_name: 'new_dashboard.yml',
    lock_label: null,
  },
];

export const TEST_VISUALIZATION = () => ({
  version: 1,
  type: 'LineChart',
  slug: 'test_visualization',
  data: {
    type: 'cube_analytics',
    query: {
      measures: ['TrackedEvents.count'],
      timeDimensions: [
        {
          dimension: 'TrackedEvents.utcTime',
          granularity: 'day',
        },
      ],
      limit: 100,
      timezone: 'UTC',
      filters: [],
      dimensions: [],
    },
  },
});

export const TEST_CUSTOM_DASHBOARD = () => ({
  slug: 'new_dashboard',
  title: 'New dashboard',
  panels: [
    {
      id: 1,
      visualization: 'page_views_per_day',
      visualizationType: 'yml',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 7,
        height: 6,
      },
      options: {},
    },
  ],
});

export const TEST_DASHBOARD_GRAPHQL_404_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      productAnalyticsDashboards: {
        nodes: [],
        __typename: 'ProductAnalyticsDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const getGraphQLDashboard = (options = {}, withPanels = true) => {
  const dashboard = {
    slug: '',
    title: '',
    userDefined: false,
    description: 'Understand your audience',
    __typename: 'ProductAnalyticsDashboard',
    ...options,
  };

  if (withPanels) {
    return {
      ...dashboard,
      panels: {
        nodes: [
          {
            title: 'Daily Active Users',
            gridAttributes: {
              yPos: 1,
              xPos: 0,
              width: 6,
              height: 5,
            },
            queryOverrides: {
              limit: 200,
            },
            visualization: {
              slug: 'line_chart',
              type: 'LineChart',
              options: {
                xAxis: {
                  name: 'Time',
                  type: 'time',
                },
                yAxis: {
                  name: 'Counts',
                  type: 'time',
                },
              },
              data: {
                type: 'cube_analytics',
                query: {
                  measures: ['SnowplowTrackedEvents.uniqueUsersCount'],
                  timeDimensions: [
                    {
                      dimension: 'SnowplowTrackedEvents.derivedTstamp',
                      granularity: 'day',
                    },
                  ],
                  limit: 100,
                  timezone: 'UTC',
                  filters: [],
                  dimensions: [],
                },
              },
              __typename: 'ProductAnalyticsDashboardVisualization',
            },
            __typename: 'ProductAnalyticsDashboardPanel',
          },
        ],
        __typename: 'ProductAnalyticsDashboardPanelConnection',
      },
    };
  }

  return dashboard;
};

export const TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/73',
      productAnalyticsVisualizations: {
        nodes: [
          {
            slug: 'another_one',
            type: 'SingleStat',
            data: {
              type: 'cube_analytics',
              query: {
                measures: ['SnowplowTrackedEvents.count'],
                filters: [
                  {
                    member: 'SnowplowTrackedEvents.event',
                    operator: 'equals',
                    values: ['click'],
                  },
                ],
                limit: 100,
                timezone: 'UTC',
                dimensions: [],
                timeDimensions: [],
              },
            },
            options: {},
            __typename: 'ProductAnalyticsDashboardVisualization',
          },
        ],
      },
    },
  },
};

export const TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      productAnalyticsDashboards: {
        nodes: [
          getGraphQLDashboard({
            slug: 'custom_dashboard',
            title: 'Custom Dashboard',
            userDefined: true,
          }),
        ],
        __typename: 'ProductAnalyticsDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      productAnalyticsDashboards: {
        nodes: [getGraphQLDashboard({ slug: 'audience', title: 'Audience' })],
        __typename: 'ProductAnalyticsDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      productAnalyticsDashboards: {
        nodes: [
          getGraphQLDashboard({ slug: 'audience', title: 'Audience' }, false),
          getGraphQLDashboard({ slug: 'behavior', title: 'Behavior' }, false),
          getGraphQLDashboard(
            { slug: 'new_dashboard', title: 'new_dashboard', userDefined: true },
            false,
          ),
        ],
        __typename: 'ProductAnalyticsDashboardConnection',
      },
      __typename: 'Project',
    },
  },
};

export const mockResultSet = {
  seriesNames: () => [
    {
      title: 'pageview, TrackedEvents Count',
      key: 'pageview,TrackedEvents.count',
      yValues: ['pageview', 'TrackedEvents.count'],
    },
  ],
  chartPivot: () => [
    {
      x: '2022-11-09T00:00:00.000',
      xValues: ['2022-11-09T00:00:00.000'],
      'pageview,TrackedEvents.count': 55,
    },
    {
      x: '2022-11-10T00:00:00.000',
      xValues: ['2022-11-10T00:00:00.000'],
      'pageview,TrackedEvents.count': 14,
    },
  ],
  tableColumns: () => [
    {
      key: 'TrackedEvents.utcTime.day',
      title: 'TrackedEvents Utc Time',
      shortTitle: 'Utc Time',
      type: 'time',
      dataIndex: 'TrackedEvents.utcTime.day',
    },
    {
      key: 'TrackedEvents.eventType',
      title: 'TrackedEvents Event Type',
      shortTitle: 'Event Type',
      type: 'string',
      dataIndex: 'TrackedEvents.eventType',
    },
    {
      key: 'TrackedEvents.count',
      type: 'number',
      dataIndex: 'TrackedEvents.count',
      title: 'TrackedEvents Count',
      shortTitle: 'Count',
    },
  ],
  tablePivot: () => [
    {
      'TrackedEvents.utcTime.day': '2022-11-09T00:00:00.000',
      'TrackedEvents.eventType': 'pageview',
      'TrackedEvents.count': '55',
    },
    {
      'TrackedEvents.utcTime.day': '2022-11-10T00:00:00.000',
      'TrackedEvents.eventType': 'pageview',
      'TrackedEvents.count': '14',
    },
  ],
  rawData: () => [
    {
      'TrackedEvents.userLanguage': 'en-US',
      'TrackedEvents.count': '36',
      'TrackedEvents.url': 'https://example.com/us',
    },
    {
      'TrackedEvents.userLanguage': 'es-ES',
      'TrackedEvents.count': '60',
      'TrackedEvents.url': 'https://example.com/es',
    },
  ],
};

export const mockTableWithLinksResultSet = {
  tableColumns: () => [
    {
      key: 'TrackedEvents.docPath',
      title: 'Tracked Events Doc Path',
      shortTitle: 'Doc Path',
      type: 'string',
      dataIndex: 'TrackedEvents.docPath',
    },
    {
      key: 'TrackedEvents.url',
      title: 'Tracked Events Url',
      shortTitle: 'Url',
      type: 'string',
      dataIndex: 'TrackedEvents.url',
    },
    {
      key: 'TrackedEvents.pageViewsCount',
      type: 'number',
      dataIndex: 'TrackedEvents.pageViewsCount',
      title: 'Tracked Events Page Views Count',
      shortTitle: 'Page Views Count',
    },
  ],
  tablePivot: () => [
    {
      'TrackedEvents.docPath': '/foo',
      'TrackedEvents.url': 'https://example.com/foo',
      'TrackedEvents.pageViewsCount': '1',
    },
  ],
};

export const mockFilters = {
  startDate: new Date('2015-01-01'),
  endDate: new Date('2016-01-01'),
};

export const mockMetaData = {
  cubes: [
    {
      name: 'SnowplowTrackedEvents',
      title: 'Snowplow Tracked Events',
      connectedComponent: 2,
      measures: [
        {
          name: 'SnowplowTrackedEvents.count',
          title: 'Snowplow Tracked Events Count',
          shortTitle: 'Count',
          cumulativeTotal: false,
          cumulative: false,
          type: 'number',
          aggType: 'count',
          drillMembers: ['SnowplowTrackedEvents.eventId', 'SnowplowTrackedEvents.pageTitle'],
          drillMembersGrouped: {
            measures: [],
            dimensions: ['SnowplowTrackedEvents.eventId', 'SnowplowTrackedEvents.pageTitle'],
          },
          isVisible: true,
        },
      ],
      dimensions: [
        {
          name: 'SnowplowTrackedEvents.pageUrlhosts',
          title: 'Snowplow Tracked Events Page Urlhosts',
          type: 'string',
          shortTitle: 'Page Urlhosts',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.pageUrlpath',
          title: 'Snowplow Tracked Events Page Urlpath',
          type: 'string',
          shortTitle: 'Page Urlpath',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.event',
          title: 'Snowplow Tracked Events Event',
          type: 'string',
          shortTitle: 'Event',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.pageTitle',
          title: 'Snowplow Tracked Events Page Title',
          type: 'string',
          shortTitle: 'Page Title',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.osFamily',
          title: 'Snowplow Tracked Events Os Family',
          type: 'string',
          shortTitle: 'Os Family',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.osName',
          title: 'Snowplow Tracked Events Os Name',
          type: 'string',
          shortTitle: 'Os Name',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.osVersion',
          title: 'Snowplow Tracked Events Os Version',
          type: 'string',
          shortTitle: 'Os Version',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.osVersionMajor',
          title: 'Snowplow Tracked Events Os Version Major',
          type: 'string',
          shortTitle: 'Os Version Major',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.agentName',
          title: 'Snowplow Tracked Events Agent Name',
          type: 'string',
          shortTitle: 'Agent Name',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.agentVersion',
          title: 'Snowplow Tracked Events Agent Version',
          type: 'string',
          shortTitle: 'Agent Version',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.pageReferrer',
          title: 'Snowplow Tracked Events Page Referrer',
          type: 'string',
          shortTitle: 'Page Referrer',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.pageUrl',
          title: 'Snowplow Tracked Events Page Url',
          type: 'string',
          shortTitle: 'Page Url',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.useragent',
          title: 'Snowplow Tracked Events Useragent',
          type: 'string',
          shortTitle: 'Useragent',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.userId',
          title: 'Snowplow Tracked Events User Id',
          type: 'string',
          shortTitle: 'User Id',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.derivedTstamp',
          title: 'Snowplow Tracked Events Derived Tstamp',
          type: 'time',
          shortTitle: 'Derived Tstamp',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.browserLanguage',
          title: 'Snowplow Tracked Events Browser Language',
          type: 'string',
          shortTitle: 'Browser Language',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.documentLanguage',
          title: 'Snowplow Tracked Events Document Language',
          type: 'string',
          shortTitle: 'Document Language',
          suggestFilterValues: true,
          isVisible: true,
        },
        {
          name: 'SnowplowTrackedEvents.viewportSize',
          title: 'Snowplow Tracked Events Viewport Size',
          type: 'string',
          shortTitle: 'Viewport Size',
          suggestFilterValues: true,
          isVisible: true,
        },
      ],
      segments: [],
    },
  ],
};
