require "spec_helper"
require "bbbevents"

RSpec.describe BBBEvents::Poll do
  before(:all) do
    @sample = BBBEvents.parse(file_fixture("new-events-2_5.xml"))
    @poll = @sample.polls.first
  end

  context "#id" do
    it "should properly parse id." do
      expect(@poll.id).to eq("4273443ce696f01108e3addc86386d73329b8d98-1684351990846/1/1684352053505")
    end
  end

  context "#options" do
    it "should properly parse options." do
      expect(@poll.options).to be_a(Array)
      expect(@poll.options.empty?).to be false
    end
  end

  context "#votes" do
    it "should properly record votes." do
      expect(@poll.votes).to be_a(Hash)
      expect(@poll.votes.empty?).to be false
    end
  end

  context "#published?" do
    it "has published? alias." do
      expect(@poll).to respond_to(:published?)
    end
  end
end
