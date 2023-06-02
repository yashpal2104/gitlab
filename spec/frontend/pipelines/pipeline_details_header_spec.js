import { GlAlert, GlBadge, GlLoadingIcon, GlModal } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PipelineDetailsHeader from '~/pipelines/components/pipeline_details_header.vue';
import { BUTTON_TOOLTIP_RETRY, BUTTON_TOOLTIP_CANCEL } from '~/pipelines/constants';
import TimeAgo from '~/pipelines/components/pipelines_list/time_ago.vue';
import CiBadgeLink from '~/vue_shared/components/ci_badge_link.vue';
import cancelPipelineMutation from '~/pipelines/graphql/mutations/cancel_pipeline.mutation.graphql';
import deletePipelineMutation from '~/pipelines/graphql/mutations/delete_pipeline.mutation.graphql';
import retryPipelineMutation from '~/pipelines/graphql/mutations/retry_pipeline.mutation.graphql';
import getPipelineDetailsQuery from '~/pipelines/graphql/queries/get_pipeline_header_data.query.graphql';
import {
  pipelineHeaderSuccess,
  pipelineHeaderRunning,
  pipelineHeaderFailed,
  pipelineRetryMutationResponseSuccess,
  pipelineCancelMutationResponseSuccess,
  pipelineDeleteMutationResponseSuccess,
  pipelineRetryMutationResponseFailed,
  pipelineCancelMutationResponseFailed,
  pipelineDeleteMutationResponseFailed,
} from './mock_data';

Vue.use(VueApollo);

