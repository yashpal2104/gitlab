# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::SecureFiles::P12 do
  context 'when the supplied certificate cannot be parsed' do
    let(:invalid_certificate) { described_class.new('xyzabc') }
    let(:subject) { described_class.new('xyzabc') }

    describe '#certificate_data' do
      it 'assigns the error message and returns nil' do
        expect(invalid_certificate.certificate_data).to be nil
        expect(invalid_certificate.error).to eq('PKCS12_parse: mac verify failure')
      end
    end

    describe '#metadata' do
      it 'returns an empty hash' do
        expect(invalid_certificate.metadata).to eq({})
      end
    end

    describe '#expires_at' do
      it 'returns nil' do
        expect(invalid_certificate.expires_at).to be_nil
      end
    end
  end

  context 'when the supplied certificate can be parsed' do
    let(:sample_file) { fixture_file('ci_secure_files/sample.p12') }
    let(:subject) { described_class.new(sample_file) }

    describe '#certificate_data' do
      it 'returns an OpenSSL::X509::Certificate object' do
        expect(subject.certificate_data.class).to be(OpenSSL::X509::Certificate)
      end
    end

    describe '#metadata' do
      it 'returns a hash with the expected keys' do
        expect(subject.metadata.keys).to match_array([:issuer, :subject, :id, :expires_at])
      end
    end

    describe '#id' do
      it 'returns the certificate serial number' do
        expect(subject.metadata[:id]).to eq('75949910542696343243264405377658443914')
      end
    end

    describe '#expires_at' do
      it 'returns the certificate expiration timestamp' do
        expect(subject.expires_at).to eq('2022-09-21 14:56:00 UTC')
      end
    end

    describe '#issuer' do
      it 'calls parse on X509Name' do
        expect(subject.metadata[:issuer]["O"]).to eq('Apple Inc.')
      end
    end

    describe '#subject' do
      it 'calls parse on X509Name' do
        expect(subject.metadata[:subject]["OU"]).to eq('N7SYAN8PX8')
      end
    end
  end
end
