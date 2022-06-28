import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import PipelineEditorMiniGraph from '~/pipeline_editor/components/header/pipeline_editor_mini_graph.vue';
import PipelineMiniGraph from '~/pipelines/components/pipelines_list/pipeline_mini_graph.vue';
import getLinkedPipelinesQuery from '~/projects/commit_box/info/graphql/queries/get_linked_pipelines.query.graphql';
import { mockLinkedPipelines, mockProjectFullPath, mockProjectPipeline } from '../../mock_data';

Vue.use(VueApollo);

describe('Pipeline Status', () => {
  let wrapper;
  let mockApollo;
  let mockLinkedPipelinesQuery;

  const createComponent = ({ hasStages = true, options } = {}) => {
    wrapper = shallowMount(PipelineEditorMiniGraph, {
      provide: {
        dataMethod: 'graphql',
        projectFullPath: mockProjectFullPath,
      },
      propsData: {
        pipeline: mockProjectPipeline({ hasStages }).pipeline,
      },
      ...options,
    });
  };

  const createComponentWithApollo = (hasStages = true) => {
    const handlers = [[getLinkedPipelinesQuery, mockLinkedPipelinesQuery]];
    mockApollo = createMockApollo(handlers);

    createComponent({
      hasStages,
      options: {
        apolloProvider: mockApollo,
      },
    });
  };

  const findPipelineMiniGraph = () => wrapper.findComponent(PipelineMiniGraph);

  beforeEach(() => {
    mockLinkedPipelinesQuery = jest.fn();
  });

  afterEach(() => {
    mockLinkedPipelinesQuery.mockReset();
    wrapper.destroy();
  });

  describe('when querying pipeline stages', () => {
    describe('when query returns data', () => {
      beforeEach(() => {
        mockLinkedPipelinesQuery.mockResolvedValue(mockLinkedPipelines());
        createComponentWithApollo();
      });

      describe('pipeline mini graph rendering based on given data', () => {
        it('renders pipeline mini graph', () => {
          expect(findPipelineMiniGraph().exists()).toBe(true);
        });
      });
    });

    describe('when query returns no data', () => {
      beforeEach(() => {
        mockLinkedPipelinesQuery.mockResolvedValue(mockLinkedPipelines());
        const hasStages = false;
        createComponentWithApollo(hasStages);
      });

      describe('pipeline mini graph rendering based on given data', () => {
        it('does not render pipeline mini graph', () => {
          expect(findPipelineMiniGraph().exists()).toBe(false);
        });
      });
    });
  });
});
