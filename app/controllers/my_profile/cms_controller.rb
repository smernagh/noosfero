class CmsController < MyProfileController

  protect 'edit_profile', :profile, :only => [:set_home_page]

  include ArticleHelper
  include CategoriesHelper
  include SearchTags
  include Captcha

  def self.protect_if(*args)
    before_filter(*args) do |c|
      user, profile = c.send(:user), c.send(:profile)
      if yield(c, user, profile)
        true
      else
        access_denied = _("You do not have access to ")
        render_access_denied("#{access_denied}#{c.request.path_info}")
        false
      end
    end
  end

  before_filter :login_required, :except => [:suggest_an_article]
  before_filter :load_recent_files, :only => [:new, :edit]

  helper_method :file_types

  protect_if :except => [:suggest_an_article, :set_home_page, :edit, :destroy, :publish, :publish_on_portal_community, :publish_on_communities, :search_communities_to_publish, :upload_files, :new] do |c, user, profile|
    user && (user.has_permission?('post_content', profile) || user.has_permission?('publish_content', profile))
  end

  protect_if :only => [:new, :upload_files] do |c, user, profile|
    parent_id = c.params[:article].present? ? c.params[:article][:parent_id] : c.params[:parent_id]
    parent = profile.articles.find_by(id: parent_id)
    user && user.can_post_content?(profile, parent)
  end

  protect_if :only => :destroy do |c, user, profile|
    profile.articles.find(c.params[:id]).allow_post_content?(user)
  end

  protect_if :only => :edit do |c,user,profile|
    profile.articles.find(c.params[:id]).allow_edit?(user)
  end

  def boxes_holder
    profile
  end

  def view
    @article = profile.articles.find(params[:id])
    @articles = @article.children.reorder("case when type = 'Folder' then 0 when type ='Blog' then 1 else 2 end, updated_at DESC, name")
    @articles = @articles.where "type <> ?", 'RssFeed' if @article.has_posts?
    @articles = @articles.paginate per_page: per_page, page: params[:npage]
  end

  def index
    @article = nil
    @articles = profile.top_level_articles
      .order("case when type = 'Folder' then 0 when type ='Blog' then 1 else 2 end, updated_at DESC")
      .paginate(per_page: per_page, page: params[:npage])

    render :action => 'view'
  end

  def edit
    @success_back_to = params[:success_back_to]
    @article = profile.articles.find(params[:id])
    version = params[:version]
    @article.revert_to(version) if version

    @parent_id = params[:parent_id]
    @type = params[:type] || @article.class.to_s
    translations if @article.translatable?
    continue = params[:continue]

    @article.article_privacy_exceptions = params[:q].split(/,/).map{|n| environment.people.find n.to_i} unless params[:q].nil?

    @tokenized_children = prepare_to_token_input(
                            profile.members.includes(:articles_with_access).find_all{ |m|
                              m.articles_with_access.include?(@article)
                            }
                          )
    refuse_blocks
    record_coming
    if request.post?
      if @article.image.present? && params[:article][:image_builder] &&
        params[:article][:image_builder][:label]
        @article.image.label = params[:article][:image_builder][:label]
        @article.image.save!
      end
      params_metadata = params[:article].try(:delete, :metadata) || {}
      @article.metadata = @article.metadata.merge(params_metadata)
      @article.last_changed_by = user
      if @article.update(params[:article])
        if !continue
          if @article.content_type.nil? || @article.image?
            success_redirect
          else
            redirect_to :action => (@article.parent ? 'view' : 'index'), :id => @article.parent
          end
        end
      end
    end
  end

  def new
    # FIXME this method should share some logic with edit !!!

    @success_back_to = params[:success_back_to]
    # user must choose an article type first

    @parent = profile.articles.find(params[:parent_id]) if params && params[:parent_id].present?
    record_coming
    @type = params[:type]
    if @type.blank?
      @article_types = []
      available_article_types.each do |type|
        @article_types.push({
          :class => type,
          :short_description => type.short_description,
          :description => type.description
        })
      end
      @parent_id = params[:parent_id]
      render :action => 'select_article_type', :layout => false, :back_to => @back_to
      return
    else
      refuse_blocks
    end

    raise "Invalid article type #{@type}" unless valid_article_type?(@type)
    klass = @type.constantize
    article_data = environment.enabled?('articles_dont_accept_comments_by_default') ? { :accept_comments => false } : {}
    article_data.merge!(params[:article]) if params[:article]
    article_data.merge!(:profile => profile) if profile

    @article = if params[:clone]
      current_article = profile.articles.find(params[:id])
      current_article.copy_without_save
    else
      klass.new(article_data)
    end

    parent = check_parent(params[:parent_id])
    if parent
      @article.parent = parent
      @article.published = parent.published
      @article.show_to_followers = parent.show_to_followers
      @article.highlighted = parent.highlighted
      @parent_id = parent.id
    end

    @article.profile = profile
    @article.author = user
    @article.editor = current_person.editor
    @article.last_changed_by = user
    @article.created_by = user

    translations if @article.translatable?

    continue = params[:continue]
    if request.post?
      @article.article_privacy_exceptions = params[:q].split(/,/).map{|n| environment.people.find n.to_i} unless params[:q].nil?

      if @article.save
        if continue
          redirect_to :action => 'edit', :id => @article
        else
          respond_to do |format|
            format.html { success_redirect }
            format.json { render :text => {:id => @article.id, :full_name => profile.identifier + '/' + @article.full_name}.to_json }
          end
        end
        return
      end
    end
    render :action => 'edit'
  end

  post_only :set_home_page
  def set_home_page
    return render_access_denied unless user.can_change_homepage?

    article = params[:id].nil? ? nil : profile.articles.find(params[:id])
    profile.update_attribute(:home_page, article)

    if article.nil?
      session[:notice] = _('Homepage reseted.')
    else
      session[:notice] = _('"%s" configured as homepage.') % article.title
    end

    redirect_to (request.referer || profile.url)
  end

  def upload_files
    upload_single_file?
    @uploaded_files = []
    @parent = check_parent(params[:parent_id])
    @target = @parent ? ('/%s/%s' % [profile.identifier, @parent.full_name]) : '/%s' % profile.identifier
    record_coming
    if request.post? && params[:uploaded_files]
      params[:uploaded_files].each do |file|
        unless file == ''
          @uploaded_files << UploadedFile.create(
            {
              :uploaded_data => file,
              :profile => profile,
              :parent => @parent,
              :last_changed_by => user,
              :author => user,
            },
            :without_protection => true
          )
        end
      end
      @errors = @uploaded_files.select { |f| f.errors.any? }
      if @errors.any?
        render :action => 'upload_files', :parent_id => @parent_id
      else
        session[:notice] = _('File(s) successfully uploaded')
        if @back_to
          redirect_to url_for(@back_to)
        elsif @parent
          redirect_to :action => 'view', :id => @parent.id
        else
          redirect_to :action => 'index'
        end
      end
    end
  end

  def destroy
    @article = profile.articles.find(params[:id])
    if request.post?
      @article.destroy
      session[:notice] = _("\"%s\" was removed." % @article.title)
      referer = Rails.application.routes.recognize_path URI.parse(request.referer).path rescue nil
      if referer and referer[:controller] == 'cms' and referer[:action] != 'edit'
        redirect_to referer
      elsif @article.parent
        redirect_to @article.parent.url
      else
        redirect_to profile.url
      end
    end
  end

  def why_categorize
    render :action => params[:action], :layout => false
  end

  def update_categories
    @object = params[:id] ? @profile.articles.find(params[:id]) : Article.new
    render_categories 'article'
  end

  def search_communities_to_publish
    scope = user.memberships.distinct(false)
    results = find_by_contents(:profiles, environment, scope, params['q'], {:page => 1}, {:fields => ['name']})[:results]
    render :text => results.map {|community| {:id => community.id, :name => community.name} }
                           .uniq {|c| c[:id] }.to_json
  end

  def publish
    @article = profile.articles.find(params[:id])
    record_coming
    @failed = {}
    if request.post?
      article_name = params[:name]
      task = ApproveArticle.create!(:article => @article, :name => article_name, :target => user, :requestor => user)
      begin
        task.finish
      rescue Exception => ex
         @failed[ex.message] ? @failed[ex.message] << @article.title : @failed[ex.message] = [@article.title]
         task.cancel
      end
      if @failed.blank?
        session[:notice] = _("You published this content successfully")
        if @back_to
          redirect_to @back_to
        else
          redirect_to @article.view_url
        end
      end
    end
  end

  def publish_on_communities
    if request.post?
      @back_to = params[:back_to]
      @article = profile.articles.find(params[:id])
      @failed = {}
      article_name = params[:name]
      params_marked = (params['q'] || '').split(',').select { |marked| user.memberships.map(&:id).include? marked.to_i }
      @marked_groups = Profile.find(params_marked)
      if @marked_groups.empty?
        redirect_to @back_to
        return session[:notice] = _("Select some group to publish your article")
      end
      @marked_groups.each do |item|
        task = ApproveArticle.create!(:article => @article, :name => article_name, :target => item, :requestor => user)
        begin
          task.finish unless item.moderated_articles?
        rescue Exception => ex
           @failed[ex.message] ? @failed[ex.message] << item.name : @failed[ex.message] = [item.name]
           task.cancel
        end
      end
      if @failed.blank?
        session[:notice] = _("Your publish request was sent successfully")
        if @back_to
          redirect_to @back_to
        else
          redirect_to @article.view_url
        end
      else
        session[:notice] = _("Some of your publish requests couldn't be sent.")
        render :action => 'publish'
      end
    end
  end

  def publish_on_portal_community
    if request.post?
      @article = profile.articles.find(params[:id])
      if environment.portal_enabled
        task = ApproveArticle.create!(:article => @article, :name => params[:name], :target => environment.portal_community, :requestor => user)
        begin
          task.finish unless environment.portal_community.moderated_articles?
          session[:notice] = _("Your publish request was sent successfully")
        rescue
          session[:notice] = _("Your publish request couldn't be sent.")
          task.cancel
        end
      else
        session[:notice] = _("There is no portal community to publish your article.")
      end

      if @back_to
        redirect_to @back_to
      else
        redirect_to @article.view_url
      end
    end
  end

  def suggest_an_article
    @back_to = params[:back_to] || request.referer || url_for(profile.public_profile_url)
    @task = SuggestArticle.new(params[:task])
    if request.post?
      @task.target = profile
      @task.ip_address = request.remote_ip
      @task.user_agent = request.user_agent
      @task.referrer = request.referrer
      @task.requestor = current_person if logged_in?
      if verify_captcha(:suggest_article, @task, user, environment, profile) && @task.save
        session[:notice] = _('Thanks for your suggestion. The community administrators were notified.')
        redirect_to @back_to
      end
    end
  end

  def search
    query = params[:q]
    results = find_by_contents(:uploaded_files, profile, profile.files.published, query)[:results]
    render :text => article_list_to_json(results).html_safe, :content_type => 'application/json'
  end

  def media_upload
    parent = check_parent(params[:parent_id])
    if request.post?
      begin
        @file = UploadedFile.create!(:uploaded_data => params[:file], :profile => profile, :parent => parent) unless params[:file] == ''
        @file = FilePresenter.for(@file)
        respond_to do |format|
          format.js
        end
      rescue Exception => exception
        render :text => exception.to_s, :status => :bad_request
      end
    end
  end

  def published_media_items
    load_recent_files(params[:parent_id], params[:q])
    render :partial => 'published_media_items'
  end

  def view_all_media
    paginate_options = {:page => params[:page].blank? ? 1 : params[:page] }
    @key = params[:key].to_sym
    load_recent_files(params[:parent_id], params[:q], paginate_options)
  end

  def files
    @files = profile.files.paginate(per_page: per_page, page: params[:npage])
    @filters = {
      _('Name') => 'name',
      _('Size (bigger first)') => 'size DESC',
      _('Size (smaller first)') => 'size ASC'
    }

    @sort_by = params[:sort_by] || 'name'
    if @sort_by.in?(@filters.values)
      @files = @files.order(@sort_by)
    else
      @files = @files.order('name')
    end

    respond_to do |format|
      format.html
      format.js
    end
  end

  protected

  include CmsHelper

  def available_article_types
    articles = [
      TextArticle,
      Event
    ]
    articles += special_article_types if params && params[:cms]
    parent_id = params ? params[:parent_id] : nil
    if @parent && @parent.blog?
      articles -= Article.folder_types.map(&:constantize)
    end
    articles
  end

  def special_article_types
    [Folder, Blog, UploadedFile, Forum, Gallery, RssFeed] + @plugins.dispatch(:content_types)
  end


  def record_coming
    if request.post?
      @back_to = params[:back_to]
    else
      @back_to = params[:back_to] || request.referer
    end
  end

  def valid_article_type?(type)
    (available_article_types + special_article_types).map {|item| item.name}.include?(type)
  end

  def check_parent(id)
    if !id.blank?
      parent = profile.articles.find(id)
      if ! parent.allow_children?
        raise ArgumentError.new("cannot create child of article which does not accept children")
      end
      parent
    else
      nil
    end
  end

  def refuse_blocks
    @no_design_blocks = @type.present? && valid_article_type?(@type) ? !@type.constantize.can_display_blocks? : false
  end

  def per_page
    10
  end

  def translations
    @locales = environment.locales.invert.reject { |name, lang| !@article.possible_translations.include?(lang) }
    @selected_locale = @article.language || FastGettext.locale
  end

  def article_list_to_json(list)
    list.map do |item|
      {
        'title' => item.title,
        'url' => item.image? ? item.public_filename(:uploaded) : url_for(item.url),
        :icon => icon_for_article(item),
        :content_type => item.mime_type,
        :error => item.errors.any? ? _('%s could not be uploaded') % item.title : nil,
      }
    end.to_json
  end

  def content_editor?
    true
  end

  def success_redirect
    if !@success_back_to.blank?
      redirect_to @success_back_to
    else
      redirect_to @article.view_url
    end
  end

  def file_types
    {:images => _('Images'), :generics => _('Files')}
  end

  def load_recent_files(parent_id = nil, q = nil, paginate_options = {:page => 1, :per_page => 6})
    #TODO Since we only have special support for images, I'm limiting myself to
    #     consider generic files as non-images. In the future, with more supported
    #     file types we'll need to have a smart way to fetch from the database
    #     scopes of each supported type as well as the non-supported types as a
    #     whole.
    @recent_files = {}

    parent = parent_id.present? ? profile.articles.find(parent_id) : nil
    if parent.present?
      files = parent.children.files
    else
      files = profile.files
    end

    files = files.reorder('created_at DESC')
    images = files.images
    generics = files.no_images

    if q.present?
      @recent_files[:images] = find_by_contents(:images, profile, images, q, paginate_options)[:results]
      @recent_files[:generics] = find_by_contents(:generics, profile, generics, q, paginate_options)[:results]
    else
      @recent_files[:images] = images.paginate(paginate_options)
      @recent_files[:generics] = generics.paginate(paginate_options)
    end
  end

  def upload_single_file?
    if profile.allow_single_file?
      @article = UploadedFile.new if @article.nil?
      @type = "UploadedFile"
      redirect_to :action => 'new', type: "UploadedFile",  back_to: params[:back_to], parent_id: params[:parent_id]
    end
  end
end
