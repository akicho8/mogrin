require "spec_helper"

describe Mogrin do
  let(:instance){Mogrin::Core.new([], :dry_run => true)}
  it{ instance.hosts.should == [] }
  it{ instance.urls.should == []}
end