describe('Pipeline details header', () => {
  let wrapper;
  let glModalDirective;

  const successHandler = jest.fn().mockResolvedValue(pipelineHeaderSuccess);
  const runningHandler = jest.fn().mockResolvedValue(pipelineHeaderRunning);
  const failedHandler = jest.fn().mockResolvedValue(pipelineHeaderFailed);

  const retryMutationHandlerSuccess = jest
    .fn()
    .mockResolvedValue(pipelineRetryMutationResponseSuccess);
  const cancelMutationHandlerSuccess = jest
    .fn()
    .mockResolvedValue(pipelineCancelMutationResponseSuccess);
  const deleteMutationHandlerSuccess = jest
    .fn()
    .mockResolvedValue(pipelineDeleteMutationResponseSuccess);
  const retryMutationHandlerFailed = jest
    .fn()
    .mockResolvedValue(pipelineRetryMutationResponseFailed);
  const cancelMutationHandlerFailed = jest
    .fn()
    .mockResolvedValue(pipelineCancelMutationResponseFailed);
  const deleteMutationHandlerFailed = jest
    .fn()
    .mockResolvedValue(pipelineDeleteMutationResponseFailed);

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findStatus = () => wrapper.findComponent(CiBadgeLink);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTimeAgo = () => wrapper.findComponent(TimeAgo);
  const findAllBadges = () => wrapper.findAllComponents(GlBadge);
  const findPipelineName = () => wrapper.findByTestId('pipeline-name');
  const findTotalJobs = () => wrapper.findByTestId('total-jobs');
  const findComputeCredits = () => wrapper.findByTestId('compute-credits');
  const findCommitLink = () => wrapper.findByTestId('commit-link');
  const findPipelineRunningText = () => wrapper.findByTestId('pipeline-running-text').text();
  const findPipelineRefText = () => wrapper.findByTestId('pipeline-ref-text').text();
  const findRetryButton = () => wrapper.findByTestId('retry-pipeline');
  const findCancelButton = () => wrapper.findByTestId('cancel-pipeline');
  const findDeleteButton = () => wrapper.findByTestId('delete-pipeline');
  const findDeleteModal = () => wrapper.findComponent(GlModal);

  const defaultHandlers = [[getPipelineDetailsQuery, successHandler]];

  const defaultProvideOptions = {
    pipelineIid: 1,
    paths: {
      pipelinesPath: '/namespace/my-project/-/pipelines',
      fullProject: '/namespace/my-project',
      triggeredByPath: '',
    },
  };

  const defaultProps = {
    name: 'Ruby 3.0 master branch pipeline',
    totalJobs: '50',
    computeCredits: '0.65',
    yamlErrors: 'errors',
    failureReason: 'pipeline failed',
    badges: {
      schedule: true,
      child: false,
      latest: true,
      mergeTrainPipeline: false,
      invalid: false,
      failed: false,
      autoDevops: false,
      detached: false,
      stuck: false,
    },
    refText:
      'Related merge request <a class="mr-iid" href="/root/ci-project/-/merge_requests/1">!1</a> to merge <a class="ref-name" href="/root/ci-project/-/commits/test">test</a>',
  };

  const createMockApolloProvider = (handlers) => {
    return createMockApollo(handlers);
  };

  const createComponent = (handlers = defaultHandlers, props = defaultProps) => {
    glModalDirective = jest.fn();

    wrapper = shallowMountExtended(PipelineDetailsHeader, {
      provide: {
        ...defaultProvideOptions,
      },
      propsData: {
        ...props,
      },
      directives: {
        glModal: {
          bind(_, { value }) {
            glModalDirective(value);
          },
        },
      },
      apolloProvider: createMockApolloProvider(handlers),
    });
  };

  describe('loading state', () => {
    it('shows a loading state while graphQL is fetching initial data', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('defaults', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('does not display loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('displays pipeline status', () => {
      expect(findStatus().exists()).toBe(true);
    });

    it('displays pipeline name', () => {
      expect(findPipelineName().text()).toBe(defaultProps.name);
    });

    it('displays total jobs', () => {
      expect(findTotalJobs().text()).toBe('50 Jobs');
    });

    it('has link to commit', () => {
      const {
        data: {
          project: { pipeline },
        },
      } = pipelineHeaderSuccess;

      expect(findCommitLink().attributes('href')).toBe(pipeline.commit.webPath);
    });

    it('displays correct badges', () => {
      expect(findAllBadges()).toHaveLength(2);
      expect(wrapper.findByText('latest').exists()).toBe(true);
      expect(wrapper.findByText('Scheduled').exists()).toBe(true);
    });

    it('displays ref text', () => {
      expect(findPipelineRefText()).toBe('Related merge request !1 to merge test');
    });
  });

  describe('finished pipeline', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('displays compute credits', () => {
      expect(findComputeCredits().text()).toBe('0.65');
    });

    it('displays time ago', () => {
      expect(findTimeAgo().exists()).toBe(true);
    });
  });

  describe('running pipeline', () => {
    beforeEach(async () => {
      createComponent([[getPipelineDetailsQuery, runningHandler]]);

      await waitForPromises();
    });

    it('does not display compute credits', () => {
      expect(findComputeCredits().exists()).toBe(false);
    });

    it('does not display time ago', () => {
      expect(findTimeAgo().exists()).toBe(false);
    });

    it('displays pipeline running text', () => {
      expect(findPipelineRunningText()).toBe('In progress, queued for 3600 seconds');
    });
  });

  describe('actions', () => {
    describe('retry action', () => {
      beforeEach(async () => {
        createComponent([
          [getPipelineDetailsQuery, failedHandler],
          [retryPipelineMutation, retryMutationHandlerSuccess],
        ]);

        await waitForPromises();
      });

      it('should call retryPipeline Mutation with pipeline id', () => {
        findRetryButton().vm.$emit('click');

        expect(retryMutationHandlerSuccess).toHaveBeenCalledWith({
          id: pipelineHeaderFailed.data.project.pipeline.id,
        });
        expect(findAlert().exists()).toBe(false);
      });

      it('should render retry action tooltip', () => {
        expect(findRetryButton().attributes('title')).toBe(BUTTON_TOOLTIP_RETRY);
      });
    });

    describe('retry action failed', () => {
      beforeEach(async () => {
        createComponent([
          [getPipelineDetailsQuery, failedHandler],
          [retryPipelineMutation, retryMutationHandlerFailed],
        ]);

        await waitForPromises();
      });

      it('should display error message on failure', async () => {
        findRetryButton().vm.$emit('click');

        await waitForPromises();

        expect(findAlert().exists()).toBe(true);
      });

      it('retry button loading state should reset on error', async () => {
        findRetryButton().vm.$emit('click');

        await nextTick();

        expect(findRetryButton().props('loading')).toBe(true);

        await waitForPromises();

        expect(findRetryButton().props('loading')).toBe(false);
      });
    });

    describe('cancel action', () => {
      it('should call cancelPipeline Mutation with pipeline id', async () => {
        createComponent([
          [getPipelineDetailsQuery, runningHandler],
          [cancelPipelineMutation, cancelMutationHandlerSuccess],
        ]);

        await waitForPromises();

        findCancelButton().vm.$emit('click');

        expect(cancelMutationHandlerSuccess).toHaveBeenCalledWith({
          id: pipelineHeaderRunning.data.project.pipeline.id,
        });
        expect(findAlert().exists()).toBe(false);
      });

      it('should render cancel action tooltip', async () => {
        createComponent([
          [getPipelineDetailsQuery, runningHandler],
          [cancelPipelineMutation, cancelMutationHandlerSuccess],
        ]);

        await waitForPromises();

        expect(findCancelButton().attributes('title')).toBe(BUTTON_TOOLTIP_CANCEL);
      });

      it('should display error message on failure', async () => {
        createComponent([
          [getPipelineDetailsQuery, runningHandler],
          [cancelPipelineMutation, cancelMutationHandlerFailed],
        ]);

        await waitForPromises();

        findCancelButton().vm.$emit('click');

        await waitForPromises();

        expect(findAlert().exists()).toBe(true);
      });
    });

    describe('delete action', () => {
      it('displays delete modal when clicking on delete and does not call the delete action', async () => {
        createComponent([
          [getPipelineDetailsQuery, successHandler],
          [deletePipelineMutation, deleteMutationHandlerSuccess],
        ]);

        await waitForPromises();

        findDeleteButton().vm.$emit('click');

        const modalId = 'pipeline-delete-modal';

        expect(findDeleteModal().props('modalId')).toBe(modalId);
        expect(glModalDirective).toHaveBeenCalledWith(modalId);
        expect(deleteMutationHandlerSuccess).not.toHaveBeenCalled();
        expect(findAlert().exists()).toBe(false);
      });

      it('should call deletePipeline Mutation with pipeline id when modal is submitted', async () => {
        createComponent([
          [getPipelineDetailsQuery, successHandler],
          [deletePipelineMutation, deleteMutationHandlerSuccess],
        ]);

        await waitForPromises();

        findDeleteModal().vm.$emit('primary');

        expect(deleteMutationHandlerSuccess).toHaveBeenCalledWith({
          id: pipelineHeaderSuccess.data.project.pipeline.id,
        });
      });

      it('should display error message on failure', async () => {
        createComponent([
          [getPipelineDetailsQuery, successHandler],
          [deletePipelineMutation, deleteMutationHandlerFailed],
        ]);

        await waitForPromises();

        findDeleteModal().vm.$emit('primary');

        await waitForPromises();

        expect(findAlert().exists()).toBe(true);
      });
    });
  });
});
