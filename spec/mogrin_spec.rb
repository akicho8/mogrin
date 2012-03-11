require "spec_helper"

describe Mogrin do
  let(:instance){Mogrin::Core.new}

  it{ instance.servers.should == [{:host => "localhost"}] }
  it{ instance.urls.should == [{:url => "http://localhost/"}, {:url => "http://www.google.co.jp/"}] }
end
