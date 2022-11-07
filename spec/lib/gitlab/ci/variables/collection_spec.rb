# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Variables::Collection do
  describe '.new' do
    it 'can be initialized with an array' do
      variable = { key: 'VAR', value: 'value', public: true, masked: false }

      collection = described_class.new([variable])

      expect(collection.first.to_runner_variable).to eq variable
    end

    it 'can be initialized without an argument' do
      is_expected.to be_none
    end
  end

  describe '#append' do
    it 'appends a hash' do
      subject.append(key: 'VARIABLE', value: 'something')

      is_expected.to be_one
    end

    it 'appends a Ci::Variable' do
      subject.append(build(:ci_variable))

      is_expected.to be_one
    end

    it 'appends an internal resource' do
      collection = described_class.new([{ key: 'TEST', value: '1' }])

      subject.append(collection.first)

      is_expected.to be_one
    end

    it 'returns self' do
      expect(subject.append(key: 'VAR', value: 'test'))
        .to eq subject
    end
  end

  describe '#compact' do
    subject do
      described_class.new
        .append(key: 'STRING', value: 'string')
        .append(key: 'NIL', value: nil)
        .append(key: nil, value: 'string')
    end

    it 'returns a new Collection instance', :aggregate_failures do
      collection = subject.compact

      expect(collection).to be_an_instance_of(described_class)
      expect(collection).not_to eql(subject)
    end

    it 'rejects pair that has nil value', :aggregate_failures do
      collection = subject.compact

      expect(collection).not_to include(key: 'NIL', value: nil, public: true)
      expect(collection).to include(key: 'STRING', value: 'string', public: true)
      expect(collection).to include(key: nil, value: 'string', public: true)
    end
  end

  describe '#concat' do
    it 'appends all elements from an array' do
      collection = described_class.new([{ key: 'VAR_1', value: '1' }])
      variables = [{ key: 'VAR_2', value: '2' }, { key: 'VAR_3', value: '3' }]

      collection.concat(variables)

      expect(collection).to include(key: 'VAR_1', value: '1', public: true)
      expect(collection).to include(key: 'VAR_2', value: '2', public: true)
      expect(collection).to include(key: 'VAR_3', value: '3', public: true)
    end

    it 'appends all elements from other collection' do
      collection = described_class.new([{ key: 'VAR_1', value: '1' }])
      additional = described_class.new([{ key: 'VAR_2', value: '2' },
                                        { key: 'VAR_3', value: '3' }])

      collection.concat(additional)

      expect(collection).to include(key: 'VAR_1', value: '1', public: true)
      expect(collection).to include(key: 'VAR_2', value: '2', public: true)
      expect(collection).to include(key: 'VAR_3', value: '3', public: true)
    end

    it 'does not concatenate resource if it undefined' do
      collection = described_class.new([{ key: 'VAR_1', value: '1' }])

      collection.concat(nil)

      expect(collection).to be_one
    end

    it 'returns self' do
      expect(subject.concat([key: 'VAR', value: 'test']))
        .to eq subject
    end
  end

  describe '#+' do
    it 'makes it possible to combine with an array' do
      collection = described_class.new([{ key: 'TEST', value: '1' }])
      variables = [{ key: 'TEST', value: 'something' }]

      expect((collection + variables).count).to eq 2
    end

    it 'makes it possible to combine with another collection' do
      collection = described_class.new([{ key: 'TEST', value: '1' }])
      other = described_class.new([{ key: 'TEST', value: '2' }])

      expect((collection + other).count).to eq 2
    end
  end

  describe '#[]' do
    subject { Gitlab::Ci::Variables::Collection.new(variables)[var_name] }

    shared_examples 'an array access operator' do
      context 'for a non-existent variable name' do
        let(:var_name) { 'UNKNOWN_VAR' }

        it 'returns nil' do
          is_expected.to be_nil
        end
      end

      context 'for an existent variable name' do
        let(:var_name) { 'VAR' }

        it 'returns the last Item' do
          is_expected.to be_an_instance_of(Gitlab::Ci::Variables::Collection::Item)
          expect(subject.to_runner_variable).to eq(variables.last)
        end
      end
    end

    context 'with variable key with single entry' do
      let(:variables) do
        [
          { key: 'VAR', value: 'value', public: true, masked: false }
        ]
      end

      it_behaves_like 'an array access operator'
    end

    context 'with variable key with multiple entries' do
      let(:variables) do
        [
          { key: 'VAR', value: 'value', public: true, masked: false },
          { key: 'VAR', value: 'override value', public: true, masked: false }
        ]
      end

      it_behaves_like 'an array access operator'
    end
  end

  describe '#all' do
    subject { described_class.new(variables).all(var_name) }

    shared_examples 'a method returning all known variables or nil' do
      context 'for a non-existent variable name' do
        let(:var_name) { 'UNKNOWN_VAR' }

        it 'returns nil' do
          is_expected.to be_nil
        end
      end

      context 'for an existing variable name' do
        let(:var_name) { 'VAR' }

        it 'returns all expected Items' do
          is_expected.to eq(expected_variables.map { |v| Gitlab::Ci::Variables::Collection::Item.fabricate(v) })
        end
      end
    end

    context 'with variable key with single entry' do
      let(:variables) do
        [
          { key: 'VAR', value: 'value', public: true, masked: false }
        ]
      end

      it_behaves_like 'a method returning all known variables or nil' do
        let(:expected_variables) do
          [
            { key: 'VAR', value: 'value', public: true, masked: false }
          ]
        end
      end
    end

    context 'with variable key with multiple entries' do
      let(:variables) do
        [
          { key: 'VAR', value: 'value', public: true, masked: false },
          { key: 'VAR', value: 'override value', public: true, masked: false }
        ]
      end

      it_behaves_like 'a method returning all known variables or nil' do
        let(:expected_variables) do
          [
            { key: 'VAR', value: 'value', public: true, masked: false },
            { key: 'VAR', value: 'override value', public: true, masked: false }
          ]
        end
      end
    end
  end

  describe '#size' do
    it 'returns zero for empty collection' do
      collection = described_class.new([])

      expect(collection.size).to eq(0)
    end

    it 'returns 2 for collection with 2 variables' do
      collection = described_class.new(
        [
          { key: 'VAR1', value: 'value', public: true, masked: false },
          { key: 'VAR2', value: 'value', public: true, masked: false }
        ])

      expect(collection.size).to eq(2)
    end

    it 'returns 3 for collection with 2 duplicate variables' do
      collection = described_class.new(
        [
          { key: 'VAR1', value: 'value', public: true, masked: false },
          { key: 'VAR2', value: 'value', public: true, masked: false },
          { key: 'VAR1', value: 'value', public: true, masked: false }
        ])

      expect(collection.size).to eq(3)
    end
  end

  describe '#to_runner_variables' do
    it 'creates an array of hashes in a runner-compatible format' do
      collection = described_class.new([{ key: 'TEST', value: '1' }])

      expect(collection.to_runner_variables)
        .to eq [{ key: 'TEST', value: '1', public: true, masked: false }]
    end
  end

  describe '#to_hash' do
    it 'returns regular hash in valid order without duplicates' do
      collection = described_class.new
        .append(key: 'TEST1', value: 'test-1')
        .append(key: 'TEST2', value: 'test-2')
        .append(key: 'TEST1', value: 'test-3')

      expect(collection.to_hash).to eq('TEST1' => 'test-3',
                                       'TEST2' => 'test-2')

      expect(collection.to_hash).to include(TEST1: 'test-3')
      expect(collection.to_hash).not_to include(TEST1: 'test-1')
    end
  end

  describe '#reject' do
    let(:collection) do
      described_class.new
        .append(key: 'CI_JOB_NAME', value: 'test-1')
        .append(key: 'CI_BUILD_ID', value: '1')
        .append(key: 'TEST1', value: 'test-3')
    end

    subject { collection.reject { |var| var[:key] =~ /\ACI_(JOB|BUILD)/ } }

    it 'returns a Collection instance' do
      is_expected.to be_an_instance_of(described_class)
    end

    it 'returns correctly filtered Collection' do
      comp = collection.to_runner_variables.reject { |var| var[:key] =~ /\ACI_(JOB|BUILD)/ }
      expect(subject.to_runner_variables).to eq(comp)
    end
  end

  describe '#expand_value' do
    let(:collection) do
      Gitlab::Ci::Variables::Collection.new
                     .append(key: 'CI_JOB_NAME', value: 'test-1')
                     .append(key: 'CI_BUILD_ID', value: '1')
                     .append(key: 'TEST1', value: 'test-3')
                     .append(key: 'FILEVAR1', value: 'file value 1', file: true)
    end

    context 'table tests' do
      using RSpec::Parameterized::TableSyntax

      where do
        {
          "empty value": {
            value: '',
            result: ''
          },
          "simple expansions": {
            value: 'key$TEST1-$CI_BUILD_ID',
            result: 'keytest-3-1'
          },
          "complex expansion": {
            value: 'key${TEST1}-${CI_JOB_NAME}',
            result: 'keytest-3-test-1'
          },
          "missing variable not keeping original": {
            value: 'key${MISSING_VAR}-${CI_JOB_NAME}',
            result: 'key-test-1'
          },
          "missing variable keeping original": {
            value: 'key${MISSING_VAR}-${CI_JOB_NAME}',
            result: 'key${MISSING_VAR}-test-1',
            keep_undefined: true
          },
          "escaped characters are kept intact": {
            value: 'key-$TEST1-%%HOME%%-$${HOME}',
            result: 'key-test-3-%%HOME%%-$${HOME}'
          },
          "file variable with expand_file_refs: true": {
            value: 'key-$FILEVAR1-$TEST1',
            result: 'key-file value 1-test-3'
          },
          "file variable with expand_file_refs: false": {
            value: 'key-$FILEVAR1-$TEST1',
            result: 'key-$FILEVAR1-test-3',
            expand_file_refs: false
          }
        }
      end

      with_them do
        let(:options) { { keep_undefined: keep_undefined, expand_file_refs: expand_file_refs }.compact }

        subject(:expanded_result) { collection.expand_value(value, **options) }

        it 'matches expected expansion' do
          is_expected.to eq(result)
        end
      end
    end
  end

  describe '#sort_and_expand_all' do
    context 'table tests' do
      using RSpec::Parameterized::TableSyntax

      where do
        {
          "empty array": {
            variables: [],
            keep_undefined: false,
            result: []
          },
          "simple expansions": {
            variables: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result' },
              { key: 'variable3', value: 'key$variable$variable2' },
              { key: 'variable4', value: 'key$variable$variable3' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result' },
              { key: 'variable3', value: 'keyvalueresult' },
              { key: 'variable4', value: 'keyvaluekeyvalueresult' }
            ]
          },
          "complex expansion": {
            variables: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'key${variable}' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'keyvalue' }
            ]
          },
          "unused variables": {
            variables: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result2' },
              { key: 'variable3', value: 'result3' },
              { key: 'variable4', value: 'key$variable$variable3' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result2' },
              { key: 'variable3', value: 'result3' },
              { key: 'variable4', value: 'keyvalueresult3' }
            ]
          },
          "complex expansions": {
            variables: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result' },
              { key: 'variable3', value: 'key${variable}${variable2}' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result' },
              { key: 'variable3', value: 'keyvalueresult' }
            ]
          },
          "escaped characters in complex expansions keeping undefined are kept intact": {
            variables: [
              { key: 'variable3', value: 'key_${variable}_$${HOME}_%%HOME%%' },
              { key: 'variable', value: '$variable2' },
              { key: 'variable2', value: 'value' }
            ],
            keep_undefined: true,
            result: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'value' },
              { key: 'variable3', value: 'key_value_$${HOME}_%%HOME%%' }
            ]
          },
          "escaped characters in complex expansions discarding undefined are kept intact": {
            variables: [
              { key: 'variable2', value: 'key_${variable4}_$${HOME}_%%HOME%%' },
              { key: 'variable', value: 'value_$${HOME}_%%HOME%%' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable', value: 'value_$${HOME}_%%HOME%%' },
              { key: 'variable2', value: 'key__$${HOME}_%%HOME%%' }
            ]
          },
          "out-of-order expansion": {
            variables: [
              { key: 'variable3', value: 'key$variable2$variable' },
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable2', value: 'result' },
              { key: 'variable', value: 'value' },
              { key: 'variable3', value: 'keyresultvalue' }
            ]
          },
          "out-of-order complex expansion": {
            variables: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result' },
              { key: 'variable3', value: 'key${variable2}${variable}' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable', value: 'value' },
              { key: 'variable2', value: 'result' },
              { key: 'variable3', value: 'keyresultvalue' }
            ]
          },
          "missing variable discarding original": {
            variables: [
              { key: 'variable2', value: 'key$variable' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable2', value: 'key' }
            ]
          },
          "missing variable keeping original": {
            variables: [
              { key: 'variable2', value: 'key$variable' }
            ],
            keep_undefined: true,
            result: [
              { key: 'variable2', value: 'key$variable' }
            ]
          },
          "complex expansions with missing variable keeping original": {
            variables: [
              { key: 'variable4', value: 'key${variable}${variable2}${variable3}' },
              { key: 'variable', value: 'value' },
              { key: 'variable3', value: 'value3' }
            ],
            keep_undefined: true,
            result: [
              { key: 'variable', value: 'value' },
              { key: 'variable3', value: 'value3' },
              { key: 'variable4', value: 'keyvalue${variable2}value3' }
            ]
          },
          "complex expansions with raw variable with expand_raw_refs: true (default)": {
            variables: [
              { key: 'variable1', value: 'value1' },
              { key: 'raw_var', value: 'raw-$variable1', raw: true },
              { key: 'nonraw_var', value: 'nonraw-$variable1' },
              { key: 'variable2', value: '$raw_var and $nonraw_var' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable1', value: 'value1' },
              { key: 'raw_var', value: 'raw-$variable1', raw: true },
              { key: 'nonraw_var', value: 'nonraw-value1' },
              { key: 'variable2', value: 'raw-$variable1 and nonraw-value1' }
            ]
          },
          "complex expansions with raw variable with expand_raw_refs: false": {
            variables: [
              { key: 'variable1', value: 'value1' },
              { key: 'raw_var', value: 'raw-$variable1', raw: true },
              { key: 'nonraw_var', value: 'nonraw-$variable1' },
              { key: 'variable2', value: '$raw_var and $nonraw_var' }
            ],
            keep_undefined: false,
            expand_raw_refs: false,
            result: [
              { key: 'variable1', value: 'value1' },
              { key: 'raw_var', value: 'raw-$variable1', raw: true },
              { key: 'nonraw_var', value: 'nonraw-value1' },
              { key: 'variable2', value: '$raw_var and nonraw-value1' }
            ]
          },
          "variable value referencing password with special characters": {
            variables: [
              { key: 'VAR', value: '$PASSWORD' },
              { key: 'PASSWORD', value: 'my_password$$_%%_$A' },
              { key: 'A', value: 'value' }
            ],
            keep_undefined: false,
            result: [
              { key: 'VAR', value: 'my_password$$_%%_value' },
              { key: 'PASSWORD', value: 'my_password$$_%%_value' },
              { key: 'A', value: 'value' }
            ]
          },
          "cyclic dependency causes original array to be returned": {
            variables: [
              { key: 'variable', value: '$variable2' },
              { key: 'variable2', value: '$variable3' },
              { key: 'variable3', value: 'key$variable$variable2' }
            ],
            keep_undefined: false,
            result: [
              { key: 'variable', value: '$variable2' },
              { key: 'variable2', value: '$variable3' },
              { key: 'variable3', value: 'key$variable$variable2' }
            ]
          }
        }
      end

      with_them do
        let(:collection) { Gitlab::Ci::Variables::Collection.new(variables) }
        let(:options) { { keep_undefined: keep_undefined, expand_raw_refs: expand_raw_refs }.compact }

        subject(:expanded_result) { collection.sort_and_expand_all(**options) }

        it 'returns Collection' do
          is_expected.to be_an_instance_of(Gitlab::Ci::Variables::Collection)
        end

        it 'expands variables' do
          var_hash = result.to_h { |env| [env.fetch(:key), env.fetch(:value)] }
            .with_indifferent_access
          expect(subject.to_hash).to eq(var_hash)
        end

        it 'preserves raw attribute' do
          expect(subject.pluck(:key, :raw).to_h).to eq(collection.pluck(:key, :raw).to_h)
        end
      end
    end

    context 'with the file_variable_is_referenced_in_another_variable logging' do
      let(:collection) do
        Gitlab::Ci::Variables::Collection.new
                       .append(key: 'VAR1', value: 'test-1')
                       .append(key: 'VAR2', value: '$VAR1')
                       .append(key: 'VAR3', value: '$VAR1', raw: true)
                       .append(key: 'FILEVAR4', value: 'file-test-4', file: true)
                       .append(key: 'VAR5', value: '$FILEVAR4')
                       .append(key: 'VAR6', value: '$FILEVAR4', raw: true)
      end

      subject(:sort_and_expand_all) { collection.sort_and_expand_all(project: project) }

      context 'when a project is not passed' do
        let(:project) {}

        it 'does not log anything' do
          expect(Gitlab::AppJsonLogger).not_to receive(:info)

          sort_and_expand_all
        end
      end

      context 'when a project is passed' do
        let(:project) { create(:project) }

        it 'logs file_variable_is_referenced_in_another_variable once for VAR5' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            event: 'file_variable_is_referenced_in_another_variable',
            project_id: project.id,
            variable: 'FILEVAR4'
          ).once

          sort_and_expand_all
        end
      end
    end
  end
end
