shared_examples "unauthenticated user" do
  describe '#log_in' do
    it 'should raise AuthError' do
      expect { subject.log_in }.to raise_error(Minisky::AuthError)
    end
  end
end
