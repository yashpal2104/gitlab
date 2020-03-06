# frozen_string_literal: true

RSpec.shared_examples 'publish incidents' do
  let(:status_page_setting_enabled) { true }
  let(:storage_client) { instance_double(StatusPage::Storage::S3Client) }
  let(:serializer) { instance_double(StatusPage::IncidentSerializer) }
  let(:content_json) { content.to_json }

  let(:status_page_setting) do
    instance_double(StatusPageSetting, enabled?: status_page_setting_enabled,
                    storage_client: storage_client)
  end

  before do
    stub_licensed_features(status_page: true)

    allow(project).to receive(:status_page_setting)
      .and_return(status_page_setting)
    allow(StatusPage::IncidentSerializer).to receive(:new)
      .and_return(serializer)
  end

  shared_examples 'feature is not available' do
  end

  context 'when upload succeeds' do
    before do
      allow(storage_client).to receive(:upload_object).with(key, content_json)
    end

    it 'publishes details as JSON' do
      expect(result).to be_success
      expect(result.payload).to eq(object_key: key)
    end
  end

  context 'when upload fails due to exception' do
    let(:bucket) { 'bucket_name' }
    let(:error) { StandardError.new }

    let(:exception) do
      StatusPage::Storage::Error.new(bucket: bucket, error: error)
    end

    before do
      allow(storage_client).to receive(:upload_object).with(key, content_json)
        .and_raise(exception)
    end

    it 'returns an error with exception' do
      expect(result).to be_error
      expect(result.message).to eq(exception.message)
      expect(result.payload).to eq(error: exception)
    end
  end

  context 'when limits exceeded' do
    let(:too_big) { 'a' * StatusPage::Storage::JSON_MAX_SIZE }

    before do
      if content.is_a?(Array)
        content.concat([too_big: too_big])
      else
        content.merge!(too_big: too_big)
      end
    end

    it 'returns limit exceeded error' do
      expect(result).to be_error
      expect(result.message).to eq(
        "Failed to upload #{key}: Limit exceeded"
      )
    end
  end

  context 'when status page setting is not enabled' do
    let(:status_page_setting_enabled) { false }

    it 'returns feature not available error' do
      expect(result).to be_error
      expect(result.message).to eq('Feature not available')
    end
  end
end
