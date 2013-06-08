require 'spec_helper'

describe WordPress::Options do

  subject do
    $wp.options
  end

  it "should be the correct class" do
    subject.class.should == WordPress::Options
  end

  it "should store a value" do
    subject['hello'] = 'there'
    subject['hello'].should == 'there'
  end

  it "should have the correct inital DB version" do
    subject['initial_db_version'].should == '22441'
  end

  it "should correctly handle an array" do
    the_array = [ 1, 2, 'hello' ]
    subject['hello'] = the_array
    subject['hello'].should == the_array
  end

  it "should correctly handle a hash" do
    the_hash = { 'hello' => 'world', 'goodbye' => 'moon' }
    subject['hello'] = the_hash
    subject['hello'].should == the_hash
  end

end
