require 'spec_helper'

describe WordPress::Post do

  subject { $wp.new_post({ :post_title => 'Sample Post', :post_name => 'sample-post-name' }) }

  its :class do
    should be WordPress::Post
  end

  its :post_title do
    should eq 'Sample Post'
  end

  its :post_name do
    should eq 'sample-post-name'
  end

  it "does save without errors" do
    subject.save!
  end

  context "post meta" do

    before :each do
      # Posts require to be saved before maniuplating post meta
      subject.save!
    end

    it "should store a value" do
      subject.post_meta['hello'] = 'there'
      subject.post_meta['hello'].should == 'there'
    end

    it "should correctly handle an array" do
      the_array = [ 1, 2, 'hello' ]
      subject.post_meta['hello'] = the_array
      subject.post_meta['hello'].should == the_array
    end

    it "should correctly handle a hash" do
      the_hash = { 'hello' => 'world', 'goodbye' => 'moon' }
      subject.post_meta['hello'] = the_hash
      subject.post_meta['hello'].should == the_hash
    end

  end

  context "taxonomies" do

    before :each do
      # Posts require to be saved before maniuplating taxonomies
      subject.save!
    end

    it "does start out with no categories" do
      subject.get_the_terms('category').should == []
    end

    it "does set a category" do
      subject.set_post_terms 'hello', 'category'
      subject.get_the_terms('category').should == ['hello']
    end

    it "does set multiple categories" do
      subject.set_post_terms ['hello', 'there'], 'category'
      subject.get_the_terms('category').sort.should == ['hello', 'there'].sort
    end

    it "does clear categories when given an empty array" do
      subject.set_post_terms 'hello', 'category'

      subject.set_post_terms [], 'category'
      subject.get_the_terms('category').should == []
    end

    it "does append categories" do
      subject.set_post_terms 'hello', 'category'
      subject.set_post_terms 'there', 'category', true
      subject.get_the_terms('category').sort.should == ['hello', 'there'].sort
    end

    it "does append multiple categories" do
      subject.set_post_terms 'hello', 'category'
      subject.set_post_terms ['there', 'goodbye'], 'category', true
      subject.get_the_terms('category').sort.should == ['hello', 'there', 'goodbye'].sort
    end

  end

end
