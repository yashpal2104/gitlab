# frozen_string_literal: true

RSpec.describe CsvBuilder do
  let(:object) { double(question: :answer) }
  let(:csv_data) { subject.render }

  let(:subject) do
    described_class.new(
      enumerable, 'Q & A' => :question, 'Reversed' => ->(o) { o.question.to_s.reverse })
  end

  shared_examples 'csv builder examples' do
    let(:items) { [object] }

    it "has a version number" do
      expect(CsvBuilder::Version::VERSION).not_to be nil
    end

    it 'generates a csv' do
      expect(csv_data.scan(/(,|\n)/).join).to include ",\n,"
    end

    it 'uses a temporary file to reduce memory allocation' do
      expect(CSV).to receive(:new).with(instance_of(Tempfile)).and_call_original

      subject.render
    end

    it 'counts the number of rows' do
      subject.render

      expect(subject.rows_written).to eq 1
    end

    describe 'rows_expected' do
      it 'uses rows_written if CSV rendered successfully' do
        subject.render

        expect(enumerable).not_to receive(:count)
        expect(subject.rows_expected).to eq 1
      end

      it 'falls back to calling .count before rendering begins' do
        expect(subject.rows_expected).to eq 1
      end
    end

    describe 'truncation' do
      let(:big_object) { double(question: 'Long' * 1024) }
      let(:row_size) { big_object.question.length * 2 }
      let(:items) { [big_object, big_object, big_object] }

      it 'occurs after given number of bytes' do
        expect(subject.render(row_size * 2).length).to be_between(row_size * 2, row_size * 3)
        expect(subject).to be_truncated
        expect(subject.rows_written).to eq 2
      end

      it 'is ignored by default' do
        expect(subject.render.length).to be > row_size * 3
        expect(subject.rows_written).to eq 3
      end

      it 'causes rows_expected to fall back to .count' do
        subject.render(0)

        expect(enumerable).to receive(:count).and_call_original
        expect(subject.rows_expected).to eq 3
      end
    end

    it 'avoids loading all data in a single query' do
      expect(enumerable).to receive(:find_each)

      subject.render
    end

    it 'uses hash keys as headers' do
      expect(csv_data).to start_with 'Q & A'
    end

    it 'gets data by calling method provided as hash value' do
      expect(csv_data).to include 'answer'
    end

    it 'allows lamdas to look up more complicated data' do
      expect(csv_data).to include 'rewsna'
    end

    describe 'excel sanitization' do
      let(:dangerous_title) { double(title: "=cmd|' /C calc'!A0 title", description: "*safe_desc") }
      let(:dangerous_desc) { double(title: "*safe_title", description: "=cmd|' /C calc'!A0 desc") }
      let(:items) { [dangerous_title, dangerous_desc] }
      let(:subject) { described_class.new(enumerable, 'Title' => 'title', 'Description' => 'description') }
      let(:csv_data) { subject.render }

      it 'sanitizes dangerous characters at the beginning of a column' do
        expect(csv_data).to include "'=cmd|' /C calc'!A0 title"
        expect(csv_data).to include "'=cmd|' /C calc'!A0 desc"
      end

      it 'does not sanitize safe symbols at the beginning of a column' do
        expect(csv_data).not_to include "'*safe_desc"
        expect(csv_data).not_to include "'*safe_title"
      end

      context 'when dangerous characters are after a line break' do
        let(:items) { [double(title: "Safe title", description: "With task list\n-[x] todo 1")] }

        it 'does not append single quote to description' do
          builder = described_class.new(enumerable, 'Title' => 'title', 'Description' => 'description')

          csv_data = builder.render

          expect(csv_data).to eq("Title,Description\nSafe title,\"With task list\n-[x] todo 1\"\n")
        end
      end
    end
  end

  context 'when ActiveRecord::Relation like object is given' do
    let(:enumerable) { described_class::FakeRelation.new(items) }

    before do
      stub_const("#{described_class}::FakeRelation", Array)

      described_class::FakeRelation.class_eval do
        def find_each(&block)
          each(&block)
        end
      end
    end

    it_behaves_like 'csv builder examples'
  end

  context 'when Enumerable like object is given' do
    let(:enumerable) { items }

    it_behaves_like 'csv builder examples'
  end
end
