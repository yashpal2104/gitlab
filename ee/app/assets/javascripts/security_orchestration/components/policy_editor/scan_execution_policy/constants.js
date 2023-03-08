import { __, s__ } from '~/locale';

export const SCANNER_DAST = 'dast';
export const DEFAULT_AGENT_NAME = '';
export const AGENT_KEY = 'agents';

export const SCAN_EXECUTION_RULES_PIPELINE_KEY = 'pipeline';
export const SCAN_EXECUTION_RULES_SCHEDULE_KEY = 'schedule';

export const SCAN_EXECUTION_RULES_LABELS = {
  [SCAN_EXECUTION_RULES_PIPELINE_KEY]: s__('ScanExecutionPolicy|A pipeline is run'),
  [SCAN_EXECUTION_RULES_SCHEDULE_KEY]: s__('ScanExecutionPolicy|Schedule'),
};

export const ADD_CONDITION_LABEL = s__('ScanExecutionPolicy|Add condition');
export const CONDITIONS_LABEL = s__('ScanExecutionPolicy|Conditions');

export const SCAN_EXECUTION_PIPELINE_RULE = 'pipeline';
export const SCAN_EXECUTION_SCHEDULE_RULE = 'schedule';

export const SCAN_EXECUTION_RULE_SCOPE_TYPE = {
  branch: s__('ScanExecutionPolicy|branch'),
  agent: s__('ScanExecutionPolicy|agent'),
};

export const SCAN_EXECUTION_RULE_PERIOD_TYPE = {
  daily: __('daily'),
  weekly: __('weekly'),
};

export const DEFAULT_SCANNER = SCANNER_DAST;

export const SCANNER_HUMANIZED_TEMPLATE = s__(
  'ScanExecutionPolicy|%{thenLabelStart}Then%{thenLabelEnd} Require a %{scan} scan to run with tags %{tags}',
);

export const DAST_HUMANIZED_TEMPLATE = s__(
  'ScanExecutionPolicy|%{thenLabelStart}Then%{thenLabelEnd} Require a %{scan} scan to run with site profile %{siteProfile} and scanner profile %{scannerProfile} with tags %{tags}',
);
