require 'spec_helper'

describe WordPress do

  subject do
    $wp
  end

  context "#new_post" do

    subject do
      $wp.new_post({ :post_title => "Inital Post Title", :post_name => 'inital-post-title' })
    end

    its :class do
      should be WordPress::Post
    end

  end

  context "#query" do

    it "does query by :post_type" do
      subject.query( :post_type => 'post' ).count.should == 1
    end

    it "does query by :page_id" do
      subject.query( :page_id => 2 ).count.should == 1
    end

    it "does query by :pagename" do
      subject.query( :pagename => 'sample-page' ).count.should == 1
    end

    it "does query by :p" do
      subject.query( :p => 1 ).count.should == 1
    end

    it "does query by :post__in" do
      subject.query( :post__in => [1] ).count.should == 1
    end

    it "does query by :post__not_in" do
      subject.query( :post__not_in => [1] ).count.should == 0
    end

    context "meta queries" do

      before :each do
        @new_post = $wp.new_post({ :post_title => "Test meta post", :post_name => "test-meta-post", :post_status => 'publish' } )
        @new_post.save!

        @new_post_2 = $wp.new_post({ :post_title => "Test 2", :post_name => "test-2", :post_status => 'publish' } )
        @new_post_2.save!
      end

      it "does query by simple meta comparison" do
        @new_post.post_meta['hello'] = 'there'
        subject.query( :meta_query => [ { :key => 'hello', :value => 'there' } ] ).first.should == @new_post
      end

      it "does query by multiple meta comparison" do
        @new_post.post_meta['hello'] = 'there'
        @new_post.post_meta['goodbye'] = 'moon'
        @new_post_2.post_meta['goodbye'] = 'moon'

        subject.query( :meta_query => [ { :key => 'hello', :value => 'there' }, { :key => 'goodbye', :value => 'moon' } ] ).first.should == @new_post
      end

      it "does query by LIKE comparison" do
        @new_post.post_meta['hello'] = 'there'
        subject.query( :meta_query => [ { :key => 'hello', :value => 'the%', :compare => 'LIKE' } ] ).first.should == @new_post
      end

      it "does query by NOT LIKE comparison" do
        @new_post.post_meta['hello'] = 'there'
        subject.query( :meta_query => [ { :key => 'hello', :value => 'the%', :compare => 'NOT LIKE' } ] ).first.should == nil
      end

      it "does query by BETWEEN using a range" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => (5..15), :compare => 'BETWEEN' } ] ).first.should == @new_post
      end

      it "does query by BETWEEN using an array" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => [5, 15], :compare => 'BETWEEN' } ] ).first.should == @new_post
      end

      it "does query by NOT BETWEEN using a range" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => (5..15), :compare => 'NOT BETWEEN' } ] ).first.should == @new_post_2
      end

      it "does query by NOT BETWEEN using an array" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => [5, 15], :compare => 'NOT BETWEEN' } ] ).first.should == @new_post_2
      end

      it "does query by IN using a range" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => (5..15), :compare => 'IN' } ] ).first.should == @new_post
      end

      it "does query by IN using an array" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => [9, 10, 11], :compare => 'IN' } ] ).first.should == @new_post
      end

      it "does query by NOT IN using a range" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => (5..15), :compare => 'NOT IN' } ] ).first.should == @new_post_2
      end

      it "does query by NOT IN using an array" do
        @new_post.post_meta['hello'] = 10
        @new_post_2.post_meta['hello'] = 20
        subject.query( :meta_query => [ { :key => 'hello', :value => [9, 10, 11], :compare => 'NOT IN' } ] ).first.should == @new_post_2
      end

    end

  end

end
