# -*- coding: utf-8 -*-

require_relative "../spec_helper"

describe Mogrin do
  it do
    object = Mogrin::Core.new
    object.servers.should == [{:host => "localhost"}]
    object.urls.should == [{:url => "http://localhost/"}, {:url => "http://www.google.co.jp/"}]
  end
end
