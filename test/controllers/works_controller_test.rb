require "test_helper"

describe WorksController do
  let(:existing_work) { works(:album) }
  
  describe "root" do
    it "succeeds with all media types" do
      get root_path
      
      must_respond_with :success
    end
    
    it "succeeds with one media type absent" do
      only_book = works(:poodr)
      only_book.destroy
      
      get root_path
      
      must_respond_with :success
    end
    
    it "succeeds with no media" do
      Work.all do |work|
        work.destroy
      end
      
      get root_path
      
      must_respond_with :success
    end
  end
  
  describe "guest user functionality" do
    describe "index" do
      it "redirects to the root path with an error message" do
        get works_path
        
        must_redirect_to root_path
        expect(flash[:status]).must_equal :failure
        expect(flash[:result_text]).must_equal "You must log in to view this page"
      end
    end
    
    describe "show" do
      it "redirects to the root path with an error message for an extant work" do
        get work_path(existing_work.id)
        
        must_redirect_to root_path
        expect(flash[:status]).must_equal :failure
        expect(flash[:result_text]).must_equal "You must log in to view this page"
      end
      
      it "renders 404 not_found for a bogus work ID" do
        destroyed_id = existing_work.id
        existing_work.destroy
        
        get work_path(destroyed_id)
        
        must_respond_with :not_found
      end
    end
  end
  
  describe "logged in user functionality" do
    before do
      perform_login(users(:dan))
    end
    
    CATEGORIES = %w(albums books movies)
    INVALID_CATEGORIES = ["nope", "42", "", "  ", "albumstrailingtext"]
    
    describe "index" do
      it "succeeds when there are works" do
        get works_path
        
        must_respond_with :success
      end
      
      it "succeeds when there are no works" do
        Work.all do |work|
          work.destroy
        end
        
        get works_path
        
        must_respond_with :success
      end
    end
    
    describe "new" do
      it "succeeds" do
        get new_work_path
        
        must_respond_with :success
      end
    end
    
    describe "create" do
      it "creates a work with valid data for a real category" do
        new_work = { work: { title: "Dirty Computer", category: "album" } }
        
        expect {
          post works_path, params: new_work
        }.must_change "Work.count", 1
        
        new_work_id = Work.find_by(title: "Dirty Computer").id
        
        must_respond_with :redirect
        must_redirect_to work_path(new_work_id)
      end
      
      it "renders bad_request and does not update the DB for bogus data" do
        bad_work = { work: { title: nil, category: "book" } }
        
        expect {
          post works_path, params: bad_work
        }.wont_change "Work.count"
        
        must_respond_with :bad_request
      end
      
      it "renders 400 bad_request for bogus categories" do
        INVALID_CATEGORIES.each do |category|
          invalid_work = { work: { title: "Invalid Work", category: category } }
          
          proc { post works_path, params: invalid_work }.wont_change "Work.count"
          
          Work.find_by(title: "Invalid Work", category: category).must_be_nil
          must_respond_with :bad_request
        end
      end
    end
    
    describe "show" do
      it "succeeds for an extant work ID" do
        get work_path(existing_work.id)
        
        must_respond_with :success
      end
      
      it "renders 404 not_found for a bogus work ID" do
        destroyed_id = existing_work.id
        existing_work.destroy
        
        get work_path(destroyed_id)
        
        must_respond_with :not_found
      end
    end
    
    describe "edit" do
      it "succeeds for an extant work ID" do
        get edit_work_path(existing_work.id)
        
        must_respond_with :success
      end
      
      it "renders 404 not_found for a bogus work ID" do
        bogus_id = existing_work.id
        existing_work.destroy
        
        get edit_work_path(bogus_id)
        
        must_respond_with :not_found
      end
    end
    
    describe "update" do
      it "succeeds for valid data and an extant work ID" do
        updates = { work: { title: "Dirty Computer" } }
        
        expect {
          put work_path(existing_work), params: updates
        }.wont_change "Work.count"
        updated_work = Work.find_by(id: existing_work.id)
        
        updated_work.title.must_equal "Dirty Computer"
        must_respond_with :redirect
        must_redirect_to work_path(existing_work.id)
      end
      
      it "renders bad_request for bogus data" do
        updates = { work: { title: nil } }
        
        expect {
          put work_path(existing_work), params: updates
        }.wont_change "Work.count"
        
        work = Work.find_by(id: existing_work.id)
        
        must_respond_with :not_found
      end
      
      it "renders 404 not_found for a bogus work ID" do
        bogus_id = existing_work.id
        existing_work.destroy
        
        put work_path(bogus_id), params: { work: { title: "Test Title" } }
        
        must_respond_with :not_found
      end
    end
    
    describe "destroy" do
      it "succeeds for an extant work ID" do
        expect {
          delete work_path(existing_work.id)
        }.must_change "Work.count", -1
        
        must_respond_with :redirect
        must_redirect_to root_path
      end
      
      it "renders 404 not_found and does not update the DB for a bogus work ID" do
        bogus_id = existing_work.id
        existing_work.destroy
        
        expect {
          delete work_path(bogus_id)
        }.wont_change "Work.count"
        
        must_respond_with :not_found
      end
    end
  end
  
  describe "upvote" do
    let(:work_id) {
      works(:poodr).id
    }
    
    it "redirects to the work page if no user is logged in" do
      expect {
        post upvote_path(work_id)
      }.wont_change "Vote.count"
      
      must_redirect_to work_path(work_id)
      expect(flash[:result_text]).must_equal "You must log in to do that"
    end
    
    it "redirects to the work page after the user has logged out" do
      user = users(:dan)
      perform_login(user)
      session[:user_id].must_equal user.id
      
      delete logout_path
      session[:user_id].must_be_nil
      
      expect {
        post upvote_path(work_id)
      }.wont_change "Vote.count"
      
      must_redirect_to work_path(work_id)
      expect(flash[:result_text]).must_equal "You must log in to do that"
    end
    
    it "succeeds for a logged-in user and a fresh user-vote pair" do
      user = users(:dan)
      perform_login(user)
      session[:user_id].must_equal user.id
      
      expect {
        post upvote_path(work_id)
      }.must_change "Vote.count", 1
      
      expect(flash[:status]).must_equal :success
    end
    
    it "redirects to the work page if the user has already voted for that work" do
      user = users(:dan)
      perform_login(user)
      session[:user_id].must_equal user.id
      
      post upvote_path(work_id)
      
      expect {
        post upvote_path(work_id)
      }.wont_change "Vote.count"
      
      expect(flash[:result_text]).must_equal "Could not upvote"
      must_redirect_to work_path(work_id)
    end
  end
end
